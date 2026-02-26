import os
from datetime import datetime
from typing import Optional, Any

import httpx
from fastapi import APIRouter, Header, HTTPException, Query
from fastapi.concurrency import run_in_threadpool

from sqlalchemy.orm import Session
from sqlalchemy import select

from app.services.api_football import fetch_fixtures
from app.db import SessionLocal
from app.models.fixture import Fixture

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN nu este setat in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


def _parse_dt(dt_str: Optional[str]) -> Optional[datetime]:
    if not dt_str:
        return None
    # API-Football dă ISO cu timezone (+00:00). Python acceptă cu fromisoformat.
    try:
        return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
    except Exception:
        return None


def _upsert_fixtures(db: Session, items: list[dict[str, Any]], league: int, season: int) -> dict:
    inserted = 0
    updated = 0

    for item in items:
        fx = (item or {}).get("fixture") or {}
        teams = (item or {}).get("teams") or {}
        goals = (item or {}).get("goals") or {}
        league_obj = (item or {}).get("league") or {}
        status = (fx.get("status") or {})

        fixture_id = fx.get("id")
        if not fixture_id:
            continue

        existing = db.execute(
            select(Fixture).where(Fixture.fixture_id == int(fixture_id))
        ).scalar_one_or_none()

        payload = item  # salvăm tot ca raw

        if existing is None:
            obj = Fixture(
                fixture_id=int(fixture_id),
                league_id=int(league_obj.get("id")) if league_obj.get("id") else league,
                season=int(league_obj.get("season")) if league_obj.get("season") else season,
                date_utc=_parse_dt(fx.get("date")),
                status_short=status.get("short"),
                home_team_id=(teams.get("home") or {}).get("id"),
                away_team_id=(teams.get("away") or {}).get("id"),
                home_team_name=(teams.get("home") or {}).get("name"),
                away_team_name=(teams.get("away") or {}).get("name"),
                home_goals=goals.get("home"),
                away_goals=goals.get("away"),
                raw=payload,
            )
            db.add(obj)
            inserted += 1
        else:
            # update câmpuri (upsert)
            existing.league_id = int(league_obj.get("id")) if league_obj.get("id") else existing.league_id
            existing.season = int(league_obj.get("season")) if league_obj.get("season") else existing.season
            existing.date_utc = _parse_dt(fx.get("date")) or existing.date_utc
            existing.status_short = status.get("short") or existing.status_short

            existing.home_team_id = (teams.get("home") or {}).get("id") or existing.home_team_id
            existing.away_team_id = (teams.get("away") or {}).get("id") or existing.away_team_id
            existing.home_team_name = (teams.get("home") or {}).get("name") or existing.home_team_name
            existing.away_team_name = (teams.get("away") or {}).get("name") or existing.away_team_name

            # Goals pot fi None la meciuri neîncepute
            existing.home_goals = goals.get("home") if goals.get("home") is not None else existing.home_goals
            existing.away_goals = goals.get("away") if goals.get("away") is not None else existing.away_goals

            existing.raw = payload
            updated += 1

    db.commit()
    return {"inserted": inserted, "updated": updated, "total_processed": inserted + updated}


def _sync_to_db(league: int, season: int, date_from: Optional[str], date_to: Optional[str], status: Optional[str], next_n: Optional[int]) -> dict:
    # 1) fetch din API
    data = None
    # fetch_fixtures e async, dar aici suntem sync, deci nu-l folosim direct
    # -> facem request sync cu httpx? Mai simplu: apelăm endpoint-ul async dintr-un helper async nu e ok.
    # Așa că facem request direct aici sync:
    api_key = os.getenv("API_FOOTBALL_KEY")
    if not api_key:
        raise RuntimeError("Missing API_FOOTBALL_KEY")

    base_url = "https://v3.football.api-sports.io"
    params: dict[str, Any] = {"league": league, "season": season}
    if date_from:
        params["from"] = date_from
    if date_to:
        params["to"] = date_to
    if status:
        params["status"] = status
    if next_n:
        params["next"] = next_n  # pe free poate da eroare, dar tu deja ai văzut asta

    headers = {"x-apisports-key": api_key}

    with httpx.Client(timeout=30) as client:
        resp = client.get(f"{base_url}/fixtures", params=params, headers=headers)
        resp.raise_for_status()
        data = resp.json()

    items = data.get("response") or []
    # 2) save în DB
    db = SessionLocal()
    try:
        stats = _upsert_fixtures(db, items, league=league, season=season)
    finally:
        db.close()

    return {
        "ok": True,
        "params": params,
        "api_results": data.get("results"),
        "db": stats,
        "errors": data.get("errors"),
    }


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(..., description="API-Football league id (ex: 39 EPL)"),
    season: int = Query(..., description="Season (ex: 2024)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    next_n: Optional[int] = Query(None, description="Paid ex: 50 (free poate refuza)"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    """
    Fetch fixtures din API-Football și le salvează/upsert în Postgres.
    """
    _check_token(x_sync_token)

    # rulează partea sync (httpx + sqlalchemy) într-un thread ca să nu blocheze event loop
    try:
        result = await run_in_threadpool(_sync_to_db, league, season, date_from, date_to, status, next_n)
        return result
    except httpx.HTTPStatusError as e:
        detail = f"API-Football error: {e.response.status_code} - {e.response.text}"
        raise HTTPException(status_code=502, detail=detail)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
