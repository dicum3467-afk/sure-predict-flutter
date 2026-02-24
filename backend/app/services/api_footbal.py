import os
import requests
from typing import List, Dict, Any, Optional


API_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


def fetch_fixtures_by_league(
    league_id: str,
    season: int,
    days_ahead: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Ia meciuri din API-Football și le normalizează
    pentru tabela noastră fixtures.
    """

    if not API_KEY:
        raise RuntimeError("Missing API_FOOTBALL_KEY env var")

    url = f"{BASE_URL}/fixtures"

    params = {
        "league": league_id,
        "season": season,
    }

    headers = {
        "x-apisports-key": API_KEY,
    }

    resp = requests.get(url, headers=headers, params=params, timeout=30)

    if resp.status_code != 200:
        raise RuntimeError(f"API error {resp.status_code}: {resp.text[:200]}")

    data = resp.json()
    response = data.get("response", [])

    fixtures: List[Dict[str, Any]] = []

    for item in response:
        try:
            fx = item.get("fixture", {})
            teams = item.get("teams", {})

            home = (teams.get("home") or {}).get("name")
            away = (teams.get("away") or {}).get("name")

            fixtures.append(
                {
                    "provider_fixture_id": str(fx.get("id")),
                    "kickoff_at": fx.get("date"),
                    "status": (fx.get("status") or {}).get("short"),
                    "home": home,
                    "away": away,
                    # probabilități — momentan None (le vei calcula tu)
                    "p_home": None,
                    "p_draw": None,
                    "p_away": None,
                    "p_gg": None,
                    "p_over25": None,
                    "p_under25": None,
                }
            )
        except Exception:
            # nu vrem să crape tot sync-ul
            continue

    return fixtures
