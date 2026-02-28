# backend/app/routes/fixtures_sync.py

from fastapi import APIRouter, HTTPException, Query, Header
from app.db import get_conn

import os
import requests
from datetime import datetime, timedelta, timezone


router = APIRouter(prefix="/fixtures", tags=["fixtures"])

# Env vars (Render)
SYNC_TOKEN = os.getenv("SYNC_TOKEN")
API_KEY = os.getenv("API_FOOTBALL_KEY")  # sau API_FOOTBALL_KEY / API_FOOTBALL (depinde ce ai setat)


def _check_token(x_sync_token: str | None):
    if not SYNC_TOKEN:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN is not set on server")
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid sync token")


def _require_api_key():
    if not API_KEY:
        raise HTTPException(status_code=500, detail="API_FOOTBALL_KEY is not set on server")


@router.get("/by-league")
def fixtures_by_league(
    league: int = Query(..., description="Provider league id (ex: 39)"),
    season: int = Query(..., description="Season (ex: 2024)"),
):
    """
    Returnează meciurile din DB pentru o ligă (provider_league_id) și sezon.
    NOTE: aici presupun că ai în tabela fixtures coloanele:
      provider_league_id, season, match_date, home_team, away_team, status, provider_fixture_id
    Ajustează SELECT-ul dacă schema ta diferă.
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        provider_fixture_id,
                        provider_league_id,
                        season,
                        match_date,
                        status,
                        home_team,
                        away_team
                    FROM fixtures
                    WHERE provider_league_id = %s
                      AND season = %s
                    ORDER BY match_date ASC
                    LIMIT 200
                    """,
                    (league, season),
                )
                rows = cur.fetchall()

        # psycopg2 poate returna tuple; le mapăm în dict-uri simple
        result = []
        for r in rows:
            result.append(
                {
                    "provider_fixture_id": r[0],
                    "provider_league_id": r[1],
                    "season": r[2],
                    "match_date": r[3],
                    "status": r[4],
                    "home_team": r[5],
                    "away_team": r[6],
                }
            )
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(7, ge=1, le=14, description="Câte zile în viitor să sincronizeze"),
    season: int = Query(2024, description="Sezonul (ex: 2024)"),
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
):
    """
    Sync fixtures din API-Football pentru ligile active din tabela `leagues` (is_active=true)
    și le inserează în `fixtures`.

    Necesită header:
      X-Sync-Token: <SYNC_TOKEN>

    IMPORTANT:
      - coloanele din INSERT trebuie să fie identice cu schema ta `fixtures`.
    """
    _check_token(x_sync_token)
    _require_api_key()

    # interval: azi -> azi + days_ahead
    # folosim UTC ca să nu ai surprize
    date_from = datetime.now(timezone.utc).date()
    date_to = date_from + timedelta(days=days_ahead)

    inserted = 0
    skipped = 0
    leagues_count = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                # ia ligile active din DB
                cur.execute(
                    """
                    SELECT provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    ORDER BY provider_league_id
                    """
                )
                leagues = cur.fetchall()
                leagues_count = len(leagues)

                headers = {
                    "x-apisports-key": API_KEY,
                    "accept": "application/json",
                }

                for (provider_league_id,) in leagues:
                    # API-Football fixtures endpoint
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
                            detail=f"API error for league {provider_league_id}: {resp.status_code} {resp.text}",
                        )

                    data = resp.json()
                    items = data.get("response", [])

                    for item in items:
                        fx = item.get("fixture", {})
                        teams = item.get("teams", {})
                        status = fx.get("status", {})

                        provider_fixture_id = fx.get("id")
                        match_date = fx.get("date")  # ISO string
                        status_short = status.get("short")

                        home_team = (teams.get("home") or {}).get("name")
                        away_team = (teams.get("away") or {}).get("name")

                        if not provider_fixture_id or not match_date or not home_team or not away_team:
                            skipped += 1
                            continue

                        # === INSERT ÎN DB ===
                        # Ajustează coloanele după schema ta reală din `fixtures`
                        cur.execute(
                            """
                            INSERT INTO fixtures (
                                provider_fixture_id,
                                provider_league_id,
                                season,
                                match_date,
                                status,
                                home_team,
                                away_team
                            )
                            VALUES (%s,%s,%s,%s,%s,%s,%s)
                            ON CONFLICT (provider_fixture_id) DO NOTHING
                            """,
                            (
                                provider_fixture_id,
                                provider_league_id,
                                season,
                                match_date,
                                status_short,
                                home_team,
                                away_team,
                            ),
                        )

                        # rowcount = 1 dacă a inserat, 0 dacă a fost conflict
                        if cur.rowcount == 1:
                            inserted += 1
                        else:
                            skipped += 1

            conn.commit()

        return {
            "ok": True,
            "leagues": leagues_count,
            "inserted": inserted,
            "skipped": skipped,
            "from": str(date_from),
            "to": str(date_to),
            "season": season,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
