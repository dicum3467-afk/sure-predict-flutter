from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional, Dict, Any, List, Tuple

from fastapi import APIRouter, Query, HTTPException

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _default_window_utc() -> Tuple[date, date]:
    """
    Implicit: past 7 zile + next 14 zile (UTC), ca date.
    """
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=7)
    to = today + timedelta(days=14)
    return frm, to


def _parse_date(s: Optional[str]) -> Optional[date]:
    if not s:
        return None
    try:
        # accepta "YYYY-MM-DD"
        return datetime.fromisoformat(s).date()
    except Exception:
        return None


def _normalize_status_list(status: Optional[str]) -> Optional[List[str]]:
    """
    status poate fi "NS,FT,1H" etc.
    Returneaza lista, sau None daca nu filtrezi.
    """
    if not status:
        return None
    parts = [x.strip() for x in status.split(",") if x.strip()]
    return parts or None


def _list_fixtures(
    league_uuid: Optional[str],
    provider_league_id: Optional[int],
    status: Optional[str],
    date_from: Optional[str],
    date_to: Optional[str],
    page: int,
    per_page: int,
    order: str,
) -> Dict[str, Any]:
    try:
        frm = _parse_date(date_from)
        to = _parse_date(date_to)

        if frm is None or to is None:
            dfrm, dto = _default_window_utc()
            frm = frm or dfrm
            to = to or dto

        status_list = _normalize_status_list(status)

        offset = (page - 1) * per_page
        order_sql = "ASC" if order.lower() == "asc" else "DESC"

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

        # filtrare dupa liga (uuid)
        if league_uuid:
            where_clauses.append("f.league_id = %(league_uuid)s")
            params["league_uuid"] = league_uuid

        # filtrare dupa provider_league_id (API-Football), DAR: coloana in DB poate fi TEXT
        # => comparam ca TEXT ca sa evitam "text = integer"
        if provider_league_id is not None:
            where_clauses.append("l.provider_league_id = %(provider_league_id)s")
            params["provider_league_id"] = str(provider_league_id)

        # filtrare status-uri multiple
        if status_list is not None:
            where_clauses.append("f.status = ANY(%(status_list)s)")
            params["status_list"] = status_list

        where_sql = " AND ".join(where_clauses)

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
                f.round,
                f.run_type
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
            # r e tuple (cursor normal)
            kickoff = r[6]
            kickoff_iso = kickoff.isoformat() if hasattr(kickoff, "isoformat") else kickoff

            items.append(
                {
                    "id": r[0],
                    "league_id": r[1],
                    "provider_league_id": r[2],
                    "league_name": r[3],
                    "league_country": r[4],
                    "provider_fixture_id": r[5],
                    "kickoff_at": kickoff_iso,
                    "status": r[7],
                    "home_team": r[8],
                    "away_team": r[9],
                    "home_goals": r[10],
                    "away_goals": r[11],
                    "season": r[12],
                    "round": r[13],
                    "run_type": r[14],
                }
            )

        return {
            "page": page,
            "per_page": per_page,
            "total": total,
            "from": str(frm),
            "to": str(to),
            "order": order.lower(),
            "items": items,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/fixtures")
def list_fixtures(
    # filtre
    league_uuid: Optional[str] = Query(None, description="UUID din tabela leagues (ex: 9a0... )"),
    provider_league_id: Optional[int] = Query(None, description="ID liga din API-Football (ex: 39, 140)"),
    status: Optional[str] = Query(None, description="Filtru status-uri separate prin virgula (ex: NS,FT,1H)."),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC). Daca lipseste -> past 7 zile."),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC). Daca lipseste -> next 14 zile."),
    # paginare
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    # ordonare
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Returneaza fixtures cu paginare + filtre.
    Implicit: past 7 zile + next 14 zile (UTC).
    """
    return _list_fixtures(
        league_uuid=league_uuid,
        provider_league_id=provider_league_id,
        status=status,
        date_from=date_from,
        date_to=date_to,
        page=page,
        per_page=per_page,
        order=order,
    )


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    provider_league_id: int = Query(..., description="ID liga API-Football (ex: 39, 140)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Shortcut: fixtures pentru o liga (provider_league_id) cu paginare.
    Implicit: past 7 + next 14 zile.
    """
    return _list_fixtures(
        league_uuid=None,
        provider_league_id=provider_league_id,
        status=None,
        date_from=date_from,
        date_to=date_to,
        page=page,
        per_page=per_page,
        order=order,
    )


@router.get("/fixtures/tomorrow")
def fixtures_tomorrow(
    provider_league_id: Optional[int] = Query(None, description="Optional: filtreaza doar o liga (ex: 39)"),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    page: int = Query(1, ge=1),
    per_page: int = Query(200, ge=1, le=200),
) -> Dict[str, Any]:
    """
    Returneaza fixtures pentru ziua de MAINE (UTC).
    Daca vrei ora Romaniei, spune-mi si il fac pe Europe/Bucharest.
    """
    tomorrow = datetime.now(timezone.utc).date() + timedelta(days=1)
    d = tomorrow.isoformat()

    return _list_fixtures(
        league_uuid=None,
        provider_league_id=provider_league_id,
        status=None,
        date_from=d,
        date_to=d,
        page=page,
        per_page=per_page,
        order=order,
                          )
