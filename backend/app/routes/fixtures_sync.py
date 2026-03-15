from __future__ import annotations

import os
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


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()


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
        raise HTTPException(
            status_code=500,
            detail=f"Football API error {resp.status_code}: {resp.text[:300]}",
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


def _get_one(
    table: str,
    select_cols: str,
    eq_col: str,
    eq_value: Any,
) -> Optional[Dict[str, Any]]:
    rows = (
        supabase_client.table(table)
        .select(select_cols)
        .eq(eq_col, eq_value)
        .limit(1)
        .execute()
        .data
        or []
    )
    return rows[0] if rows else None


def _ensure_league(provider_league_id: Any, name: str, country: str) -> str:
    provider_league_id = str(provider_league_id)
    now_iso = _iso(_utc_now())

    existing = _get_one("leagues", "id", "provider_league_id", provider_league_id)
    if existing:
        supabase_client.table("leagues").update(
            {
                "name": name,
                "country": country,
                "updated_at": now_iso,
            }
        ).eq("id", existing["id"]).execute()
        return existing["id"]

    inserted = (
        supabase_client.table("leagues")
        .insert(
            {
                "provider_league_id": provider_league_id,
                "name": name,
                "country": country,
                "created_at": now_iso,
                "updated_at": now_iso,
            }
        )
        .execute()
        .data
        or []
    )

    if not inserted:
        retry = _get_one("leagues", "id", "provider_league_id", provider_league_id)
        if not retry:
            raise HTTPException(status_code=500, detail="Nu pot salva league in DB")
        return retry["id"]

    return inserted[0]["id"]


def _ensure_team(
    provider_team_id: Any,
    name: str,
    short_name: Optional[str] = None,
    logo_url: Optional[str] = None,
) -> str:
    provider_team_id = str(provider_team_id)
    now_iso = _iso(_utc_now())

    existing = _get_one("teams", "id", "provider_team_id", provider_team_id)
    if existing:
        supabase_client.table("teams").update(
            {
                "name": name,
                "short_name": short_name or name[:3].upper(),
                "logo_url": logo_url,
                "updated_at": now_iso,
            }
        ).eq("id", existing["id"]).execute()
        return existing["id"]

    inserted = (
        supabase_client.table("teams")
        .insert(
            {
                "provider_team_id": provider_team_id,
                "name": name,
                "short_name": short_name or name[:3].upper(),
                "logo_url": logo_url,
                "created_at": now_iso,
                "updated_at": now_iso,
            }
        )
        .execute()
        .data
        or []
    )

    if not inserted:
        retry = _get_one("teams", "id", "provider_team_id", provider_team_id)
        if not retry:
            raise HTTPException(status_code=500, detail="Nu pot salva team in DB")
        return retry["id"]

    return inserted[0]["id"]


def _status_from_provider(fixture_block: Dict[str, Any]) -> str:
    status = (fixture_block.get("status") or {}).get("short") or ""
    status = str(status).upper()

    if status in {"FT", "AET", "PEN"}:
        return "finished"
    if status in {"NS", "TBD"}:
        return "scheduled"
    if status in {"1H", "2H", "HT", "ET", "BT", "P", "LIVE"}:
        return "live"
    if status in {"PST", "CANC", "ABD", "AWD", "WO"}:
        return "cancelled"

    return "scheduled"


def _upsert_fixture(
    *,
    provider_fixture_id: Any,
    league_id: str,
    home_team_id: str,
    away_team_id: str,
    kickoff_at: str,
    round_name: Optional[str],
    status: str,
    home_goals: Optional[int],
    away_goals: Optional[int],
    season_id: Optional[str] = None,
) -> str:
    provider_fixture_id = str(provider_fixture_id)
    now_iso = _iso(_utc_now())

    payload: Dict[str, Any] = {
        "provider_fixture_id": provider_fixture_id,
        "league_id": league_id,
        "home_team_id": home_team_id,
        "away_team_id": away_team_id,
        "kickoff_at": kickoff_at,
        "round": round_name,
        "status": status,
        "home_goals": home_goals,
        "away_goals": away_goals,
        "updated_at": now_iso,
    }

    if season_id is not None:
        payload["season_id"] = season_id

    existing = _get_one("fixtures", "id", "provider_fixture_id", provider_fixture_id)
    if existing:
        supabase_client.table("fixtures").update(payload).eq("id", existing["id"]).execute()
        return existing["id"]

    payload["created_at"] = now_iso
    inserted = (
        supabase_client.table("fixtures")
        .insert(payload)
        .execute()
        .data
        or []
    )

    if not inserted:
        retry = _get_one("fixtures", "id", "provider_fixture_id", provider_fixture_id)
        if not retry:
            raise HTTPException(status_code=500, detail="Nu pot salva fixture in DB")
        return retry["id"]

    return inserted[0]["id"]


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
    seasons_tried: List[int] = []
    inserted = 0
    updated = 0
    skipped = 0
    errors: List[str] = []

    # dacă nu găsim rezultate pe sezonul cerut, încercăm și în urmă
    seasons_to_try = [active_season - i for i in range(season_lookback + 1)]
    seasons_tried = seasons_to_try[:]

    for league_provider_id in DEFAULT_LEAGUES:
        league_had_rows = False

        for season_try in seasons_to_try:
            try:
                fixtures = _fetch_fixtures_for_league(
                    league_provider_id=league_provider_id,
                    season=season_try,
                    date_from=date_from,
                    date_to=date_to,
                    max_pages=max_pages,
                )
            except Exception as e:
                errors.append(f"league {league_provider_id} season {season_try}: {str(e)}")
                continue

            if not fixtures:
                continue

            league_had_rows = True

            for item in fixtures:
                try:
                    fixture_block = item.get("fixture") or {}
                    league_block = item.get("league") or {}
                    teams_block = item.get("teams") or {}
                    goals_block = item.get("goals") or {}

                    home = teams_block.get("home") or {}
                    away = teams_block.get("away") or {}

                    provider_fixture_id = fixture_block.get("id")
                    provider_league_id = league_block.get("id")
                    provider_home_team_id = home.get("id")
                    provider_away_team_id = away.get("id")

                    if not provider_fixture_id or not provider_league_id:
                        skipped += 1
                        continue

                    if not provider_home_team_id or not provider_away_team_id:
                        skipped += 1
                        continue

                    league_id = _ensure_league(
                        provider_league_id=provider_league_id,
                        name=str(league_block.get("name") or f"League {provider_league_id}"),
                        country=str(league_block.get("country") or ""),
                    )

                    home_team_id = _ensure_team(
                        provider_team_id=provider_home_team_id,
                        name=str(home.get("name") or f"Team {provider_home_team_id}"),
                        short_name=(home.get("name") or "")[:3].upper() if home.get("name") else None,
                        logo_url=home.get("logo"),
                    )

                    away_team_id = _ensure_team(
                        provider_team_id=provider_away_team_id,
                        name=str(away.get("name") or f"Team {provider_away_team_id}"),
                        short_name=(away.get("name") or "")[:3].upper() if away.get("name") else None,
                        logo_url=away.get("logo"),
                    )

                    existing = _get_one(
                        "fixtures",
                        "id",
                        "provider_fixture_id",
                        str(provider_fixture_id),
                    )

                    _upsert_fixture(
                        provider_fixture_id=provider_fixture_id,
                        league_id=league_id,
                        home_team_id=home_team_id,
                        away_team_id=away_team_id,
                        kickoff_at=str(fixture_block.get("date")),
                        round_name=(league_block.get("round") or None),
                        status=_status_from_provider(fixture_block),
                        home_goals=goals_block.get("home"),
                        away_goals=goals_block.get("away"),
                        season_id=None,  # dacă ai tabel de sezoane separat, îl legăm după
                    )

                    if existing:
                        updated += 1
                    else:
                        inserted += 1

                except Exception as e:
                    errors.append(f"fixture error league {league_provider_id}: {str(e)}")

            # dacă am găsit fixtures pe sezonul ăsta, nu mai încercăm alte sezoane pentru liga curentă
            break

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
        "seasons_tried": seasons_tried,
        "max_pages": max_pages,
        "errors_count": len(errors),
        "errors_preview": errors[:10],
    }
