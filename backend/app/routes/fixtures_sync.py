from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

import requests
from fastapi import APIRouter, Header, HTTPException, Query

from app.db import supabase_client

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])


@router.get("/debug-status")
def debug_status():
    url = f"{FOOTBALL_API_BASE_URL}/status"

    resp = requests.get(
        url,
        headers={
            "x-apisports-key": FOOTBALL_API_KEY
        },
        timeout=30
    )

    return {
        "status_code": resp.status_code,
        "response": resp.text
    }

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")

# API SPORTS
FOOTBALL_API_BASE_URL = os.getenv(
    "FOOTBALL_API_BASE_URL",
    "https://v3.football.api-sports.io"
)

FOOTBALL_API_KEY = os.getenv("FOOTBALL_API_KEY", "")

# ligi importante
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


def _api_headers() -> Dict[str, str]:
    return {
        "x-apisports-key": FOOTBALL_API_KEY
    }


def _api_get(path: str, params: Dict[str, Any]) -> Dict[str, Any]:

    if not FOOTBALL_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="FOOTBALL_API_KEY lipseste"
        )

    url = f"{FOOTBALL_API_BASE_URL}/{path}"

    resp = requests.get(
        url,
        headers=_api_headers(),
        params=params,
        timeout=30
    )

    if resp.status_code >= 400:
        raise HTTPException(
            status_code=500,
            detail=f"Football API error {resp.status_code}: {resp.text}"
        )

    return resp.json()


def _extract_fixture_row(data: Dict[str, Any]):

    fixture = data["fixture"]
    teams = data["teams"]
    goals = data["goals"]
    league = data["league"]

    return {
        "fixture_id": fixture["id"],
        "league_id": league["id"],
        "league_name": league["name"],
        "season": league["season"],
        "home_team_id": teams["home"]["id"],
        "home_team": teams["home"]["name"],
        "away_team_id": teams["away"]["id"],
        "away_team": teams["away"]["name"],
        "kickoff": fixture["date"],
        "status": fixture["status"]["short"],
        "home_goals": goals["home"],
        "away_goals": goals["away"],
    }


def _upsert_fixture(row: Dict[str, Any]):

    supabase_client.table("fixtures").upsert(
        row,
        on_conflict="fixture_id"
    ).execute()


def _fetch_fixtures_for_league(
    league_id: int,
    season: int,
    from_date: str,
    to_date: str,
):

    params = {
        "league": league_id,
        "season": season,
        "from": from_date,
        "to": to_date,
    }

    data = _api_get("fixtures", params)

    return data.get("response", [])


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(30, ge=1, le=90),
    past_days: int = Query(30, ge=0, le=90),
    season: int | None = Query(None),
    max_pages: int = Query(10, ge=1, le=50),
    season_lookback: int = Query(2, ge=0, le=5),
    x_sync_token: str = Header(None)
):

    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid token")

    now = datetime.now(timezone.utc)

    start_date = (now - timedelta(days=past_days)).date().isoformat()
    end_date = (now + timedelta(days=days_ahead)).date().isoformat()

    inserted = 0
    updated = 0
    skipped = 0

    errors: List[str] = []

    if season is None:
        season = now.year

    seasons_to_try = [season - i for i in range(season_lookback + 1)]

    for league in DEFAULT_LEAGUES:

        for s in seasons_to_try:

            try:

                fixtures = _fetch_fixtures_for_league(
                    league,
                    s,
                    start_date,
                    end_date
                )

                for f in fixtures:

                    row = _extract_fixture_row(f)

                    _upsert_fixture(row)

                    inserted += 1

            except Exception as e:

                errors.append(f"league {league} season {s}: {str(e)}")

    return {
        "ok": True,
        "from": start_date,
        "to": end_date,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors_count": len(errors),
        "errors_preview": errors[:10],
    }
