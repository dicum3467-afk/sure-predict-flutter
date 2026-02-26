import os
from datetime import date
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

# ⚠️ IMPORTANT — verifică numele funcției din api_football.py
from app.services.api_football import fetch_fixtures_by_league

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")

    if not expected:
        raise HTTPException(
            status_code=500,
            detail="SYNC_TOKEN nu este setat.",
        )

    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(...),
    season: int = Query(...),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    next_n: Optional[int] = Query(50),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    _check_token(x_sync_token)

    # fallback pe azi
    if not date_from and not date_to:
        today = date.today().isoformat()
        date_from = today
        date_to = today

    try:
        fixtures = await fetch_fixtures_by_league(
            league_id=league,
            season=season,
            date_from=date_from,
            date_to=date_to,
            status=status,
            limit=next_n,
            offset=0,
        )

        return {
            "count": len(fixtures),
            "items": fixtures,
        }

    except Exception as e:
        # 🔥 ca să vezi eroarea reală în Swagger
        raise HTTPException(status_code=500, detail=str(e))
