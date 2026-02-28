from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone, date
from typing import Optional, Dict, Any, List, Tuple

import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn

router = APIRouter(tags=["fixtures"])

API_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Missing APISPORTS_KEY / API_FOOTBALL_KEY in environment.",
        )


def _check_token(x_sync_token: Optional[str]) -> None:
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _daterange_utc(past_days: int, days_ahead: int) -> Tuple[date, date]:
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=past_days)
    to = today + timedelta(days=days_ahead)
    return frm, to


def _api_get_fixtures(league_id: int, season: int, frm: date, to: date, page: int) -> Dict[str, Any]:
    """
    API-Football v3 fixtures endpoint with pagination.
    """
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {
        "x-apisports-key": API_KEY,
        "accept": "application/json",
    }
    params = {
        "league": league_id,
        "season": season,
        "from": str(frm),
        "to": str(to),
        "page": page,
    }

    resp = requests.get(url, headers=headers, params=params, timeout=30)
    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football error {resp.status_code} for league={league_id}, season={season}, page={page}",
        )
    return resp.json()


def _parse_fixture_row(item: Dict[str, Any], league_uuid: str) -> Dict[str, Any]:
    fx = item.get("fixture", {}) or {}
    teams = item.get("teams", {}) or {}
    goals = item.get("goals", {}) or {}
    league = item.get("league", {}) or {}
    st = (fx.get("status") or {}).get("short")

    kickoff = fx.get("date")  # ISO string UTC
    provider_fixture_id = fx.get("id")

    home = (teams.get("home") or {}).get("name")
    away = (teams.get("away") or {}).get("name")

    home_goals = goals.get("home")
    away_goals = goals.get("away")

    return {
        "league_id": league_uuid,
        "provider_fixture_id": provider_fixture_id,
        "kickoff_at": kickoff,
        "status": st,
        "home_team": home,
        "away_team": away,
        "home_goals": home_goals,
        "away_goals": away_goals,
        "season": league.get("season"),
        "round": league.get("round"),
    }


@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    # PRO++: range mare, dar controlat
    days_ahead: int = Query(14, ge=1, le=90, description="Câte zile în viitor să sincronizeze (max 90)."),
    past_days: int = Query(7, ge=0, le=90, description="Câte zile în trecut să includă (max 90)."),
    # sezon opțional
    season: Optional[int] = Query(None, description="Sezonul (ex: 2025). Dacă lipsește, se auto-detectează."),
    # cost control:
    max_pages: int = Query(10, ge=1, le=50, description="Limită pagini per ligă (max 50)."),
    season_lookback: int = Query(2, ge=0, le=5, description="Câți ani înapoi să caute sezonul dacă nu e dat."),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    PRO++ Sync fixtures din API-Football în tabela fixtures, pentru ligile active din tabela leagues.

    Include:
    - +viitor (days_ahead)
    - +trecut (past_days)
    - paginare (max_pages)
    - auto-detect sezon (dacă season nu e trimis)
    """

    _check_token(x_sync_token)
    _require_api_key()

    frm, to = _daterange_utc(past_days=past_days, days_ahead=days_ahead)

    inserted = 0
    updated = 0
    skipped = 0
    leagues_count = 0

    # colectăm ce sezoane încercăm dacă nu e dat explicit
    now_year = datetime.now(timezone.utc).year
    seasons_to_try: List[int] = [season] if season is not None else [now_year - i for i in range(0, season_lookback + 1)]

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                # ligile active
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    """
                )
                leagues: List[Tuple[str, int]] = cur.fetchall()
                leagues_count = len(leagues)

                # UPSERT query (ai deja UNIQUE pe provider_fixture_id)
                upsert_sql = """
                INSERT INTO fixtures (
                    league_id,
                    provider_fixture_id,
                    kickoff_at,
                    status,
                    home_team,
                    away_team,
                    home_goals,
                    away_goals,
                    season,
                    round
                )
                VALUES (
                    %(league_id)s,
                    %(provider_fixture_id)s,
                    %(kickoff_at)s,
                    %(status)s,
                    %(home_team)s,
                    %(away_team)s,
                    %(home_goals)s,
                    %(away_goals)s,
                    %(season)s,
                    %(round)s
                )
                ON CONFLICT (provider_fixture_id)
                DO UPDATE SET
                    league_id   = EXCLUDED.league_id,
                    kickoff_at  = EXCLUDED.kickoff_at,
                    status      = EXCLUDED.status,
                    home_team   = EXCLUDED.home_team,
                    away_team   = EXCLUDED.away_team,
                    home_goals  = EXCLUDED.home_goals,
                    away_goals  = EXCLUDED.away_goals,
                    season      = EXCLUDED.season,
                    round       = EXCLUDED.round
                RETURNING (xmax = 0) AS inserted;
                """

                for league_uuid, provider_league_id in leagues:
                    # alegem sezonul care dă rezultate (dacă season nu a fost dat)
                    chosen_season: Optional[int] = None

                    for s in seasons_to_try:
                        # încercăm prima pagină ca "probe"
                        data = _api_get_fixtures(provider_league_id, s, frm, to, page=1)
                        resp_items = data.get("response", []) or []
                        paging = (data.get("paging") or {})
                        total_pages = int(paging.get("total", 1) or 1)

                        if len(resp_items) > 0 or season is not None:
                            chosen_season = s
                            # dacă e sezon explicit, nu mai căutăm
                            break

                        # alt sezon (auto-detect) dacă nu sunt date
                        continue

                    if chosen_season is None:
                        # nimic găsit pentru lookback
                        continue

                    # acum sincronizăm toate paginile (limit max_pages)
                    page = 1
                    while True:
                        data = _api_get_fixtures(provider_league_id, chosen_season, frm, to, page=page)
                        items = data.get("response", []) or []
                        paging = (data.get("paging") or {})
                        total_pages = int(paging.get("total", 1) or 1)

                        if not items and page == 1:
                            # nimic în range
                            break

                        for item in items:
                            row = _parse_fixture_row(item, league_uuid)

                            if not row.get("provider_fixture_id") or not row.get("kickoff_at"):
                                skipped += 1
                                continue

                            cur.execute(upsert_sql, row)
                            res = cur.fetchone()
                            if res and res[0] is True:
                                inserted += 1
                            else:
                                updated += 1

                        conn.commit()

                        if page >= total_pages:
                            break
                        if page >= max_pages:
                            break

                        page += 1

        return {
            "ok": True,
            "leagues": leagues_count,
            "inserted": inserted,
            "updated": updated,
            "skipped": skipped,
            "from": str(frm),
            "to": str(to),
            "season": season if season is not None else seasons_to_try[0],
            "seasons_tried": seasons_to_try if season is None else [season],
            "max_pages": max_pages,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
