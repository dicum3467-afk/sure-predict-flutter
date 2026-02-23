import os
import httpx

API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


async def fetch_fixtures_by_league(provider_league_id: str):
    """
    Fetch fixtures from API-Football by league id
    """

    headers = {
        "x-apisports-key": API_FOOTBALL_KEY,
    }

    params = {
        "league": provider_league_id,
        "season": 2024,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(
            f"{BASE_URL}/fixtures",
            headers=headers,
            params=params,
        )
        resp.raise_for_status()
        return resp.json()
