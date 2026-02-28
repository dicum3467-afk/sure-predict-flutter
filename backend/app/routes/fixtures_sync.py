from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Header
from datetime import datetime, timezone, timedelta
import os
import requests

from app.db import get_conn

router = APIRouter(tags=["fixtures"])

API_KEY = os.getenv("API_FOOTBALL_KEY") or os.getenv("API_FOOTBALL")

def _require_api_key():
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Missing API_FOOTBALL_KEY env var")

def _check_token(x_sync_token: Optional[str]):
    expected = os.getenv("SYNC_TOKEN")
    if expected and x_sync_token != expected:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")

@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=14),
    past_days: int = Query(2, ge=0, le=14),  # ✅ NOU: cate zile in trecut
    season: Optional[int] = Query(None),
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
):
    """
    Sync fixtures din API-Football in tabela fixtures, pentru ligile active din tabela leagues.

    - viitoare: days_ahead (max 14)
    - trecute: past_days (max 14)  ✅ NOU
    - NU filtram doar NS (altfel risti 0 rezultate)
    """

    _check_token(x_sync_token)
    _require_api_key()

    # intervalul de sync: (azi - past_days) -> (azi + days_ahead)
    today = datetime.now(timezone.utc).date()
    date_from = today - timedelta(days=past_days)
    date_to = today + timedelta(days=days_ahead)

    # daca season nu e dat, folosim anul "date_to" (de obicei ok pt fixtures)
    used_season = season if season is not None else date_to.year

    inserted = 0
    skipped = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                # ia ligile active
                cur.execute("""
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                """)
                leagues = cur.fetchall()

                headers = {
                    "x-apisports-key": API_KEY,
                    "accept": "application/json",
                }

                for league_uuid, provider_league_id in leagues:
                    resp = requests.get(
                        "https://v3.football.api-sports.io/fixtures",
                        headers=headers,
                        params={
                            "league": provider_league_id,
                            "season": used_season,
                            "from": str(date_from),
                            "to": str(date_to),
                            # NU punem status aici ca sa nu ramanem fara date
                        },
                        timeout=30,
                    )

                    if resp.status_code != 200:
                        raise HTTPException(
                            status_code=500,
                            detail=f"API error league={provider_league_id} status={resp.status_code} body={resp.text[:200]}",
                        )

                    data = resp.json()
                    items = data.get("response", []) or []

                    for item in items:
                        fx = item.get("fixture", {}) or {}
                        teams = item.get("teams", {}) or {}
                        goals = item.get("goals", {}) or {}
                        status_info = (fx.get("status", {}) or {})
                        league_info = item.get("league", {}) or {}

                        provider_fixture_id = fx.get("id")
                        if not provider_fixture_id:
                            skipped += 1
                            continue

                        kickoff_str = fx.get("date")  # ISO string
                        if not kickoff_str:
                            skipped += 1
                            continue

                        # transformam in datetime aware UTC (Postgres ok)
                        try:
                            kickoff_at = datetime.fromisoformat(kickoff_str.replace("Z", "+00:00"))
                        except Exception:
                            skipped += 1
                            continue

                        home_team = (teams.get("home", {}) or {}).get("name")
                        away_team = (teams.get("away", {}) or {}).get("name")

                        home_goals = goals.get("home")
                        away_goals = goals.get("away")

                        status = status_info.get("short") or status_info.get("long") or "UNKNOWN"

                        # IMPORTANT: trebuie sa ai unique index pe provider_fixture_id (tu il ai deja)
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

                        # rowcount = 1 si la insert, si la update in multe cazuri
                        inserted += 1

                conn.commit()

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")

    return {
        "ok": True,
        "leagues": len(leagues) if 'leagues' in locals() else 0,
        "upserted": inserted,   # upserted = insert + update
        "skipped": skipped,
        "from": str(date_from),
        "to": str(date_to),
        "season": used_season,
        "past_days": past_days,
        "days_ahead": days_ahead,
                            }
