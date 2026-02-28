import os
from datetime import datetime, timezone, timedelta, date
from typing import Any, Dict, List, Optional

import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["fixtures"])

API_KEY = os.getenv("API_FOOTBALL_KEY") or os.getenv("API_FOOTBALL")  # acceptă ambele
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Missing API_FOOTBALL_KEY env var")


def _check_token(x_sync_token: Optional[str]) -> None:
    if not SYNC_TOKEN:
        raise HTTPException(status_code=500, detail="Missing SYNC_TOKEN env var")
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=14),      # UI-ul tău are max 14
    season: int = Query(2024),
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    Sync fixtures din API-Football în tabela fixtures, pentru ligile active din tabela leagues.
    - ia viitoare + ultimele 2 zile (pentru test / rezultate recente)
    - NU filtrează doar NS, ca să nu rămâi fără date
    """
    _check_token(x_sync_token)
    _require_api_key()

    # ⭐ fereastra inteligentă
    DAYS_BACK = 2
    today = datetime.now(timezone.utc).date()
    date_from: date = today - timedelta(days=DAYS_BACK)
    date_to: date = today + timedelta(days=days_ahead)

    inserted = 0
    skipped = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:

                # ia ligile active
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    """
                )
                leagues = cur.fetchall()

                headers = {
                    "x-apisports-key": API_KEY,
                    "accept": "application/json",
                }

                for league_uuid, provider_league_id in leagues:

                    # ⚠️ provider_league_id trebuie să fie număr (ex: 39, 140 etc)
                    resp = requests.get(
                        "https://v3.football.api-sports.io/fixtures",
                        headers=headers,
                        params={
                            "league": provider_league_id,
                            "season": season,
                            "from": str(date_from),
                            "to": str(date_to),
                            # ⚠️ fără status: luăm și recente + viitoare
                        },
                        timeout=30,
                    )

                    if resp.status_code != 200:
                        raise HTTPException(
                            status_code=500,
                            detail=f"API error league {provider_league_id}: {resp.status_code}",
                        )

                    data = resp.json()
                    items = data.get("response", [])

                    for item in items:
                        fx = item.get("fixture", {}) or {}
                        league_info = item.get("league", {}) or {}

                        provider_fixture_id = fx.get("id")
                        kickoff_iso = fx.get("date")  # ISO string
                        status_short = (fx.get("status") or {}).get("short")

                        round_name = league_info.get("round")

                        # uneori poate lipsi ceva
                        if not provider_fixture_id or not kickoff_iso:
                            skipped += 1
                            continue

                        # convertim kickoff la datetime (UTC)
                        # API-Football dă ISO cu timezone, ex: "2026-02-20T10:46:59+00:00"
                        kickoff_at = None
                        try:
                            kickoff_at = datetime.fromisoformat(kickoff_iso.replace("Z", "+00:00"))
                        except Exception:
                            # fallback
                            kickoff_at = datetime.now(timezone.utc)

                        # INSERT cu "ON CONFLICT" pe provider_fixture_id
                        # ⚠️ presupune că ai index unic pe provider_fixture_id (cum ai zis)
                        cur.execute(
                            """
                            INSERT INTO fixtures (
                                league_id,
                                provider_fixture_id,
                                season_id,
                                home_team_id,
                                away_team_id,
                                kickoff_at,
                                round,
                                status,
                                created_at
                            )
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s, now())
                            ON CONFLICT (provider_fixture_id) DO UPDATE SET
                                kickoff_at = EXCLUDED.kickoff_at,
                                round = EXCLUDED.round,
                                status = EXCLUDED.status
                            """,
                            (
                                league_uuid,
                                str(provider_fixture_id),
                                season,
                                None,
                                None,
                                kickoff_at,
                                round_name,
                                status_short,
                            ),
                        )
                        inserted += 1

            conn.commit()

        return {
            "ok": True,
            "leagues": len(leagues),
            "inserted": inserted,
            "skipped": skipped,
            "from": str(date_from),
            "to": str(date_to),
            "season": season,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
