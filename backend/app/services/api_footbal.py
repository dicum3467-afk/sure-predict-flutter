# backend/app/services/api_football.py
import os
from datetime import date, timedelta
from typing import Any, Dict, List, Optional

import httpx

API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


def _ensure_key() -> None:
    if not API_FOOTBALL_KEY:
        raise RuntimeError("Missing API_FOOTBALL_KEY env var")


def _headers() -> Dict[str, str]:
    return {"x-apisports-key": API_FOOTBALL_KEY}  # type: ignore[arg-type]


async def fetch_fixtures_by_league(
    league_id: str,
    season: int,
    *,
    days_ahead: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Fetch fixtures from API-Football by numeric league id (ex: "39") and season (ex: 2025).
    Returns ONLY the list of fixtures (json["response"]).
    If days_ahead is provided, it limits by date interval [today, today+days_ahead].
    """
    _ensure_key()

    params: Dict[str, Any] = {
        "league": str(league_id).strip(),
        "season": int(season),
    }

    # Optional: limit results to the next X days (more efficient + predictable)
    if days_ahead is not None:
        start = date.today()
        end = start + timedelta(days=int(days_ahead))
        params["from"] = start.isoformat()
        params["to"] = end.isoformat()

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(
            f"{BASE_URL}/fixtures",
            headers=_headers(),
            params=params,
        )
        resp.raise_for_status()
        data = resp.json()

    # API-Football returns: {"get": "...", "parameters": {...}, "errors": ..., "results": N, "response": [ ... ]}
    fixtures = data.get("response")
    if fixtures is None:
        return []

    if isinstance(fixtures, list):
        return fixtures

    # fallback safe
    return []
