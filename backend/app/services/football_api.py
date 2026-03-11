import os
import requests


API_BASE_URL = os.getenv("FOOTBALL_API_BASE_URL", "").rstrip("/")
API_KEY = os.getenv("FOOTBALL_API_KEY", "")


def _headers():
    return {
        "x-apisports-key": API_KEY,
    }


def get_fixtures(league_id: str, season: int, from_date: str, to_date: str):
    if not API_BASE_URL:
        raise RuntimeError("FOOTBALL_API_BASE_URL is missing")
    if not API_KEY:
        raise RuntimeError("FOOTBALL_API_KEY is missing")

    url = f"{API_BASE_URL}/fixtures"
    params = {
        "league": league_id,
        "season": season,
        "from": from_date,
        "to": to_date,
    }

    response = requests.get(
        url,
        headers=_headers(),
        params=params,
        timeout=30,
    )
    response.raise_for_status()
    return response.json()
