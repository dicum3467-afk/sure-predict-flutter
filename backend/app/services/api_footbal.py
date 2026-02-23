import os
import httpx

API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


async def fetch_fixtures_by_league(league_id: str, season: int = 2024):
    """
    Fetch fixtures from API-Football by numeric league id (ex: "39")
    """
    if not API_FOOTBALL_KEY:
        raise RuntimeError("Missing API_FOOTBALL_KEY env var")

    headers = {
        "x-apisports-key": API_FOOTBALL_KEY,
    }

    params = {
        "league": league_id,
        "season": season,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(
            f"{BASE_URL}/fixtures",
            headers=headers,
            params=params,
        )
        resp.raise_for_status()
        return resp.json()
