from typing import Optional, Dict, Any, List, Tuple
from fastapi import APIRouter, HTTPException, Query, Header
from datetime import datetime, timezone, timedelta
import os
import time
import requests

from app.db import get_conn

router = APIRouter(tags=["fixtures"])

API_KEY = os.getenv("API_FOOTBALL_KEY") or os.getenv("API_FOOTBALL")


def _require_api_key():
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Missing API_FOOTBALL_KEY env var (API_FOOTBALL_KEY)")


def _check_token(x_sync_token: Optional[str]):
    expected = os.getenv("SYNC_TOKEN")
    if expected and x_sync_token != expected:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _api_get_with_retry(
    url: str,
    headers: Dict[str, str],
    params: Dict[str, Any],
    timeout: int = 30,
    max_retries: int = 6,
) -> requests.Response:
    backoff = 1.5
    last_resp: Optional[requests.Response] = None

    for _ in range(max_retries):
        resp = requests.get(url, headers=headers, params=params, timeout=timeout)
        last_resp = resp

        if resp.status_code == 200:
            return resp

        # Rate limit
        if resp.status_code == 429:
            retry_after = resp.headers.get("Retry-After")
            if retry_after:
                try:
                    sleep_s = float(retry_after)
                except Exception:
                    sleep_s = backoff
            else:
                sleep_s = backoff
            time.sleep(sleep_s)
            backoff = min(backoff * 2, 20)
            continue

        # server errors retry
        if 500 <= resp.status_code <= 599:
            time.sleep(backoff)
            backoff = min(backoff * 2, 20)
            continue

        # other errors -> stop
        return resp

    return last_resp if last_resp is not None else resp  # type: ignore


def _parse_kickoff(dt_str: str) -> Optional[datetime]:
    if not dt_str:
        return None
    try:
        return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
    except Exception:
        return None


def _fetch_all_fixtures_for_league(
    provider_league_id: int,
    season: int,
    date_from: str,
    date_to: str,
    headers: Dict[str, str],
    max_pages: int = 10,
) -> Tuple[List[Dict[str, Any]], int]:
    """
    Returneaza (items, pages_fetched) cu paginare.
    """
    url = "https://v3.football.api-sports.io/fixtures"
    all_items: List[Dict[str, Any]] = []
    page = 1
    pages_fetched = 0

    while True:
        params = {
            "league": provider_league_id,
            "season": season,
            "from": date_from,
            "to": date_to,
            "page": page,
        }

        resp = _api_get_with_retry(url, headers=headers, params=params, timeout=30, max_retries=6)
        if resp.status_code != 200:
            raise HTTPException(
                status_code=500,
                detail=f"API error league={provider_league_id} season={season} page={page} "
                       f"status={resp.status_code} body={resp.text[:250]}",
            )

        data = resp.json() or {}
        items = data.get("response", []) or []
        all_items.extend(items)

        paging = data.get("paging", {}) or {}
        current = int(paging.get("current", page) or page)
        total = int(paging.get("total", page) or page)

        pages_fetched += 1

        if current >= total:
            break

        page += 1
        if page > max_pages:
            break

    return all_items, pages_fetched


def _choose_best_season_for_league(
    provider_league_id: int,
    candidate_seasons: List[int],
    date_from: str,
    date_to: str,
    headers: Dict[str, str],
    max_pages: int,
) -> Tuple[int, List[Dict[str, Any]], int]:
    """
    Incearca mai multe sezoane si alege sezonul cu cele mai multe items.
    Return: (best_season, best_items, pages_fetched_for_best)
    """
    best_season = candidate_seasons[0]
    best_items: List[Dict[str, Any]] = []
    best_pages = 0

    for s in candidate_seasons:
        items, pages = _fetch_all_fixtures_for_league(
            provider_league_id=provider_league_id,
            season=s,
            date_from=date_from,
            date_to=date_to,
            headers=headers,
            max_pages=max_pages,
        )
        if len(items) > len(best_items):
            best_items = items
            best_season = s
            best_pages = pages

        # mic shortcut: daca am gasit destule, nu mai incercam (optional)
        if len(best_items) >= 50:
            break

    return best_season, best_items, best_pages


@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=14),
    past_days: int = Query(2, ge=0, le=14),
    season: Optional[int] = Query(None),
    max_pages: int = Query(10, ge=1, le=50),
    season_lookback: int = Query(2, ge=0, le=5),  # PRO++: cate sezoane in spate incercam
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
):
    """
    PRO++ Sync fixtures cu:
      - past_days + days_ahead
      - paginare
      - retry la 429/5xx
      - auto-detect sezon per liga (daca season nu e trimis)
    """

    _check_token(x_sync_token)
    _require_api_key()

    today = datetime.now(timezone.utc).date()
    date_from = today - timedelta(days=past_days)
    date_to = today + timedelta(days=days_ahead)

    headers = {
        "x-apisports-key": API_KEY,
        "accept": "application/json",
    }

    upserted = 0
    skipped = 0
    total_pages = 0
    total_items_fetched = 0

    league_season_choices: List[Dict[str, Any]] = []

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, provider_league_id, name
                    FROM leagues
                    WHERE is_active = true
                """)
                leagues = cur.fetchall()

                for league_uuid, provider_league_id, league_name in leagues:
                    provider_league_id_int = int(provider_league_id)

                    if season is not None:
                        used_season = int(season)
                        items, pages_fetched = _fetch_all_fixtures_for_league(
                            provider_league_id=provider_league_id_int,
                            season=used_season,
                            date_from=str(date_from),
                            date_to=str(date_to),
                            headers=headers,
                            max_pages=max_pages,
                        )
                    else:
                        # PRO++: candidate seasons
                        # folosim anul de la date_to ca "curent" + inapoi season_lookback
                        base = int(date_to.year)
                        candidate_seasons = [base - i for i in range(0, season_lookback + 1)]
                        used_season, items, pages_fetched = _choose_best_season_for_league(
                            provider_league_id=provider_league_id_int,
                            candidate_seasons=candidate_seasons,
                            date_from=str(date_from),
                            date_to=str(date_to),
                            headers=headers,
                            max_pages=max_pages,
                        )

                    league_season_choices.append({
                        "league": league_name,
                        "provider_league_id": provider_league_id_int,
                        "season_used": used_season,
                        "items": len(items),
                        "pages": pages_fetched,
                    })

                    total_pages += pages_fetched
                    total_items_fetched += len(items)

                    for item in items:
                        fx = item.get("fixture", {}) or {}
                        teams = item.get("teams", {}) or {}
                        goals = item.get("goals", {}) or {}
                        status_info = (fx.get("status", {}) or {})

                        provider_fixture_id = fx.get("id")
                        if not provider_fixture_id:
                            skipped += 1
                            continue

                        kickoff_at = _parse_kickoff(fx.get("date"))
                        if not kickoff_at:
                            skipped += 1
                            continue

                        home_team = (teams.get("home", {}) or {}).get("name")
                        away_team = (teams.get("away", {}) or {}).get("name")

                        home_goals = goals.get("home")
                        away_goals = goals.get("away")

                        status = status_info.get("short") or status_info.get("long") or "UNKNOWN"

                        # Upsert pe provider_fixture_id
                        cur.execute(
                            """
                            INSERT INTO fixtures (
                                league_id,
                                provider_fixture_id,
                                kickoff_at,
                                status,
                                home_team,
                                away_team,
                                home_goals,
                                away_goals,
                                season
                            )
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                            ON CONFLICT (provider_fixture_id) DO UPDATE SET
                                league_id = EXCLUDED.league_id,
                                kickoff_at = EXCLUDED.kickoff_at,
                                status = EXCLUDED.status,
                                home_team = EXCLUDED.home_team,
                                away_team = EXCLUDED.away_team,
                                home_goals = EXCLUDED.home_goals,
                                away_goals = EXCLUDED.away_goals,
                                season = EXCLUDED.season
                            """,
                            (
                                league_uuid,
                                str(provider_fixture_id),
                                kickoff_at,
                                status,
                                home_team,
                                away_team,
                                home_goals,
                                away_goals,
                                used_season,
                            ),
                        )
                        upserted += 1

                conn.commit()

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")

    # sortam ca sa vezi rapid ligile cu 0 items
    league_season_choices.sort(key=lambda x: x["items"], reverse=True)

    return {
        "ok": True,
        "from": str(date_from),
        "to": str(date_to),
        "past_days": past_days,
        "days_ahead": days_ahead,
        "season_param": season,
        "season_lookback": season_lookback,
        "max_pages": max_pages,
        "leagues_active": len(leagues) if "leagues" in locals() else 0,
        "pages_fetched_total": total_pages,
        "items_fetched_total": total_items_fetched,
        "upserted": upserted,
        "skipped": skipped,
        "league_season_choices": league_season_choices,
                        }
