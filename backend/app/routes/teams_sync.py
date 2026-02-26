import os
import httpx
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from app.db import get_conn
from app.services.api_football import fetch_teams

router = APIRouter(prefix="/admin", tags=["admin"])

def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN nu este setat in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")

@router.post("/sync/teams")
async def sync_teams(
    league: int = Query(..., description="ex: 39"),
    season: int = Query(..., description="ex: 2024"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    _check_token(x_sync_token)

    try:
        data = await fetch_teams(league=league, season=season)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"API-Football error: {e.response.status_code} - {e.response.text}")

    items = data.get("response", [])
    conn = get_conn()

    saved_teams = 0
    saved_links = 0

    try:
        with conn.cursor() as cur:
            for it in items:
                team = it.get("team") or {}
                team_id = team.get("id")
                name = team.get("name")
                code = team.get("code")
                country = team.get("country")
                founded = team.get("founded")
                national = team.get("national")
                logo = team.get("logo")

                if not team_id or not name:
                    continue

                # upsert team
                cur.execute(
                    """
                    INSERT INTO teams (team_id, name, code, country, founded, national, logo)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (team_id) DO UPDATE SET
                      name = EXCLUDED.name,
                      code = EXCLUDED.code,
                      country = EXCLUDED.country,
                      founded = EXCLUDED.founded,
                      national = EXCLUDED.national,
                      logo = EXCLUDED.logo
                    """,
                    (team_id, name, code, country, founded, national, logo),
                )
                saved_teams += 1

                # link league <-> team on season
                cur.execute(
                    """
                    INSERT INTO league_teams (league_id, season, team_id)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                    """,
                    (league, season, team_id),
                )
                saved_links += 1
    finally:
        conn.close()

    return {
        "ok": True,
        "league": league,
        "season": season,
        "teams_upserted": saved_teams,
        "links_saved": saved_links,
          }
