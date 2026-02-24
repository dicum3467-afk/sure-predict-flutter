# backend/app/services/api_football.py

import os
from typing import Any, Dict, List, Optional

import httpx


API_FOOTBALL_BASE_URL = os.getenv("API_FOOTBALL_BASE_URL", "https://v3.football.api-sports.io")
API_FOOTBALL_KEY = os.getenv("API_FOOTBALL_KEY")  # pune-l în Render Env Vars


class ApiFootballError(Exception):
    pass


def _headers() -> Dict[str, str]:
    if not API_FOOTBALL_KEY:
        raise ApiFootballError("Missing API_FOOTBALL_KEY env var")
    return {
        "x-apisports-key": API_FOOTBALL_KEY,
        "accept": "application/json",
    }


def fetch_fixtures_by_league(
    league_id: str,
    season: int,
    days_ahead: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Returnează o listă de fixtures (dict-uri) din API-Football.
    league_id = id numeric de la provider (ex: 39 EPL).
    """

    params: Dict[str, Any] = {
        "league": league_id,
        "season": season,
    }

    # opțional: dacă vrei să limitezi doar următoarele N zile, putem filtra după date local
    # sau putem cere "from/to" dacă providerul suportă. Aici ținem simplu.
    timeout = httpx.Timeout(20.0)

    with httpx.Client(base_url=API_FOOTBALL_BASE_URL, headers=_headers(), timeout=timeout) as client:
        r = client.get("/fixtures", params=params)
        if r.status_code != 200:
            raise ApiFootballError(f"API-Football error {r.status_code}: {r.text[:300]}")

        data = r.json()
        resp = data.get("response") or []
        out: List[Dict[str, Any]] = []

        for item in resp:
            fixture = item.get("fixture", {}) or {}
            teams = item.get("teams", {}) or {}
            goals = item.get("goals", {}) or {}

            provider_fixture_id = fixture.get("id")
            kickoff = fixture.get("date")  # ISO string

            home_name = (teams.get("home") or {}).get("name")
            away_name = (teams.get("away") or {}).get("name")

            status_long = ((fixture.get("status") or {}).get("long")) or ""
            # status scurt pentru DB
            status = (status_long or "").strip()[:32]

            # scor (dacă există)
            hg = goals.get("home")
            ag = goals.get("away")

            out.append(
                {
                    "provider_fixture_id": str(provider_fixture_id) if provider_fixture_id is not None else None,
                    "kickoff_at": kickoff,
                    "status": status,
                    "home": home_name or "",
                    "away": away_name or "",
                    # dacă vrei probabilități, le calculezi tu separat -> aici lăsăm None
                    "p_home": None,
                    "p_draw": None,
                    "p_away": None,
                    "p_gg": None,
                    "p_over25": None,
                    "p_under25": None,
                    "computed_at": None,
                }
            )

        # dacă vrei days_ahead, filtrăm aici simplu după kickoff date (opțional)
        # (am lăsat fără filtrare ca să nu stricăm)
        return out
