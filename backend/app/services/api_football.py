import os
import httpx

API_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


async def fetch_fixtures(
    league: int,
    season: int,
    date_from: str | None = None,
    date_to: str | None = None,
    status: str | None = None,
    next_n: int | None = None,
):
    if not API_KEY:
        raise ValueError("Missing API_FOOTBALL_KEY")

    params = {
        "league": league,
        "season": season,
    }

    if date_from:
        params["from"] = date_from
    if date_to:
        params["to"] = date_to
    if status:
        params["status"] = status
    if next_n:
        params["next"] = next_n

    headers = {
        "x-apisports-key": API_KEY
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(
            f"{BASE_URL}/fixtures",
            params=params,
            headers=headers,
        )

        response.raise_for_status()
        return response.json()
