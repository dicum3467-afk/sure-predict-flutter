from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, List, Dict, Any, Tuple

from fastapi import APIRouter, Query, HTTPException

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _default_window_utc() -> Tuple[date, date]:
    """Implicit: past 7 zile + next 14 zile (UTC)."""
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=7)
    to = today + timedelta(days=14)
    return frm, to


def _parse_date(s: Optional[str]) -> Optional[date]:
    if not s:
        return None
    # acceptă "YYYY-MM-DD"
    return datetime.fromisoformat(s).date()


@router.get("/fixtures")
def list_fixtures(
    league_uuid: Optional[str] = Query(None, description="UUID din tabela leagues"),
    provider_league_id: Optional[int] = Query(None, description="ID liga din API-Football (ex: 39, 140)"),
    status: Optional[str] = Query(
        None,
        description="Filtru status-uri separate prin virgula (ex: NS,FT,1H). Daca lipseste, nu filtreaza.",
    ),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC). Daca lipseste -> past 7 zile."),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC). Daca lipseste -> next 14 zile."),
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

        status_list: Optional[List[str]] = None
        if status:
            status_list = [x.strip() for x in status.split(",") if x.strip()]
            if not status_list:
                status_list = None

        offset = (page - 1) * per_page

        # IMPORTANT:
        # folosim ::date pentru interval inclusiv pe zi
        where_clauses = [
            "f.kickoff_at::date >= %(frm)s",
            "f.kickoff_at::date <= %(to)s",
        ]

        params: Dict[str, Any] = {
            "frm": frm,
            "to": to,
            "limit": per_page,
            "offset": offset,
        }

        if league_uuid:
            where_clauses.append("f.league_id = %(league_uuid)s")
            params["league_uuid"] = league_uuid

        if provider_league_id is not None:
            # FIX: daca l.provider_league_id e TEXT in DB, castam la int
            where_clauses.append("l.provider_league_id::int = %(provider_league_id)s")
            params["provider_league_id"] = provider_league_id

        if status_list is not None:
            where_clauses.append("f.status = ANY(%(status_list)s)")
            params["status_list"] = status_list

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
                f.home_team,
                f.away_team,
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

        # FIX: acelasi nume la variabila (conn)
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
                    "league_id": r[1],
                    "provider_league_id": r[2],
                    "league_name": r[3],
                    "league_country": r[4],
                    "provider_fixture_id": r[5],
                    "kickoff_at": r[6].isoformat() if hasattr(r[6], "isoformat") else r[6],
                    "status": r[7],
                    "home_team": r[8],
                    "away_team": r[9],
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

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    provider_league_id: int = Query(..., description="ID liga din API-Football (ex: 39, 140)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Shortcut: fixtures pentru o liga (provider_league_id) cu paginare.
    Default: past 7 + next 14 zile (UTC).
    """
    return list_fixtures(
        league_uuid=None,
        provider_league_id=provider_league_id,
        status=None,
        date_from=date_from,
        date_to=date_to,
        page=page,
        per_page=per_page,
        order=order,
                    )
