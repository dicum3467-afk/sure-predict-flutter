from fastapi import APIRouter, HTTPException, Query, Header
from app.db import get_conn

import os
import requests
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/fixtures", tags=["fixtures"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN")
API_KEY = os.getenv("API_FOOTBALL_KEY")


# =========================
# helpers
# =========================

def _check_token(x_sync_token: str | None):
    if not SYNC_TOKEN:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN not set")
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid sync token")


def _require_api_key():
    if not API_KEY:
        raise HTTPException(status_code=500, detail="API_FOOTBALL_KEY not set")


# =========================
# GET fixtures by league
# =========================

@router.get("/by-league")
def fixtures_by_league(
    league: int = Query(...),
    season: int = Query(...),
):
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        provider_fixture_id,
                        league_id,
                        season_id,
                        kickoff_at,
                        status,
                        home_team_id,
                        away_team_id,
                        round
                    FROM fixtures
                    WHERE league_id = %s
                      AND season_id = %s
                    ORDER BY kickoff_at ASC
                    LIMIT 200
                    """,
                    (league, season),
                )
                rows = cur.fetchall()

        return [
            {
                "provider_fixture_id": r[0],
                "league_id": r[1],
                "season_id": r[2],
                "kickoff_at": r[3],
                "status": r[4],
                "home_team_id": r[5],
                "away_team_id": r[6],
                "round": r[7],
            }
            for r in rows
        ]

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# ADMIN SYNC (IMPORTANT)
# =========================

@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(7, ge=1, le=14),
    season: int = Query(2024),
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
):
    """
    Sync fixtures din API-Football în tabela ta reală.
    """

    _check_token(x_sync_token)
    _require_api_key()

    date_from = datetime.now(timezone.utc).date()
    date_to = date_from + timedelta(days=days_ahead)

    inserted = 0
    skipped = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:

                # 🔹 ia ligile active
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    """
                )
                leagues = cur.fetchall()

                headers = {
                    "x-apisports-key": API_KEY,
                    "accept": "application/json",
                }

                for league_id, provider_league_id in leagues:

                    resp = requests.get(
                        "https://v3.football.api-sports.io/fixtures",
                        headers=headers,
                        params={
                            "league": provider_league_id,
                            "season": season,
                            "from": str(date_from),
                            "to": str(date_to),
                        },
                        timeout=30,
                    )

                    if resp.status_code != 200:
                        raise HTTPException(
                            status_code=500,
                            detail=f"API error league {provider_league_id}",
                        )

                    data = resp.json()
                    items = data.get("response", [])

                    for item in items:
                        fx = item.get("fixture", {})
                        teams = item.get("teams", {})
                        league_info = item.get("league", {})
                        status_info = fx.get("status", {})

                        provider_fixture_id = fx.get("id")
                        kickoff_at = fx.get("date")
                        status_short = status_info.get("short")
                        round_name = league_info.get("round")

                        home_team_id = (teams.get("home") or {}).get("id")
                        away_team_id = (teams.get("away") or {}).get("id")

                        if not provider_fixture_id:
                            skipped += 1
                            continue

                        # 🔥 INSERT PE STRUCTURA TA REALĂ
                        cur.execute(
                            """
                            INSERT INTO fixtures (
                                provider_fixture_id,
                                season_id,
                                league_id,
                                home_team_id,
                                away_team_id,
                                kickoff_at,
                                round,
                                status
                            )
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                            ON CONFLICT (provider_fixture_id) DO NOTHING
                            """,
                            (
                                provider_fixture_id,
                                season,          # season_id
                                league_id,       # FK spre leagues.id
                                home_team_id,
                                away_team_id,
                                kickoff_at,
                                round_name,
                                status_short,
                            ),
                        )

                        if cur.rowcount == 1:
                            inserted += 1
                        else:
                            skipped += 1

            conn.commit()

        return {
            "ok": True,
            "inserted": inserted,
            "skipped": skipped,
            "from": str(date_from),
            "to": str(date_to),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
