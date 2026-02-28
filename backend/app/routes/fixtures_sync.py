from fastapi import APIRouter, Header, HTTPException
import os
import httpx
from app.db import get_conn

router = APIRouter(prefix="/admin/sync", tags=["sync"])

API_KEY = os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


@router.post("/fixtures")
async def sync_fixtures(
    league: int,
    season: int,
    x_sync_token: str = Header(None),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")

    if not API_KEY:
        raise HTTPException(status_code=500, detail="API key missing")

    # 1) ia league_uuid (obligatoriu)
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

    league_uuid = row["id"]

    # 2) fetch fixtures
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {"x-apisports-key": API_KEY}

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.get(url, headers=headers, params={"league": league, "season": season})

    if resp.status_code != 200:
        raise HTTPException(status_code=500, detail="API fetch failed")

    data = resp.json()
    fixtures = data.get("response", [])

    inserted = 0

    with get_conn() as conn:
        with conn.cursor() as cur:
            for f in fixtures:
                cur.execute(
                    """
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
                      run_type,
                      raw
                    )
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (api_fixture_id) DO NOTHING
                    """,
                    (
                        league_uuid,
                        season,
                        f["fixture"]["id"],
                        f["fixture"]["date"],
                        f["fixture"]["status"]["long"],
                        f["fixture"]["status"]["short"],
                        f["teams"]["home"]["id"],
                        f["teams"]["home"]["name"],
                        f["teams"]["away"]["id"],
                        f["teams"]["away"]["name"],
                        f["goals"]["home"],
                        f["goals"]["away"],
                        "api_sync",
                        f,
                    ),
                )
                inserted += cur.rowcount  # 1 dacă a inserat, 0 dacă a fost conflict

        conn.commit()

    return {"status": "ok", "inserted": inserted, "total": len(fixtures)}
