# backend/app/routes/fixtures_sync.py

import os
import httpx
from datetime import date
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.services.api_football import fetch_fixtures

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN nu este setat in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(..., description="API-Football league id (ex: 39 EPL)"),
    season: int = Query(..., description="Season (ex: 2024)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    # IMPORTANT: pe FREE nu ai voie next; default trebuie sa fie None
    next_n: Optional[int] = Query(None, description="(Paid) ex: 50"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    """
    Fetch fixtures din API-Football si returneaza datele brute (pentru test).
    (In pasul urmator poti salva in DB.)
    """
    _check_token(x_sync_token)

    # fallback util la test: daca nu dai date, ia azi->azi
    if not date_from and not date_to:
        today = date.today().isoformat()
        date_from = today
        date_to = today

    # Plan FREE: nu trimite parametrul next deloc (altfel API-Football returneaza eroare)
    next_n = None

    try:
        data = await fetch_fixtures(
            league=league,
            season=season,
            date_from=date_from,
            date_to=date_to,
            status=status,
            next_n=next_n,  # None => nu se trimite "next" in request
        )
        return data

    except httpx.HTTPStatusError as e:
        detail = f"API-Football error: {e.response.status_code} - {e.response.text}"
        raise HTTPException(status_code=502, detail=detail)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
