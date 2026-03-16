from __future__ import annotations

import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import requests
from fastapi import APIRouter, Header, HTTPException, Query

from app.db import supabase_client

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")

FOOTBALL_API_BASE_URL = os.getenv(
    "FOOTBALL_API_BASE_URL",
    "https://v3.football.api-sports.io",
)
FOOTBALL_API_KEY = os.getenv("FOOTBALL_API_KEY", "")
FOOTBALL_API_HOST = os.getenv("FOOTBALL_API_HOST", "v3.football.api-sports.io")

DEFAULT_LEAGUES = [
    39,   # Premier League
    140,  # La Liga
    135,  # Serie A
    78,   # Bundesliga
    61,   # Ligue 1
    94,   # Primeira Liga
    88,   # Eredivisie
    203,  # Super Lig
    2,    # Champions League
    3,    # Europa League
]


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _api_headers() -> Dict[str, str]:
    return {
        "x-apisports-key": FOOTBALL_API_KEY,
        "x-rapidapi-key": FOOTBALL_API_KEY,
        "x-rapidapi-host": FOOTBALL_API_HOST,
    }


@router.get("/debug-status")
def debug_status() -> Dict[str, Any]:
    if not FOOTBALL_API_KEY:
        return {
            "status_code": 500,
            "response": "FOOTBALL_API_KEY lipsește",
        }

    url = f"{FOOTBALL_API_BASE_URL.rstrip('/')}/status"
    resp = requests.get(url, headers=_api_headers(), timeout=30)

    return {
        "status_code": resp.status_code,
        "response": resp.text,
    }


def _api_get(path: str, params: Dict[str, Any]) -> Dict[str, Any]:
    if not FOOTBALL_API_KEY:
        raise HTTPException(status_code=500, detail="FOOTBALL_API_KEY lipsește")

    url = f"{FOOTBALL_API_BASE_URL.rstrip('/')}/{path.lstrip('/')}"
    resp = requests.get(
        url,
        headers=_api_headers(),
        params=params,
        timeout=30,
    )

    if resp.status_code == 429:
        raise HTTPException(
            status_code=500,
            detail="Football API error 429: Too many requests",
        )

    if resp.status_code >= 400:
        raise HTTPException(
            status_code=500,
            detail=f"Football API error {resp.status_code}: {resp.text}",
        )

    data = resp.json()
    if not isinstance(data, dict):
        raise HTTPException(status_code=500, detail="Răspuns invalid de la Football API")

    return data


def _fetch_fixtures_for_league(
    league_id: int,
    season: int,
    date_from: str,
    date_to: str,
    max_pages: int = 5,
) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    page = 1

    while page <= max_pages:
        payload = _api_get(
            "/fixtures",
            {
                "league": league_id,
                "season": season,
                "from": date_from,
                "to": date_to,
                "page": page,
            },
        )

        response_items = payload.get("response", []) or []
        paging = payload.get("paging", {}) or {}
        current = int(paging.get("current", page) or page)
        total = int(paging.get("total", 1) or 1)

        items.extend(response_items)

        if current >= total:
            break

        page += 1
        time.sleep(1.2)

    return items


def _ensure_league(league_block: Dict[str, Any]) -> None:
    league_id = league_block.get("id")
    if not league_id:
        return

    row = {
        "provider_league_id": league_id,
        "name": league_block.get("name"),
        "country": league_block.get("country"),
        "logo": league_block.get("logo"),
        "is_active": True,
        "updated_at": _utc_now().isoformat(),
    }

    supabase_client.table("leagues").upsert(
        row,
        on_conflict="provider_league_id",
    ).execute()


def _extract_fixture_row(item: Dict[str, Any]) -> Dict[str, Any]:
    fixture = item.get("fixture", {}) or {}
    league = item.get("league", {}) or {}
    teams = item.get("teams", {}) or {}
    goals = item.get("goals", {}) or {}

    home = teams.get("home", {}) or {}
    away = teams.get("away", {}) or {}
    status_block = fixture.get("status", {}) or {}

    return {
        "provider_fixture_id": fixture.get("id"),
        "season": league.get("season"),
        "league_id": league.get("id"),
        "home_team_id": home.get("id"),
        "away_team_id": away.get("id"),
        "kickoff_at": fixture.get("date"),
        "round": league.get("round"),
        "status": status_block.get("short") or status_block.get("long"),
        "home_goals": goals.get("home"),
        "away_goals": goals.get("away"),
        "updated_at": _utc_now().isoformat(),
    }


def _upsert_fixture(row: Dict[str, Any]) -> None:
    supabase_client.table("fixtures").upsert(
        row,
        on_conflict="provider_fixture_id",
    ).execute()


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90),
    past_days: int = Query(7, ge=0, le=90),
    season: Optional[int] = Query(None),
    max_pages: int = Query(5, ge=1, le=20),
    season_lookback: int = Query(1, ge=0, le=5),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    now = _utc_now()
    active_season = season or (now.year if now.month >= 7 else now.year - 1)

    date_from = (now - timedelta(days=past_days)).date().isoformat()
    date_to = (now + timedelta(days=days_ahead)).date().isoformat()
    seasons_to_try = [active_season - i for i in range(season_lookback + 1)]

    leagues_done = 0
    inserted = 0
    updated = 0
    skipped = 0
    errors: List[str] = []
    debug_preview: List[Dict[str, Any]] = []

    for league_provider_id in DEFAULT_LEAGUES:
        league_had_rows = False

        for season_try in seasons_to_try:
            try:
                fixtures = _fetch_fixtures_for_league(
                    league_id=league_provider_id,
                    season=season_try,
                    date_from=date_from,
                    date_to=date_to,
                    max_pages=max_pages,
                )

                debug_preview.append(
                    {
                        "league": league_provider_id,
                        "season": season_try,
                        "count": len(fixtures),
                    }
                )

                if not fixtures:
                    continue

                for item in fixtures:
                    league_block = item.get("league", {}) or {}
                    _ensure_league(league_block)

                    row = _extract_fixture_row(item)
                    if not row.get("provider_fixture_id"):
                        skipped += 1
                        continue

                    _upsert_fixture(row)
                    inserted += 1
                    league_had_rows = True

                leagues_done += 1
                break

            except Exception as e:
                errors.append(f"league {league_provider_id} season {season_try}: {e}")
                time.sleep(1.5)

        if not league_had_rows:
            skipped += 1

    return {
        "ok": True,
        "from": date_from,
        "to": date_to,
        "season": active_season,
        "seasons_tried": seasons_to_try,
        "leagues": leagues_done,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors_count": len(errors),
        "errors_preview": errors[:10],
        "debug_preview": debug_preview[:20],
        }
