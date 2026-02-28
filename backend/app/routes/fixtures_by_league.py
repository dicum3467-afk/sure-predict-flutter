from __future__ import annotations

from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def normalize_status(status: Optional[str]) -> Optional[str]:
    """
    Dacă vrei să normalizezi statusuri din UI (NS/FT etc) spre ce ai în DB.
    În DB tu ai acum status short (NS/FT/HT...) din sync, deci returnăm direct.
    """
    if not status:
        return None
    return status.strip().upper()


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    # Poți folosi fie league_id (UUID din tabela leagues), fie provider_league_id (ID API-Football)
    league_id: Optional[str] = Query(None, description="UUID (din tabela leagues)"),
    provider_league_id: Optional[int] = Query(None, description="ID liga API-Football (ex: 39, 140)"),

    # filtre optional
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    status: Optional[str] = Query(None, description="NS/FT/HT etc"),
    run_type: Optional[str] = Query(None, description="initial/daily/manual etc (optional)"),

    # paginare
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> List[Dict[str, Any]]:
    """
    Shortcut: fixtures pentru o ligă (provider_league_id) cu paginare.
    Default: dacă nu dai date_from/date_to, îți dă doar meciurile viitoare (kickoff_at >= now()).
    """
    if league_id is None and provider_league_id is None:
        raise HTTPException(status_code=422, detail="Trebuie league_id sau provider_league_id")

    status_n = normalize_status(status)

    offset = (page - 1) * per_page

    where = []
    params: List[Any] = []

    # ✅ FIX IMPORTANT: provider_league_id este TEXT în DB → cast în SQL
    if provider_league_id is not None:
        where.append("l.provider_league_id::int = %s")
        params.append(int(provider_league_id))
    elif league_id is not None:
        where.append("f.league_id = %s")
        params.append(league_id)

    # dacă nu ai dat deloc interval, default doar viitoare
    if not date_from and not date_to:
        where.append("f.kickoff_at >= NOW()")

    # date_from/date_to sunt YYYY-MM-DD; filtrăm pe kickoff_at (timestamptz)
    # - date_from: kickoff_at >= date_from 00:00 UTC
    if date_from:
        where.append("f.kickoff_at >= (%s::date)")
        params.append(date_from)

    # - date_to inclusiv: kickoff_at < date_to + 1 zi
    if date_to:
        where.append("f.kickoff_at < ((%s::date) + interval '1 day')")
        params.append(date_to)

    if status_n:
        where.append("UPPER(COALESCE(f.status,'')) = %s")
        params.append(status_n)

    if run_type:
        where.append("f.run_type = %s")
        params.append(run_type)

    where_sql = "WHERE " + " AND ".join(where) if where else ""
    order_sql = "ASC" if order.lower() == "asc" else "DESC"

    sql = f"""
        SELECT
            f.id,
            f.league_id,
            f.provider_fixture_id,
            f.home_team,
            f.away_team,
            f.kickoff_at,
            f.status,
            f.home_goals,
            f.away_goals,
            f.run_type
        FROM fixtures f
        JOIN leagues l ON l.id = f.league_id
        {where_sql}
        ORDER BY f.kickoff_at {order_sql}
        LIMIT %s OFFSET %s
    """

    params2 = params + [per_page, offset]

    try:
        # ✅ FIX IMPORTANT: get_conn() e context manager
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, tuple(params2))
                rows = cur.fetchall()

        out: List[Dict[str, Any]] = []
        for r in rows:
            kickoff = r[5]
            kickoff_iso = kickoff.isoformat() if hasattr(kickoff, "isoformat") and kickoff else None
            out.append(
                {
                    "id": str(r[0]),
                    "league_id": str(r[1]),
                    "provider_fixture_id": r[2],
                    "home_team": r[3],
                    "away_team": r[4],
                    "kickoff_at": kickoff_iso,
                    "status": r[6],
                    "home_goals": r[7],
                    "away_goals": r[8],
                    "run_type": r[9],
                }
            )
        return out

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
