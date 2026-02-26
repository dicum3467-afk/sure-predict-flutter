import os
import json
from typing import Optional
from fastapi import APIRouter, Header, HTTPException, Query

from psycopg2.extras import Json

from app.db import get_conn
from app.services.api_football import fetch_fixtures

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN not set in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


def _upsert_league(cur, api_league_id: int, league_obj: dict) -> str:
    """
    Creează/actualizează league și returnează league_id (UUID).
    """
    name = None
    country = None
    logo = None

    # API-Football de obicei: response[i]["league"] = {id,name,country,logo,...}
    if isinstance(league_obj, dict):
        name = league_obj.get("name")
        country = league_obj.get("country")
        logo = league_obj.get("logo")

    cur.execute(
        """
        INSERT INTO leagues (api_league_id, name, country, logo)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (api_league_id)
        DO UPDATE SET
          name = COALESCE(EXCLUDED.name, leagues.name),
          country = COALESCE(EXCLUDED.country, leagues.country),
          logo = COALESCE(EXCLUDED.logo, leagues.logo)
        RETURNING id;
        """,
        (api_league_id, name, country, logo),
    )
    row = cur.fetchone()
    return str(row["id"])


def _extract_fixture_fields(item: dict) -> dict:
    """
    Extrage câmpuri standard din payload API-Football.
    """
    fx = item.get("fixture") or {}
    teams = item.get("teams") or {}
    goals = item.get("goals") or {}
    st = fx.get("status") or {}

    home = teams.get("home") or {}
    away = teams.get("away") or {}

    return {
        "api_fixture_id": (fx.get("id") or item.get("fixture_id")),
        "fixture_date": fx.get("date"),  # ISO string ok pt Postgres timestamptz
        "status": st.get("long"),
        "status_short": st.get("short"),
        "home_team_id": home.get("id"),
        "home_team": home.get("name"),
        "away_team_id": away.get("id"),
        "away_team": away.get("name"),
        "home_goals": goals.get("home"),
        "away_goals": goals.get("away"),
    }


@router.post("/sync/fixtures")
async def sync_fixtures(
    league: int = Query(..., description="API-Football league id (ex: 39 EPL)"),
    season: int = Query(..., description="Season (ex: 2024)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    next_n: Optional[int] = Query(None, description="(Paid) next fixtures, ex: 10"),
    run_type: str = Query("manual", description="manual/initial/daily"),
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    """
    Fetch din API-Football și SALVEAZĂ în Postgres (upsert).
    """
    _check_token(x_sync_token)

    data = await fetch_fixtures(
        league=league,
        season=season,
        date_from=date_from,
        date_to=date_to,
        status=status,
        next_n=next_n,
    )

    items = (data or {}).get("response") or []
    if not items:
        return {
            "ok": True,
            "saved": 0,
            "inserted": 0,
            "updated": 0,
            "message": "No fixtures in response (nothing to save).",
            "api_errors": (data or {}).get("errors"),
        }

    conn = get_conn()
    inserted = 0
    updated = 0

    try:
        with conn:
            with conn.cursor() as cur:
                # încearcă să ia info league din primul item
                league_obj = (items[0].get("league") or {})
                league_id = _upsert_league(cur, league, league_obj)

                for item in items:
                    fields = _extract_fixture_fields(item)
                    api_fixture_id = fields["api_fixture_id"]
                    if not api_fixture_id:
                        continue

                    # UPSERT fixture
                    cur.execute(
                        """
                        INSERT INTO fixtures (
                          league_id, season, api_fixture_id,
                          fixture_date, status, status_short,
                          home_team_id, home_team, away_team_id, away_team,
                          home_goals, away_goals,
                          run_type, raw
                        )
                        VALUES (
                          %s, %s, %s,
                          %s, %s, %s,
                          %s, %s, %s, %s,
                          %s, %s,
                          %s, %s
                        )
                        ON CONFLICT (api_fixture_id)
                        DO UPDATE SET
                          league_id = EXCLUDED.league_id,
                          season = EXCLUDED.season,
                          fixture_date = COALESCE(EXCLUDED.fixture_date, fixtures.fixture_date),
                          status = COALESCE(EXCLUDED.status, fixtures.status),
                          status_short = COALESCE(EXCLUDED.status_short, fixtures.status_short),
                          home_team_id = COALESCE(EXCLUDED.home_team_id, fixtures.home_team_id),
                          home_team = COALESCE(EXCLUDED.home_team, fixtures.home_team),
                          away_team_id = COALESCE(EXCLUDED.away_team_id, fixtures.away_team_id),
                          away_team = COALESCE(EXCLUDED.away_team, fixtures.away_team),
                          home_goals = COALESCE(EXCLUDED.home_goals, fixtures.home_goals),
                          away_goals = COALESCE(EXCLUDED.away_goals, fixtures.away_goals),
                          run_type = EXCLUDED.run_type,
                          raw = EXCLUDED.raw
                        RETURNING (xmax = 0) AS inserted;
                        """,
                        (
                            league_id,
                            season,
                            api_fixture_id,
                            fields["fixture_date"],
                            fields["status"],
                            fields["status_short"],
                            fields["home_team_id"],
                            fields["home_team"],
                            fields["away_team_id"],
                            fields["away_team"],
                            fields["home_goals"],
                            fields["away_goals"],
                            run_type,
                            Json(item),
                        ),
                    )
                    r = cur.fetchone()
                    if r and r.get("inserted"):
                        inserted += 1
                    else:
                        updated += 1

        return {
            "ok": True,
            "saved": inserted + updated,
            "inserted": inserted,
            "updated": updated,
            "league": league,
            "season": season,
            "run_type": run_type,
        }

    finally:
        conn.close()
