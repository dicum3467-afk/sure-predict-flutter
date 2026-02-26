import os
import httpx
from datetime import date
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query, Depends
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.services.api_football import fetch_fixtures
from app.db import get_db
from app.models.fixture import Fixture

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
    next_n: Optional[int] = Query(None, description="(Paid) ex: 50"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
    db: Session = Depends(get_db),
):
    """
    Fetch fixtures din API-Football si le salveaza in Postgres (UPSERT).
    """
    _check_token(x_sync_token)

    # fallback: daca nu dai date, ia azi->azi (test)
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
    except httpx.HTTPStatusError as e:
        detail = f"API-Football error: {e.response.status_code} - {e.response.text}"
        raise HTTPException(status_code=502, detail=detail)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    api_list = data.get("response", [])
    if not isinstance(api_list, list):
        raise HTTPException(status_code=500, detail="Unexpected API response format (response not list).")

    saved = 0

    for item in api_list:
        item = item or {}
        fx = item.get("fixture", {}) or {}
        teams = item.get("teams", {}) or {}

        fixture_id = fx.get("id")
        if not fixture_id:
            continue

        utc_date = fx.get("date")
        timestamp = fx.get("timestamp")

        status_obj = fx.get("status") or {}
        status_short = status_obj.get("short") if isinstance(status_obj, dict) else None

        home = teams.get("home") or {}
        away = teams.get("away") or {}
        home_team = home.get("name") if isinstance(home, dict) else None
        away_team = away.get("name") if isinstance(away, dict) else None

        stmt = (
            pg_insert(Fixture)
            .values(
                fixture_id=int(fixture_id),
                league_id=int(league),
                season=int(season),
                utc_date=utc_date,
                timestamp=timestamp,
                status_short=status_short,
                home_team=home_team,
                away_team=away_team,
                payload=item,  # pastram tot json-ul brut
            )
            .on_conflict_do_update(
                constraint="uq_fixtures_fixture_id",
                set_={
                    "league_id": int(league),
                    "season": int(season),
                    "utc_date": utc_date,
                    "timestamp": timestamp,
                    "status_short": status_short,
                    "home_team": home_team,
                    "away_team": away_team,
                    "payload": item,
                },
            )
        )

        db.execute(stmt)
        saved += 1

    db.commit()

    return {
        "ok": True,
        "saved": saved,
        "league": league,
        "season": season,
        "date_from": date_from,
        "date_to": date_to,
        "status": status,
        "note": "Fixtures au fost salvate in Postgres (UPSERT).",
    }
