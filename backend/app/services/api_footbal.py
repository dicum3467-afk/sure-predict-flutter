import os
from typing import Any, Dict, List, Optional

import httpx


API_FOOTBALL_BASE = "https://v3.football.api-sports.io"


def _headers() -> Dict[str, str]:
    key = os.getenv("API_FOOTBALL_KEY") or os.getenv("RAPIDAPI_KEY")
    host = os.getenv("API_FOOTBALL_HOST") or "v3.football.api-sports.io"

    if not key:
        raise RuntimeError(
            "Lipsește API_FOOTBALL_KEY (sau RAPIDAPI_KEY). "
            "Setează-l în Render Environment."
        )

    # API-Sports acceptă fie x-apisports-key, fie RapidAPI headers (depinde cum ai contul).
    # Încercăm varianta API-Sports direct.
    return {
        "x-apisports-key": key,
        "x-rapidapi-key": key,           # safe fallback
        "x-rapidapi-host": host,         # safe fallback
    }


async def fetch_fixtures_by_league(
    *,
    league: int,
    season: int,
    date_from: Optional[str] = None,  # "YYYY-MM-DD"
    date_to: Optional[str] = None,    # "YYYY-MM-DD"
    status: Optional[str] = None,     # ex: "NS", "FT"
    next_n: Optional[int] = None,     # ex: 50
) -> List[Dict[str, Any]]:
    """
    Returnează lista 'response' de la API-Football.
    """
    params: Dict[str, Any] = {"league": league, "season": season}

    if date_from:
        params["from"] = date_from
    if date_to:
        params["to"] = date_to
    if status:
        params["status"] = status
    if next_n:
        params["next"] = next_n

    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.get(
            f"{API_FOOTBALL_BASE}/fixtures",
            headers=_headers(),
            params=params,
        )
        r.raise_for_status()
        data = r.json()

    return data.get("response", [])
