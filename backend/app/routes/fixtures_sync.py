import os
from datetime import date
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.services.api_football import fetch_fixtures

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")

    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN nu este setat în environment.")

    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(..., description="API-Football league id (ex: 39 EPL)"),
    season: int = Query(..., description="Season (ex: 2025)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    next_n: Optional[int] = Query(50, description="ex: 50"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    """
    Fetch fixtures din API-Football și returnează datele brute (pentru test).
    """
    _check_token(x_sync_token)

    # fallback util la test: dacă nu dai date, ia azi->azi
    if not date_from and not date_to:
        today = date.today().isoformat()
        date_from = today
        date_to = today

    try:
        data = await fetch_fixtures(
            league=league,
            season=season,
            date_from=date_from,
            date_to=date_to,
            status=status,
            next_n=next_n,
        )

        # API-Football returnează de obicei dict cu chei: get, parameters, results, response, errors...
        # Noi întoarcem tot ca să vezi exact ce vine.
        return data

    except httpx.HTTPStatusError as e:
        # dacă API-Football răspunde 4xx/5xx
        detail = f"API-Football error: {e.response.status_code} - {e.response.text}"
        raise HTTPException(status_code=502, detail=detail)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
