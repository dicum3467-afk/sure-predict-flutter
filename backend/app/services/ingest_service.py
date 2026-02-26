import os
import httpx
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.db import get_conn

API_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"

async def ingest_upcoming(days: int = 7, league_provider_id: Optional[int] = None) -> dict:
    """
    Importă fixtures în tabela `fixtures` (DB principală, aceeași folosită de API).
    Opțional: league_provider_id (id-ul de la API-Football) ca să nu tragi tot globul.
    """
    if not API_KEY:
        return {"ok": False, "error": "API_FOOTBALL_KEY missing"}

    headers = {"x-apisports-key": API_KEY}

    date_from = datetime.now(timezone.utc).date()
    date_to = date_from + timedelta(days=days)

    params = {"from": str(date_from), "to": str(date_to)}
    if league_provider_id is not None:
        params["league"] = str(league_provider_id)

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(f"{BASE_URL}/fixtures", headers=headers, params=params)
        resp.raise_for_status()
        data = resp.json()

    conn = get_conn()
    cur = conn.cursor()

    # mapare provider league -> league_id intern
    league_map = {}
    cur.execute("SELECT id, provider_league_id FROM leagues")
    for _id, prov in cur.fetchall():
        league_map[str(prov)] = str(_id)

    inserted = 0
    skipped = 0

    for item in data.get("response", []):
        fx = item.get("fixture", {})
        teams = item.get("teams", {})
        league = item.get("league", {})

        provider_fixture_id = fx.get("id")
        provider_league_id = league.get("id")
        kickoff_at = fx.get("date")
        status = (fx.get("status", {}) or {}).get("short") or "scheduled"

        if provider_fixture_id is None or provider_league_id is None or kickoff_at is None:
            skipped += 1
            continue

        league_id = league_map.get(str(provider_league_id))
        if not league_id:
            # dacă liga nu e în tabela leagues, nu putem lega fixture-ul
            skipped += 1
            continue

        home = (teams.get("home", {}) or {}).get("name")
        away = (teams.get("away", {}) or {}).get("name")

        # evită duplicate
        cur.execute("SELECT 1 FROM fixtures WHERE provider_fixture_id = %s LIMIT 1", (str(provider_fixture_id),))
        if cur.fetchone():
            skipped += 1
            continue

        cur.execute(
            """
            INSERT INTO fixtures (
              provider_fixture_id, league_id, kickoff_at, status, home, away,
              run_type, computed_at, p_home, p_draw, p_away, p_gg, p_over25, p_under25
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """,
            (
                str(provider_fixture_id),
                league_id,
                kickoff_at,
                status.strip().lower(),
                home,
                away,
                "initial",
                datetime.now(timezone.utc).isoformat(),
                None, None, None, None, None, None
            ),
        )
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()

    return {"ok": True, "inserted": inserted, "skipped": skipped}
