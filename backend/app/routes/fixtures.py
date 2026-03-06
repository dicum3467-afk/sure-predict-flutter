from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Query, HTTPException

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _default_window_utc() -> tuple[date, date]:
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=2)
    to = today + timedelta(days=10)
    return frm, to


def _parse_date(value: Optional[str]) -> Optional[date]:
    if not value:
        return None
    return datetime.fromisoformat(value).date()


@router.get("/fixtures")
def list_fixtures(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    provider_league_id: Optional[int] = Query(None),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
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
        order_sql = "ASC" if order == "asc" else "DESC"

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

        count_sql = f"""
            SELECT COUNT(*)
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            JOIN teams ht ON ht.id = f.home_team_id
            JOIN teams at ON at.id = f.away_team_id
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

                ht.id AS home_team_id,
                ht.provider_team_id AS home_provider_team_id,
                ht.name AS home_team_name,
                ht.short_name AS home_team_short,
                ht.logo_url AS home_team_logo,

                at.id AS away_team_id,
                at.provider_team_id AS away_provider_team_id,
                at.name AS away_team_name,
                at.short_name AS away_team_short,
                at.logo_url AS away_team_logo,

                f.home_goals,
                f.away_goals,
                f.season,
                f.round
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            JOIN teams ht ON ht.id = f.home_team_id
            JOIN teams at ON at.id = f.away_team_id
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
                    "home_team": {
                        "id": str(r[8]),
                        "provider_team_id": r[9],
                        "name": r[10],
                        "short": r[11],
                        "logo": r[12],
                    },
                    "away_team": {
                        "id": str(r[13]),
                        "provider_team_id": r[14],
                        "name": r[15],
                        "short": r[16],
                        "logo": r[17],
                    },
                    "home_goals": r[18],
                    "away_goals": r[19],
                    "season": r[20],
                    "round": r[21],
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
