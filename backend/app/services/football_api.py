import os
import requests

API_BASE_URL = os.getenv("FOOTBALL_API_BASE_URL", "")
API_KEY = os.getenv("FOOTBALL_API_KEY", "")


def _headers():
    return {
        "x-apisports-key": API_KEY,
    }


def get_leagues():
    url = f"{API_BASE_URL}/leagues"
    response = requests.get(url, headers=_headers(), timeout=30)
    response.raise_for_status()
    return response.json()


def get_teams(league_id: str, season: int):
    url = f"{API_BASE_URL}/teams"
    params = {"league": league_id, "season": season}
    response = requests.get(url, headers=_headers(), params=params, timeout=30)
    response.raise_for_status()
    return response.json()


def get_fixtures(league_id: str, season: int, from_date: str, to_date: str):
    url = f"{API_BASE_URL}/fixtures"
    params = {
        "league": league_id,
        "season": season,
        "from": from_date,
        "to": to_date,
    }
    response = requests.get(url, headers=_headers(), params=params, timeout=30)
    response.raise_for_status()
    return response.json()
