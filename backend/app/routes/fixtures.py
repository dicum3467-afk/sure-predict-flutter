from typing import Optional, List, Dict, Any
from datetime import datetime, timezone, timedelta

import os
import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn

router = APIRouter(tags=["fixtures"])

API_KEY = os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN")


def _require_api_key():
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Missing API_FOOTBALL_KEY env var")


def _check_token(x_sync_token: Optional[str]):
    if not SYNC_TOKEN:
        raise HTTPException(status_code=500, detail="Missing SYNC_TOKEN env var")
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _infer_season_year(today_utc: datetime) -> int:
    """
    API-Football folosește 'season' ca anul de start al sezonului.
    Exemplu: Feb 2026 => sezonul e 2025 (2025-2026).
    Heuristic simplu: dacă luna >= 7 => season = anul curent, altfel anul anterior.
    """
    y = today_utc.year
    m = today_utc.month
    return y if m >= 7 else y - 1


@router.get("/fixtures")
def list_fixtures(
    league_id: Optional[int] = Query(None),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    """
    Listează meciuri din DB.
    """
    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="Database not configured (missing DATABASE_URL).")

    where = ["1=1"]
    params: List[Any] = []

    try:
        with conn:
            with conn.cursor() as cur:
                # convert API league id -> UUID (din tabela leagues)
                if league_id is not None:
                    cur.execute(
                        "SELECT id FROM leagues WHERE provider_league_id = %s LIMIT 1",
                        (league_id,),
                    )
                    row = cur.fetchone()
                    if not row:
                        raise HTTPException(status_code=404, detail=f"League {league_id} not found in DB")
                    league_uuid = row[0]
                    where.append("league_id = %s")
                    params.append(league_uuid)

                if date_from:
                    where.append("kickoff_at >= %s")
                    params.append(date_from)

                if date_to:
                    where.append("kickoff_at <= %s")
                    params.append(date_to)

                if status:
                    where.append("status = %s")
                    params.append(status)

                where_sql = " WHERE " + " AND ".join(where)

                cur.execute(
                    f"""
                    SELECT
                        id,
                        league_id,
                        provider_fixture_id,
                        home_team,
                        away_team,
                        kickoff_at,
                        status,
                        home_goals,
                        away_goals
                    FROM fixtures
                    {where_sql}
                    ORDER BY kickoff_at ASC
                    LIMIT %s OFFSET %s
                    """,
                    (*params, limit, offset),
                )
                rows = cur.fetchall()

        return rows

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass


@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(30, ge=1, le=90),          # ✅ acum max 90
    past_days: int = Query(2, ge=0, le=14),            # ✅ ultimele N zile (pt rezultate recente)
    season: Optional[int] = Query(None),               # ✅ dacă nu dai, o calculează
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
):
    """
    Sync fixtures din API-Football în tabela fixtures, pentru ligile active din tabela leagues.
    Ia meciuri viitoare + ultimele 'past_days' zile.
    """
    _check_token(x_sync_token)
    _require_api_key()

    now_utc = datetime.now(timezone.utc)
    if season is None:
        season = _infer_season_year(now_utc)

    date_from = (now_utc.date() - timedelta(days=past_days))
    date_to = (now_utc.date() + timedelta(days=days_ahead))

    inserted = 0
    skipped = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    """
                )
                leagues = cur.fetchall()

                headers = {
                    "x-apisports-key": API_KEY,
                    "accept": "application/json",
                }

                for league_uuid, provider_league_id in leagues:
                    resp = requests.get(
                        "https://v3.football.api-sports.io/fixtures",
                        headers=headers,
                        params={
                            "league": provider_league_id,
                            "season": season,
                            "from": str(date_from),
                            "to": str(date_to),
                            # ⚠️ NU filtrăm doar NS, ca să prinzi și rezultate recente
                        },
                        timeout=30,
                    )

                    if resp.status_code != 200:
                        raise HTTPException(
                            status_code=500,
                            detail=f"API error league {provider_league_id}: {resp.status_code}",
                        )

                    data = resp.json()
                    items = data.get("response", []) or []

                    for item in items:
                        fx = item.get("fixture", {}) or {}
                        teams = item.get("teams", {}) or {}
                        goals = item.get("goals", {}) or {}
                        status_info = fx.get("status", {}) or {}

                        provider_fixture_id = fx.get("id")
                        kickoff_iso = fx.get("date")  # ISO string
                        status_short = status_info.get("short")  # e.g. NS, FT, 1H
                        home_name = (teams.get("home") or {}).get("name")
                        away_name = (teams.get("away") or {}).get("name")
                        home_goals = goals.get("home")
                        away_goals = goals.get("away")

                        if not provider_fixture_id or not kickoff_iso:
                            skipped += 1
                            continue

                        # Upsert (dacă ai unique index pe provider_fixture_id)
                        cur.execute(
                            """
                            INSERT INTO fixtures (
                                league_id,
                                provider_fixture_id,
                                home_team,
                                away_team,
                                kickoff_at,
                                status,
                                home_goals,
                                away_goals
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                            ON CONFLICT (provider_fixture_id)
                            DO UPDATE SET
                                league_id = EXCLUDED.league_id,
                                home_team = EXCLUDED.home_team,
                                away_team = EXCLUDED.away_team,
                                kickoff_at = EXCLUDED.kickoff_at,
                                status = EXCLUDED.status,
                                home_goals = EXCLUDED.home_goals,
                                away_goals = EXCLUDED.away_goals
                            """,
                            (
                                league_uuid,
                                str(provider_fixture_id),
                                home_name,
                                away_name,
                                kickoff_iso,
                                status_short,
                                home_goals,
                                away_goals,
                            ),
                        )
                        inserted += 1

            conn.commit()

        return {
            "ok": True,
            "leagues": len(leagues),
            "inserted": inserted,
            "skipped": skipped,
            "from": str(date_from),
            "to": str(date_to),
            "season": season,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
