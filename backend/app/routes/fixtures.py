from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Query, HTTPException

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _default_window_utc() -> tuple[date, date]:
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=7)
    to = today + timedelta(days=14)
    return frm, to


def _parse_date(s: Optional[str]) -> Optional[date]:
    if not s:
        return None
    return datetime.fromisoformat(s).date()


@router.get("/fixtures")
def list_fixtures(
    provider_league_id: Optional[int] = Query(
        None, description="ID liga din API-Football (ex: 39, 140)"
    ),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    try:
        frm = _parse_date(date_from)
        to = _parse_date(date_to)

        if frm is None or to is None:
            dfrm, dto = _default_window_utc()
            frm = frm or dfrm
            to = to or dto

        offset = (page - 1) * per_page

        where_clauses: List[str] = [
            "f.kickoff_at::date >= %(frm)s",
            "f.kickoff_at::date <= %(to)s",
        ]
        params: Dict[str, Any] = {
            "frm": frm,
            "to": to,
            "limit": per_page,
            "offset": offset,
        }

        if provider_league_id is not None:
            where_clauses.append("l.provider_league_id = %(provider_league_id)s")
            params["provider_league_id"] = provider_league_id

        where_sql = " AND ".join(where_clauses)
        order_sql = "ASC" if order == "asc" else "DESC"

        count_sql = f"""
            SELECT COUNT(*)
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            WHERE {where_sql}
        """

        data_sql = f"""
            SELECT
                f.id,
                f.league_id,
                l.provider_league_id,
                l.name AS league_name,
                l.country AS league_country,
                f.provider_fixture_id,
                f.kickoff_at,
                f.status,
                f.home_team_id,
                f.away_team_id,
                f.home_goals,
                f.away_goals,
                f.season,
                f.round
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            WHERE {where_sql}
            ORDER BY f.kickoff_at {order_sql}
            LIMIT %(limit)s OFFSET %(offset)s
        """

        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(count_sql, params)
                total = int(cur.fetchone()[0])

                cur.execute(data_sql, params)
                rows = cur.fetchall()

        items: List[Dict[str, Any]] = []
        for r in rows:
            home_team_id = r[8]
            away_team_id = r[9]

            items.append(
                {
                    "id": r[0],
                    "league_id": str(r[1]),
                    "provider_league_id": r[2],
                    "league_name": r[3],
                    "league_country": r[4],
                    "provider_fixture_id": r[5],
                    "kickoff_at": r[6].isoformat() if hasattr(r[6], "isoformat") else r[6],
                    "status": r[7],
                    "home_team": f"Team {home_team_id}" if home_team_id is not None else "Home",
                    "away_team": f"Team {away_team_id}" if away_team_id is not None else "Away",
                    "home_team_id": home_team_id,
                    "away_team_id": away_team_id,
                    "home_goals": r[10],
                    "away_goals": r[11],
                    "season": r[12],
                    "round": r[13],
                }
            )

        return {
            "page": page,
            "per_page": per_page,
            "total": total,
            "from": str(frm),
            "to": str(to),
            "order": order,
            "items": items,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
