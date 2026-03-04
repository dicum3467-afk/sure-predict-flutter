from __future__ import annotations
import os
import time
from typing import Dict, Any, Optional

import httpx

# IMPORTANT: aici imporți funcțiile tale reale de DB/upsert
# adaptează importurile la proiectul tău:
from app.db import supabase_client  # trebuie să existe în proiectul tău
from app.services.fixtures_ingest import ingest_fixtures_payload  # tu o creezi / o ai deja


APISPORTS_HOST = os.getenv("APISPORTS_HOST", "v3.football.api-sports.io")
APISPORTS_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY")

DEFAULT_TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "25"))


def _headers() -> Dict[str, str]:
    if not APISPORTS_KEY:
        raise RuntimeError("Missing APISPORTS_KEY / API_FOOTBALL_KEY")
    return {
        "x-apisports-key": APISPORTS_KEY,
        "accept": "application/json",
    }


def _get_with_retry(url: str, params: dict, tries: int = 4) -> dict:
    last_err: Optional[Exception] = None
    for i in range(tries):
        try:
            with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                r = client.get(url, headers=_headers(), params=params)
                r.raise_for_status()
                return r.json()
        except Exception as e:
            last_err = e
            # backoff: 1s, 2s, 4s, 8s
            time.sleep(2**i)
    raise RuntimeError(f"API request failed after retries: {last_err}")


def run_fixtures_sync_job(
    days_ahead: int = 30,
    past_days: int = 7,
    season: Optional[int] = None,
    max_pages: int = 5,
    season_lookback: int = 2,
) -> Dict[str, Any]:
    """
    Job RQ: sincronizează fixtures pentru ligile active.
    Rulează în worker (nu în request), deci nu mai ai 502.
    Returnează sumar (inserted/updated/etc).
    """

    # 1) ia ligile active din DB
    leagues = supabase_client.table("leagues").select("id, provider_league_id, country, name, season").eq("is_active", True).execute().data or []

    inserted = 0
    updated = 0
    skipped = 0

    # 2) pentru fiecare ligă: fetch fixtures pe interval
    base_url = f"https://{APISPORTS_HOST}/fixtures"

    for lg in leagues:
        provider_league_id = lg["provider_league_id"]

        # sezon: dacă nu e dat, folosește liga.season sau detect logic (tu ai deja)
        use_season = season or lg.get("season")

        # IMPORTANT: pe free plan nu folosi "next"
        # folosește from/to în loc
        # calculează datele în serviciul tău sau aici (simplificat: trimite parametri către serviciu)
        params = {
            "league": provider_league_id,
            "season": use_season,
            # serviciul tău poate calcula from/to din days_ahead/past_days
            "timezone": "Europe/Bucharest",
        }

        data = _get_with_retry(base_url, params=params)
        # 3) upsert în DB (tu ai deja logica asta în fișierele tale)
        # ingest_fixtures_payload trebuie să returneze counters
        res = ingest_fixtures_payload(data, league_id=lg["id"])
        inserted += int(res.get("inserted", 0))
        updated += int(res.get("updated", 0))
        skipped += int(res.get("skipped", 0))

    return {
        "ok": True,
        "leagues": len(leagues),
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "days_ahead": days_ahead,
        "past_days": past_days,
        "season": season,
        "max_pages": max_pages,
        "season_lookback": season_lookback,
    }
