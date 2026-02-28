from __future__ import annotations

import os
from typing import Optional, Dict, Any, List, Tuple

import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn

router = APIRouter(tags=["leagues"])

API_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Missing APISPORTS_KEY / API_FOOTBALL_KEY in environment.")


def _check_token(x_sync_token: Optional[str]) -> None:
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _api_get_leagues(page: int = 1) -> Dict[str, Any]:
    url = "https://v3.football.api-sports.io/leagues"
    headers = {"x-apisports-key": API_KEY, "accept": "application/json"}
    params = {"page": page}

    try:
        resp = requests.get(url, headers=headers, params=params, timeout=30)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"API request failed: {e}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail=f"API error status={resp.status_code}")

    data = resp.json()
    # dacă e suspendat / errors
    if isinstance(data, dict) and data.get("errors"):
        raise HTTPException(status_code=502, detail=f"API errors: {data.get('errors')}")
    return data


@router.post("/leagues/admin-import")
def admin_import_leagues(
    max_pages: int = Query(10, ge=1, le=100),
    activate_top_only: bool = Query(True, description="Daca true: activeaza doar ligile 'top'."),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    Importa ligile din API in tabela leagues.
    - upsert dupa provider_league_id
    - optional: activeaza doar ligile top (default True)
    """
    _check_token(x_sync_token)
    _require_api_key()

    # criteriu simplu "top": leagues.type == 'League' + country, name non-empty
    # (îl poți rafina ulterior cu tier/rank)
    upsert_sql = """
        INSERT INTO leagues (provider_league_id, name, country, tier, is_active)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (provider_league_id)
        DO UPDATE SET
            name = EXCLUDED.name,
            country = EXCLUDED.country,
            tier = EXCLUDED.tier
        RETURNING (xmax = 0) AS inserted;
    """

    inserted = 0
    updated = 0
    total_seen = 0

    # dacă activezi top only, restul le lăsăm inactive
    # (nu le “dezactivăm” dacă erau active deja; doar setăm is_active la insert)
    def is_top(lg: Dict[str, Any]) -> bool:
        # euristică safe
        return (lg.get("type") == "League") and bool(lg.get("name")) and bool((lg.get("country") or {}).get("name"))

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                page = 1
                while page <= max_pages:
                    data = _api_get_leagues(page=page)
                    resp = data.get("response") or []
                    if not resp and page == 1:
                        break

                    paging = data.get("paging") or {}
                    total_pages = int(paging.get("total") or 1)

                    for item in resp:
                        league = item.get("league") or {}
                        country = item.get("country") or {}

                        provider_league_id = league.get("id")
                        name = league.get("name")
                        ctry = country.get("name")
                        lg_type = league.get("type")  # League/Cup
                        # tier: punem League/Cup sau poți pune 1/2/3
                        tier = lg_type or "League"

                        if not provider_league_id or not name:
                            continue

                        active = is_top(league) if activate_top_only else True

                        cur.execute(
                            upsert_sql,
                            (str(provider_league_id), name, ctry, tier, active),
                        )
                        r = cur.fetchone()
                        total_seen += 1
                        if r and r[0] is True:
                            inserted += 1
                        else:
                            updated += 1

                    conn.commit()

                    if page >= total_pages:
                        break
                    page += 1

        return {
            "ok": True,
            "total_seen": total_seen,
            "inserted": inserted,
            "updated": updated,
            "activate_top_only": activate_top_only,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
