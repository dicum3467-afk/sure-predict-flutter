from typing import Optional, Any
from datetime import datetime, date

from fastapi import APIRouter, Query, HTTPException
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models.fixture import Fixture

router = APIRouter(tags=["fixtures"])


def _parse_date(d: Optional[str]) -> Optional[date]:
    if not d:
        return None
    return date.fromisoformat(d)


def _to_dict(row: Fixture) -> dict[str, Any]:
    return {
        "fixture_id": row.fixture_id,
        "league_id": row.league_id,
        "season": row.season,
        "date_utc": row.date_utc.isoformat() if row.date_utc else None,
        "status_short": row.status_short,
        "home_team": {
            "id": row.home_team_id,
            "name": row.home_team_name,
            "goals": row.home_goals,
        },
        "away_team": {
            "id": row.away_team_id,
            "name": row.away_team_name,
            "goals": row.away_goals,
        },
        # dacă vrei și payload complet:
        "raw": row.raw,
    }


def _get_fixtures_db(
    league: Optional[int],
    season: Optional[int],
    date_from: Optional[str],
    date_to: Optional[str],
    status: Optional[str],
    team_id: Optional[int],
    limit: int,
    offset: int,
) -> dict[str, Any]:
    db: Session = SessionLocal()
    try:
        filters = []

        if league is not None:
            filters.append(Fixture.league_id == league)
        if season is not None:
            filters.append(Fixture.season == season)
        if status:
            filters.append(Fixture.status_short == status)

        df = _parse_date(date_from)
        dt = _parse_date(date_to)

        # filtrare pe interval de zile (inclusiv)
        if df:
            filters.append(Fixture.date_utc >= datetime.combine(df, datetime.min.time()).astimezone())
        if dt:
            filters.append(Fixture.date_utc <= datetime.combine(dt, datetime.max.time()).astimezone())

        if team_id is not None:
            filters.append(
                (Fixture.home_team_id == team_id) | (Fixture.away_team_id == team_id)
            )

        stmt = select(Fixture).order_by(Fixture.date_utc.asc().nullslast(), Fixture.fixture_id.asc())

        if filters:
            stmt = stmt.where(and_(*filters))

        # total
        total = db.execute(select(Fixture).where(and_(*filters)) if filters else select(Fixture)).scalars().all()
        total_count = len(total)

        # page
        rows = db.execute(stmt.limit(limit).offset(offset)).scalars().all()
        return {
            "count": total_count,
            "limit": limit,
            "offset": offset,
            "items": [_to_dict(r) for r in rows],
        }
    finally:
        db.close()


@router.get("/fixtures")
async def list_fixtures(
    league: Optional[int] = Query(None, description="League id (ex: 39)"),
    season: Optional[int] = Query(None, description="Season (ex: 2024)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    team_id: Optional[int] = Query(None, description="Team id (home/away)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """
    Returnează fixtures din DB (rapid), cu filtre + paginare.
    """
    try:
        return await run_in_threadpool(
            _get_fixtures_db, league, season, date_from, date_to, status, team_id, limit, offset
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _get_fixture_one_db(fixture_id: int) -> dict[str, Any]:
    db: Session = SessionLocal()
    try:
        row = db.execute(select(Fixture).where(Fixture.fixture_id == fixture_id)).scalar_one_or_none()
        if not row:
            raise HTTPException(status_code=404, detail="Fixture not found in DB")
        return _to_dict(row)
    finally:
        db.close()


@router.get("/fixtures/{fixture_id}")
async def get_fixture(fixture_id: int):
    """
    Returnează un singur fixture din DB după fixture_id (API-Football id).
    """
    return await run_in_threadpool(_get_fixture_one_db, fixture_id)
