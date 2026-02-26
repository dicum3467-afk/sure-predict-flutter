import os
import httpx
from typing import Optional, Any, Dict

API_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"

def _headers() -> Dict[str, str]:
    if not API_KEY:
        raise ValueError("Missing API_FOOTBALL_KEY")
    return {"x-apisports-key": API_KEY}

async def _get(path: str, params: Dict[str, Any]) -> Dict[str, Any]:
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.get(f"{BASE_URL}/{path}", params=params, headers=_headers())
        r.raise_for_status()
        return r.json()

async def fetch_fixtures(
    league: int,
    season: int,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    status: Optional[str] = None,
    next_n: Optional[int] = None,
):
    params: Dict[str, Any] = {"league": league, "season": season}

    if date_from:
        params["from"] = date_from
    if date_to:
        params["to"] = date_to
    if status:
        params["status"] = status
    if next_n:
        params["next"] = next_n  # atenție: pe free plan poate să nu meargă

    return await _get("fixtures", params)

async def fetch_leagues(season: Optional[int] = None):
    params: Dict[str, Any] = {}
    if season:
        params["season"] = season
    return await _get("leagues", params)

async def fetch_teams(league: int, season: int):
    params: Dict[str, Any] = {"league": league, "season": season}
    return await _get("teams", params)
