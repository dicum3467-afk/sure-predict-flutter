from fastapi import APIRouter, Depends, Header, HTTPException
import os
import requests
from datetime import datetime, timedelta
from app.db import get_conn

router = APIRouter(prefix="/admin", tags=["admin"])

API_KEY = os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


def check_token(x_sync_token: str = Header(...)):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid sync token")


@router.post("/sync/fixtures")
def sync_fixtures(days_ahead: int = 7, _: str = Depends(check_token)):
    conn = get_conn()
    cur = conn.cursor()

    date_from = datetime.utcnow().date()
    date_to = date_from + timedelta(days=days_ahead)

    url = "https://v3.football.api-sports.io/fixtures"

    cur.execute("SELECT provider_league_id FROM leagues WHERE is_active = true")
    leagues = cur.fetchall()

    headers = {"x-apisports-key": API_KEY}

    inserted = 0

    for (league_id,) in leagues:
        params = {
            "league": league_id,
            "from": str(date_from),
            "to": str(date_to),
        }

        r = requests.get(url, headers=headers, params=params)
        data = r.json()

        for item in data.get("response", []):
            fixture = item["fixture"]
            teams = item["teams"]

            cur.execute(
                """
                INSERT INTO fixtures (
                    provider_fixture_id,
                    league_id,
                    home_team,
                    away_team,
                    match_date,
                    status
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (provider_fixture_id) DO NOTHING
                """,
                (
                    fixture["id"],
                    league_id,
                    teams["home"]["name"],
                    teams["away"]["name"],
                    fixture["date"],
                    fixture["status"]["short"],
                ),
            )
            inserted += 1

    conn.commit()
    cur.close()
    conn.close()

    return {"inserted": inserted}
