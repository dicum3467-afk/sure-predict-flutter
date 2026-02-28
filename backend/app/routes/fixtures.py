from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn, dict_cursor

router = APIRouter(tags=["fixtures"])


def _parse_date(s: str) -> date:
    # Acceptă "YYYY-MM-DD" sau ISO; ia doar data
    try:
        # dacă e strict YYYY-MM-DD
        return date.fromisoformat(s[:10])
    except Exception:
        raise HTTPException(status_code=422, detail=f"Invalid date: {s}. Use YYYY-MM-DD")


@router.get("/fixtures")
def list_fixtures(
    league_id: Optional[str] = Query(None, description="UUID din tabelul leagues.id"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="ex: NS, FT, 1H, HT etc"),
    recent_days: int = Query(
        2, ge=0, le=14,
        description="Câte zile înapoi să includă (implicit 2). 0 = doar viitor."
    ),
    upcoming_days: int = Query(
        30, ge=1, le=90,
        description="Câte zile înainte să includă (implicit 14)."
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    """
    Implicit: returnează meciuri din intervalul [azi - recent_days, azi + upcoming_days],
    cu prioritate pentru meciurile viitoare (upcoming first).
    Nu consumă API — doar DB.
    """

    now = datetime.now(timezone.utc)

    # dacă user nu dă date, setăm interval default
    if date_from is None and date_to is None:
        df = (now.date() - timedelta(days=recent_days))
        dt = (now.date() + timedelta(days=upcoming_days))
    else:
        df = _parse_date(date_from) if date_from else None
        dt = _parse_date(date_to) if date_to else None

        # dacă user dă doar una, completăm logic
        if df is None and dt is not None:
            df = dt - timedelta(days=recent_days)
        if dt is None and df is not None:
            dt = df + timedelta(days=upcoming_days)

    where = ["1=1"]
    params: list[Any] = []

    if league_id:
        where.append("league_id = %s")
        params.append(league_id)

    # Filtrare pe DATE (folosim kickoff_at::date)
    if df:
        where.append("kickoff_at::date >= %s")
        params.append(df)
    if dt:
        where.append("kickoff_at::date <= %s")
        params.append(dt)

    if status:
        where.append("status = %s")
        params.append(status)

    where_sql = "WHERE " + " AND ".join(where)

    # Upcoming first: cele cu kickoff_at >= now vin primele
    sql = f"""
        SELECT
            id,
            league_id,
            provider_fixture_id,
            season_id,
            home_team_id,
            away_team_id,
            kickoff_at,
            round,
            status,
            created_at
        FROM fixtures
        {where_sql}
        ORDER BY
            (kickoff_at < %s) ASC,
            kickoff_at ASC
        LIMIT %s OFFSET %s
    """

    params2 = params + [now, limit, offset]

    try:
        with get_conn() as conn:
            with dict_cursor(conn) as cur:
                cur.execute(sql, params2)
                return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
