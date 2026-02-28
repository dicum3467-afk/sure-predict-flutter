# backend/app/routes/fixtures_sync.py

from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException
import os
from datetime import datetime
import httpx

from app.db import get_conn

router = APIRouter(prefix="/admin/sync", tags=["sync"])

API_KEY = os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


def _dt_from_iso(s: str | None) -> datetime | None:
    """Parse ISO date from API-Football. Returns None if missing/invalid."""
    if not s:
        return None
    try:
        # API often returns "2024-02-28T19:00:00+00:00" or "...Z"
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


@router.post("/fixtures")
async def sync_fixtures(
    league: int,
    season: int,
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
):
    # 0) auth
    if not SYNC_TOKEN:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN missing on server")
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")

    if not API_KEY:
        raise HTTPException(status_code=500, detail="API key missing")

    # 1) find league_id (internal DB id) by api_league_id
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM leagues WHERE api_league_id = %s LIMIT 1",
                (league,),
            )
            row = cur.fetchone()

    if not row:
        raise HTTPException(
            status_code=400,
            detail=f"League {league} not found in DB (table leagues). Sync leagues first / insert it.",
        )

    league_id = row[0]

    # 2) fetch fixtures from API-Football
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {"x-apisports-key": API_KEY}

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.get(url, headers=headers, params={"league": league, "season": season})

    if resp.status_code != 200:
        raise HTTPException(
            status_code=500,
            detail=f"API fetch failed (status={resp.status_code})",
        )

    payload = resp.json()
    fixtures = payload.get("response", []) or []

    # 3) insert fixtures (IMPORTANT: only primitives, no dicts!)
    inserted = 0
    skipped = 0

    sql = """
        INSERT INTO fixtures (
            league_id,
            season,
            api_fixture_id,
            fixture_date,
            status,
            status_short,
            home_team_id,
            home_team,
            away_team_id,
            away_team,
            home_goals,
            away_goals,
            run_type
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (api_fixture_id) DO NOTHING
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            for f in fixtures:
                fixture = f.get("fixture") or {}
                teams = f.get("teams") or {}
                goals = f.get("goals") or {}
                status = fixture.get("status") or {}

                api_fixture_id = fixture.get("id")
                fixture_date = _dt_from_iso(fixture.get("date"))

                status_long = status.get("long")
                status_short = status.get("short")

                home = teams.get("home") or {}
                away = teams.get("away") or {}

                home_team_id = home.get("id")
                home_team = home.get("name")
                away_team_id = away.get("id")
                away_team = away.get("name")

                home_goals = goals.get("home")
                away_goals = goals.get("away")

                # basic validation
                if api_fixture_id is None:
                    skipped += 1
                    continue

                cur.execute(
                    sql,
                    (
                        league_id,
                        season,
                        api_fixture_id,
                        fixture_date,
                        status_long,
                        status_short,
                        home_team_id,
                        home_team,
                        away_team_id,
                        away_team,
                        home_goals,
                        away_goals,
                        "manual",
                    ),
                )

                # psycopg3: rowcount is 1 if inserted, 0 if conflict
                if cur.rowcount == 1:
                    inserted += 1
                else:
                    skipped += 1

        conn.commit()

    return {
        "status": "ok",
        "league": league,
        "season": season,
        "inserted": inserted,
        "skipped": skipped,
        "total_from_api": len(fixtures),
    }
