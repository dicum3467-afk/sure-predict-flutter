import os
from datetime import date
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.services.api_football import fetch_fixtures_by_league

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(
            status_code=500,
            detail="SYNC_TOKEN nu este setat in environment.",
        )

    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(..., description="API-Football league id (ex: 39 EPL)"),
    season: int = Query(..., description="Season (ex: 2025)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    next_n: Optional[int] = Query(None, description="Cate meciuri sa aduca (limit) ex: 50"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    """
    Face fetch la API-Football si returneaza datele brute (pentru test).
    Tu poti apoi sa salvezi in DB in pasul urmator.
    """
    _check_token(x_sync_token)

    # fallback util la test: daca nu dai date, ia azi->azi
    if not date_from and not date_to:
        today = date.today().isoformat()
        date_from = today
        date_to = today

    limit = next_n or 50

    fixtures = await fetch_fixtures_by_league(
        league_id=league,
        season=season,
        date_from=date_from,
        date_to=date_to,
        status=status,
        limit=limit,
        offset=0,
    )

    return {
        "count": len(fixtures),
        "league": league,
        "season": season,
        "from": date_from,
        "to": date_to,
        "status": status,
        "limit": limit,
        "items": fixtures,
    }
