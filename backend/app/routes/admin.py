from fastapi import APIRouter, Header, HTTPException
import os
import requests
from app.db import get_conn

router = APIRouter(prefix="/admin", tags=["admin"])

API_KEY = os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


def check_token(token: str | None):
    if not token or token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid sync token")


# ✅ NEW — sync leagues
@router.post("/sync/leagues")
def sync_leagues(x_sync_token: str | None = Header(default=None)):
    check_token(x_sync_token)

    url = "https://v3.football.api-sports.io/leagues"
    headers = {"x-apisports-key": API_KEY}

    resp = requests.get(url, headers=headers, timeout=60)
    resp.raise_for_status()
    data = resp.json().get("response", [])

    inserted = 0

    with get_conn() as conn:
        with conn.cursor() as cur:
            for item in data:
                league = item["league"]

                cur.execute(
                    """
                    INSERT INTO leagues (api_league_id, name, country, logo)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (api_league_id) DO NOTHING
                    """,
                    (
                        league["id"],
                        league["name"],
                        item["country"]["name"],
                        league["logo"],
                    ),
                )
                inserted += 1

        conn.commit()

    return {"status": "ok", "inserted": inserted}
