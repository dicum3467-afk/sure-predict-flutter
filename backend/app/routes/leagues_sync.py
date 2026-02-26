import os
import httpx
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from app.db import get_conn
from app.services.api_football import fetch_leagues

router = APIRouter(prefix="/admin", tags=["admin"])

def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN nu este setat in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")

@router.post("/sync/leagues")
async def sync_leagues(
    season: int | None = Query(None, description="ex: 2024 (optional)"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    _check_token(x_sync_token)

    try:
        data = await fetch_leagues(season=season)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"API-Football error: {e.response.status_code} - {e.response.text}")

    items = data.get("response", [])
    conn = get_conn()
    inserted = 0

    try:
        with conn.cursor() as cur:
            for it in items:
                league = it.get("league") or {}
                country = it.get("country") or {}
                seasons = it.get("seasons") or []

                league_id = league.get("id")
                name = league.get("name")
                ltype = league.get("type")
                ctry = country.get("name")
                logo = league.get("logo")
                flag = country.get("flag")

                # alegem ultimul sezon din listă (dacă există)
                last_season = None
                if seasons:
                    # seasons: list dicts cu "year"
                    years = [s.get("year") for s in seasons if s.get("year")]
                    last_season = max(years) if years else None

                if not league_id or not name:
                    continue

                cur.execute(
                    """
                    INSERT INTO leagues (league_id, name, type, country, logo, flag, last_season)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (league_id) DO UPDATE SET
                      name = EXCLUDED.name,
                      type = EXCLUDED.type,
                      country = EXCLUDED.country,
                      logo = EXCLUDED.logo,
                      flag = EXCLUDED.flag,
                      last_season = EXCLUDED.last_season
                    """,
                    (league_id, name, ltype, ctry, logo, flag, last_season),
                )
                inserted += 1
    finally:
        conn.close()

    return {"ok": True, "saved": inserted, "season_filter": season}
