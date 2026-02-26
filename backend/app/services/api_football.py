import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Union

import httpx

# API-Football (api-sports) base URL
API_FOOTBALL_BASE_URL = os.getenv("API_FOOTBALL_BASE_URL", "https://v3.football.api-sports.io")
API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY", "").strip()

DEFAULT_TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "30"))


class ApiFootballError(RuntimeError):
    pass


def _ensure_key():
    if not API_FOOTBALL_KEY:
        raise ApiFootballError(
            "Missing API_FOOTBALL_KEY env var. Set it in Render -> Environment Variables."
        )


def _to_yyyy_mm_dd(d: Union[str, date, datetime, None]) -> Optional[str]:
    if d is None:
        return None
    if isinstance(d, str):
        s = d.strip()
        return s if s else None
    if isinstance(d, datetime):
        return d.date().isoformat()
    if isinstance(d, date):
        return d.isoformat()
    return None


async def _get(path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    _ensure_key()
    url = f"{API_FOOTBALL_BASE_URL.rstrip('/')}/{path.lstrip('/')}"
    headers = {"x-apisports-key": API_FOOTBALL_KEY}

    async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
        r = await client.get(url, headers=headers, params=params or {})
        if r.status_code >= 400:
            raise ApiFootballError(f"API-Football HTTP {r.status_code}: {r.text}")

        data = r.json()
        # API-Football structure: { get, parameters, errors, results, paging, response }
        if isinstance(data, dict) and data.get("errors"):
            raise ApiFootballError(f"API-Football errors: {data['errors']}")
        return data


async def fetch_fixtures_by_league(
    league_id: Union[str, int],
    season: Union[str, int],
    date_from: Union[str, date, datetime, None] = None,
    date_to: Union[str, date, datetime, None] = None,
    status: Optional[str] = None,
    limit: int = 200,
    offset: int = 0,
) -> List[Dict[str, Any]]:
    """
    Returnează fixtures (meciuri) dintr-o ligă/sezon.
    - league_id: id liga (ex: 39 EPL)
    - season: ex: 2025
    - date_from/date_to: YYYY-MM-DD (opțional)
    - status: ex: NS, 1H, FT... (opțional)
    - limit/offset: paginare simplă (noi aplicăm după ce primim lista)
    """
    params: Dict[str, Any] = {
        "league": int(league_id),
        "season": int(season),
    }

    df = _to_yyyy_mm_dd(date_from)
    dt = _to_yyyy_mm_dd(date_to)
    if df:
        params["from"] = df
    if dt:
        params["to"] = dt
    if status:
        params["status"] = status

    data = await _get("/fixtures", params=params)
    resp = data.get("response", [])
    if not isinstance(resp, list):
        return []

    # Aplicăm limit/offset local (API-Football are și paging, dar așa e ok pt început)
    start = max(0, int(offset))
    end = start + max(1, int(limit))
    return resp[start:end]


async def fetch_leagues(season: Optional[Union[str, int]] = None) -> List[Dict[str, Any]]:
    """
    Listează ligi. Poți trimite sezonul ca să primești rezultate mai relevante.
    """
    params: Dict[str, Any] = {}
    if season is not None:
        params["season"] = int(season)

    data = await _get("/leagues", params=params)
    resp = data.get("response", [])
    return resp if isinstance(resp, list) else []
