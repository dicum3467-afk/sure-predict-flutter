# backend/app/services/api_football.py

import os
from typing import Any, Dict, List, Optional

import httpx


API_BASE = os.getenv("API_FOOTBALL_BASE", "https://v3.football.api-sports.io")


def _get_headers() -> Dict[str, str]:
    """
    Suport 2 variante:
    - direct API-SPORTS:  x-apisports-key
    - RapidAPI:           X-RapidAPI-Key + X-RapidAPI-Host
    """
    key = os.getenv("API_FOOTBALL_KEY") or os.getenv("RAPIDAPI_KEY")
    if not key:
        raise RuntimeError("Missing API key env. Set API_FOOTBALL_KEY (or RAPIDAPI_KEY).")

    rapid_host = os.getenv("API_FOOTBALL_HOST", "v3.football.api-sports.io")

    # Dacă userul setează API_FOOTBALL_MODE=apisports, folosim headerul apisports
    mode = (os.getenv("API_FOOTBALL_MODE") or "rapidapi").lower().strip()

    if mode == "apisports":
        return {"x-apisports-key": key}

    # default: RapidAPI
    return {
        "X-RapidAPI-Key": key,
        "X-RapidAPI-Host": rapid_host,
    }


async def _get(path: str, params: Dict[str, Any]) -> Dict[str, Any]:
    url = f"{API_BASE}{path}"
    headers = _get_headers()

    timeout = float(os.getenv("API_FOOTBALL_TIMEOUT", "20"))
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.get(url, headers=headers, params=params)
        r.raise_for_status()
        return r.json()


def _as_iso_dt(fx: Dict[str, Any]) -> Optional[str]:
    # API-Football: fixture.date este ISO
    fixture = fx.get("fixture") or {}
    return fixture.get("date")


def _status_short(fx: Dict[str, Any]) -> str:
    st = ((fx.get("fixture") or {}).get("status") or {})
    return (st.get("short") or "").strip()


def _team_name(side: str, fx: Dict[str, Any]) -> str:
    teams = fx.get("teams") or {}
    team = teams.get(side) or {}
    return (team.get("name") or "").strip()


def _predictions_flat(pred: Dict[str, Any]) -> Dict[str, Optional[float]]:
    """
    Dacă folosești endpoint /predictions, API-Football dă probabilități în:
      response[0].predictions.percent.home / draw / away (ex "45%")
    Aici le transformăm în float 0..100
    """
    out = {"p_home": None, "p_draw": None, "p_away": None, "p_gg": None, "p_over25": None, "p_under25": None}

    p = pred.get("predictions") or {}
    percent = p.get("percent") or {}

    def pct(x: Any) -> Optional[float]:
        if x is None:
            return None
        if isinstance(x, (int, float)):
            return float(x)
        s = str(x).replace("%", "").strip()
        try:
            return float(s)
        except Exception:
            return None

    out["p_home"] = pct(percent.get("home"))
    out["p_draw"] = pct(percent.get("draw"))
    out["p_away"] = pct(percent.get("away"))

    # restul le poți completa când implementezi endpointuri extra
    return out


async def fetch_fixtures_by_league(
    league_id: str,
    season: int,
    days_ahead: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Returnează o listă flat pentru DB-ul tău, cu chei:
      provider_fixture_id, kickoff_at, status, home, away
    + câmpuri de probabilități (momentan None dacă nu tragi predictions).
    """
    params: Dict[str, Any] = {"league": league_id, "season": season}

    # opțional: dacă vrei doar viitorul apropiat, API-Football are "next"
    # days_ahead nu e direct param standard, deci îl ignorăm aici ca să nu crape.
    # (îl poți implementa cu date_from/date_to ulterior)
    data = await _get("/fixtures", params=params)

    items = (data.get("response") or [])
    out: List[Dict[str, Any]] = []

    for it in items:
        fixture = it.get("fixture") or {}
        fid = fixture.get("id")
        if not fid:
            continue

        out.append(
            {
                "provider_fixture_id": str(fid),
                "kickoff_at": _as_iso_dt(it),
                "status": _status_short(it),
                "home": _team_name("home", it),
                "away": _team_name("away", it),
                # probabilități – dacă nu chemi /predictions, rămân None
                "p_home": None,
                "p_draw": None,
                "p_away": None,
                "p_gg": None,
                "p_over25": None,
                "p_under25": None,
            }
        )

    return out
