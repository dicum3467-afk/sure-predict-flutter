from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import requests
from fastapi import APIRouter, Header, HTTPException, Query

from app.db import supabase_client

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")

# API-Sports direct
FOOTBALL_API_BASE_URL = os.getenv(
    "FOOTBALL_API_BASE_URL",
    "https://v3.football.api-sports.io",
)
FOOTBALL_API_KEY = os.getenv("FOOTBALL_API_KEY", "")
FOOTBALL_API_HOST = os.getenv("FOOTBALL_API_HOST", "v3.football.api-sports.io")

# Ligi default
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


def _default_season(today: datetime) -> int:
    # sezon european: iulie -> anul curent, altfel anul precedent
    return today.year if today.month >= 7 else today.year - 1


def _api_headers() -> Dict[str, str]:
    return {
        "x-apisports-key": FOOTBALL_API_KEY,
        "x-rapidapi-key": FOOTBALL_API_KEY,
        "x-rapidapi-host": FOOTBALL_API_HOST,
    }


def _api_get(path: str, params: Dict[str, Any]) -> Dict[str, Any]:
    if not FOOTBALL_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="FOOTBALL_API_KEY lipseste din environment variables",
        )

    url = f"{FOOTBALL_API_BASE_URL.rstrip('/')}/{path.lstrip('/')}"
    resp = requests.get(url, headers=_api_headers(), params=params, timeout=45)

    if resp.status_code >= 400:
        text = resp.text[:300] if resp.text else ""
        raise HTTPException(
            status_code=500,
            detail=f"Football API error {resp.status_code}: {text}",
        )

    data = resp.json()
    if not isinstance(data, dict):
        raise HTTPException(status_code=500, detail="Raspuns invalid de la Football API")

    return data


def _fetch_fixtures_for_league(
    league_provider_id: int,
    season: int,
    date_from: str,
    date_to: str,
    max_pages: int,
) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    page = 1

    while page <= max_pages:
        payload = _api_get(
            "/fixtures",
            {
                "league": league_provider_id,
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

    return items


def _get_team_name(team_payload: Dict[str, Any], fallback: str) -> str:
    return (
        team_payload.get("name")
        or team_payload.get("short_name")
        or team_payload.get("code")
        or fallback
    )


def _ensure_team(team_payload: Dict[str, Any]) -> str:
    provider_team_id = str(team_payload.get("id") or "").strip()
    if not provider_team_id:
        raise HTTPException(status_code=500, detail="Lipseste provider team id")

    existing = (
        supabase_client.table("teams")
        .select("id")
        .eq("provider_team_id", provider_team_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if existing:
        return existing[0]["id"]

    row = {
        "provider_team_id": provider_team_id,
        "name": _get_team_name(team_payload, f"Team {provider_team_id}"),
        "short_name": team_payload.get("code") or _get_team_name(team_payload, ""),
        "country": team_payload.get("country"),
        "logo_url": team_payload.get("logo"),
    }

    inserted = (
        supabase_client.table("teams")
        .insert(row)
        .execute()
        .data
        or []
    )
    if inserted:
        return inserted[0]["id"]

    retry = (
        supabase_client.table("teams")
        .select("id")
        .eq("provider_team_id", provider_team_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if retry:
        return retry[0]["id"]

    raise HTTPException(status_code=500, detail="Nu pot salva echipa in teams")


def _ensure_league(league_payload: Dict[str, Any], season: Optional[int]) -> str:
    provider_league_id = str(league_payload.get("id") or "").strip()
    if not provider_league_id:
        raise HTTPException(status_code=500, detail="Lipseste provider league id")

    existing = (
        supabase_client.table("leagues")
        .select("id")
        .eq("provider_league_id", provider_league_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if existing:
        league_id = existing[0]["id"]
        update_data = {
            "name": league_payload.get("name"),
            "country": league_payload.get("country"),
            "logo_url": league_payload.get("logo"),
            "type": league_payload.get("type"),
            "season": season,
            "is_active": True,
        }
        supabase_client.table("leagues").update(update_data).eq("id", league_id).execute()
        return league_id

    row = {
        "provider_league_id": provider_league_id,
        "name": league_payload.get("name"),
        "country": league_payload.get("country"),
        "logo_url": league_payload.get("logo"),
        "type": league_payload.get("type"),
        "season": season,
        "is_active": True,
    }

    inserted = (
        supabase_client.table("leagues")
        .insert(row)
        .execute()
        .data
        or []
    )
    if inserted:
        return inserted[0]["id"]

    retry = (
        supabase_client.table("leagues")
        .select("id")
        .eq("provider_league_id", provider_league_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if retry:
        return retry[0]["id"]

    raise HTTPException(status_code=500, detail="Nu pot salva liga in leagues")


def _extract_fixture_row(payload: Dict[str, Any], season: int) -> Dict[str, Any]:
    fixture = payload.get("fixture", {}) or {}
    league = payload.get("league", {}) or {}
    teams = payload.get("teams", {}) or {}

    home = teams.get("home", {}) or {}
    away = teams.get("away", {}) or {}

    home_team_id = _ensure_team(home)
    away_team_id = _ensure_team(away)
    league_id = _ensure_league(league, season)

    provider_fixture_id = str(fixture.get("id") or "").strip()
    if not provider_fixture_id:
        raise HTTPException(status_code=500, detail="Lipseste provider fixture id")

    kickoff_at = fixture.get("date")
    if not kickoff_at:
        raise HTTPException(status_code=500, detail="Lipseste kickoff date")

    status_info = fixture.get("status", {}) or {}
    goals = payload.get("goals", {}) or {}

    return {
        "provider_fixture_id": provider_fixture_id,
        "season_id": season,
        "league_id": league_id,
        "home_team_id": home_team_id,
        "away_team_id": away_team_id,
        "kickoff_at": kickoff_at,
        "round": league.get("round"),
        "status": status_info.get("short") or status_info.get("long") or "NS",
        "home_goals": goals.get("home"),
        "away_goals": goals.get("away"),
    }


def _upsert_fixture(row: Dict[str, Any]) -> str:
    existing = (
        supabase_client.table("fixtures")
        .select("id")
        .eq("provider_fixture_id", row["provider_fixture_id"])
        .limit(1)
        .execute()
        .data
        or []
    )

    if existing:
        fixture_id = existing[0]["id"]
        supabase_client.table("fixtures").update(row).eq("id", fixture_id).execute()
        return fixture_id

    inserted = (
        supabase_client.table("fixtures")
        .insert(row)
        .execute()
        .data
        or []
    )

    if inserted:
        return inserted[0]["id"]

    retry = (
        supabase_client.table("fixtures")
        .select("id")
        .eq("provider_fixture_id", row["provider_fixture_id"])
        .limit(1)
        .execute()
        .data
        or []
    )
    if retry:
        return retry[0]["id"]

    raise HTTPException(status_code=500, detail="Nu pot salva fixture in fixtures")


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90),
    past_days: int = Query(7, ge=0, le=90),
    season: Optional[int] = Query(None),
    max_pages: int = Query(10, ge=1, le=50),
    season_lookback: int = Query(2, ge=0, le=5),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    now = _utc_now()
    active_season = season or _default_season(now)

    date_from = (now - timedelta(days=past_days)).date().isoformat()
    date_to = (now + timedelta(days=days_ahead)).date().isoformat()

    leagues_done = 0
    seasons_to_try = [active_season - i for i in range(season_lookback + 1)]
    inserted = 0
    updated = 0
    skipped = 0
    errors: List[str] = []
    debug_rows: List[Dict[str, Any]] = []

    for league_provider_id in DEFAULT_LEAGUES:
        league_had_rows = False

        for season_try in seasons_to_try:
            try:
                fixtures_rows = _fetch_fixtures_for_league(
                    league_provider_id=league_provider_id,
                    season=season_try,
                    date_from=date_from,
                    date_to=date_to,
                    max_pages=max_pages,
                )

                debug_rows.append(
                    {
                        "league": league_provider_id,
                        "season": season_try,
                        "count": len(fixtures_rows),
                    }
                )

                if not fixtures_rows:
                    continue

                league_had_rows = True

                for item in fixtures_rows:
                    try:
                        row = _extract_fixture_row(item, season_try)

                        existed = (
                            supabase_client.table("fixtures")
                            .select("id")
                            .eq("provider_fixture_id", row["provider_fixture_id"])
                            .limit(1)
                            .execute()
                            .data
                            or []
                        )

                        _upsert_fixture(row)

                        if existed:
                            updated += 1
                        else:
                            inserted += 1

                    except Exception as ex:
                        skipped += 1
                        errors.append(
                            f"league {league_provider_id} season {season_try}: save error: {str(ex)}"
                        )

                break

            except Exception as ex:
                errors.append(
                    f"league {league_provider_id} season {season_try}: {str(ex)}"
                )

        if league_had_rows:
            leagues_done += 1

    return {
        "ok": True,
        "leagues": leagues_done,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "from": date_from,
        "to": date_to,
        "season": active_season,
        "seasons_tried": seasons_to_try,
        "max_pages": max_pages,
        "errors_count": len(errors),
        "errors_preview": errors[:10],
        "debug_preview": debug_rows[:30],
        }
