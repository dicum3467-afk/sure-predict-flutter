from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Query, HTTPException

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _default_window_utc():
    today = datetime.now(timezone.utc).date()
    return today - timedelta(days=2), today + timedelta(days=10)


def _parse_date(value: Optional[str]):
    if not value:
        return None
    return datetime.fromisoformat(value).date()


@router.get("/fixtures")
def list_fixtures(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    provider_league_id: Optional[int] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
):

    try:
        frm = _parse_date(date_from)
        to = _parse_date(date_to)

        if not frm or not to:
            frm, to = _default_window_utc()

        offset = (page - 1) * per_page

        where = [
            "f.kickoff_at::date >= %(frm)s",
            "f.kickoff_at::date <= %(to)s",
        ]

        params = {
            "frm": frm,
            "to": to,
            "limit": per_page,
            "offset": offset,
        }

        if provider_league_id:
            where.append("l.provider_league_id = %(league)s")
            params["league"] = provider_league_id

        where_sql = " AND ".join(where)

        count_sql = f"""
        SELECT COUNT(*)
        FROM fixtures f
        JOIN leagues l ON l.id = f.league_id
        WHERE {where_sql}
        """

        data_sql = f"""
        SELECT
            f.id,
            f.kickoff_at,
            f.status,

            l.name,
            l.country,

            ht.name,
            ht.short_name,
            ht.logo_url,

            at.name,
            at.short_name,
            at.logo_url

        FROM fixtures f

        JOIN leagues l
        ON l.id = f.league_id

        JOIN teams ht
        ON ht.id = f.home_team_id

        JOIN teams at
        ON at.id = f.away_team_id

        WHERE {where_sql}

        ORDER BY f.kickoff_at ASC
        LIMIT %(limit)s OFFSET %(offset)s
        """

        with get_conn() as conn:
            with conn.cursor() as cur:

                cur.execute(count_sql, params)
                total = cur.fetchone()[0]

                cur.execute(data_sql, params)
                rows = cur.fetchall()

        items = []

        for r in rows:

            items.append(
                {
                    "id": r[0],
                    "kickoff_at": r[1].isoformat(),
                    "status": r[2],

                    "league_name": r[3],
                    "league_country": r[4],

                    "home_team": {
                        "name": r[5],
                        "short": r[6],
                        "logo": r[7],
                    },

                    "away_team": {
                        "name": r[8],
                        "short": r[9],
                        "logo": r[10],
                    },
                }
            )

        return {
            "page": page,
            "per_page": per_page,
            "total": total,
            "items": items,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
