from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone, date
from typing import Optional, Dict, Any, List, Tuple

import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn

router = APIRouter(tags=["fixtures"])

API_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Missing APISPORTS_KEY / API_FOOTBALL_KEY in environment.",
        )


def _check_token(x_sync_token: Optional[str]) -> None:
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _daterange_utc(past_days: int, days_ahead: int) -> Tuple[datetime, datetime]:
    """
    Return UTC datetime range [from, to] inclusive-ish.
    We'll use >= from and < to+1day to avoid timezone issues.
    """
    now = datetime.now(timezone.utc)
    frm = now - timedelta(days=past_days)
    to = now + timedelta(days=days_ahead)
    return frm, to


def _parse_iso_dt(iso_str: Optional[str]) -> Optional[datetime]:
    if not iso_str:
        return None
    s = iso_str.strip()
    # API-Football returns ISO like "2026-02-20T10:46:59+00:00" or "...Z"
    s = s.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None


def _normalize_status(short: Optional[str]) -> Optional[str]:
    """
    Normalize API-Football fixture status.short into our DB 'status'.
    """
    if not short:
        return None
    m = {
        "NS": "scheduled",
        "TBD": "scheduled",
        "1H": "live",
        "HT": "live",
        "2H": "live",
        "ET": "live",
        "BT": "live",
        "P": "live",
        "SUSP": "live",
        "INT": "live",
        "FT": "finished",
        "AET": "finished",
        "PEN": "finished",
        "PST": "postponed",
        "CANC": "canceled",
        "ABD": "abandoned",
        "AWD": "awarded",
        "WO": "walkover",
    }
    return m.get(short.upper(), short.lower())


def _api_get_fixtures_next(
    provider_league_id: int,
    season: int,
    page: int,
    next_count: int = 50,
    tz: str = "Europe/Bucharest",
) -> Dict[str, Any]:
    """
    ROBUST: use 'next' instead of from/to. This usually returns upcoming fixtures reliably.
    """
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {"x-apisports-key": API_KEY, "accept": "application/json"}
    params = {
        "league": provider_league_id,
        "season": season,
        "next": next_count,
        "page": page,
        "timezone": tz,
    }

    resp = requests.get(url, headers=headers, params=params, timeout=30)
    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football error {resp.status_code} for league={provider_league_id}, season={season}, page={page}",
        )
    return resp.json()


def _parse_fixture_row(item: Dict[str, Any], league_uuid: str) -> Optional[Dict[str, Any]]:
    fx = (item.get("fixture") or {}) if isinstance(item, dict) else {}
    teams = item.get("teams") or {}
    goals = item.get("goals") or {}
    league = item.get("league") or {}
    st = ((fx.get("status") or {}).get("short")) if isinstance(fx.get("status"), dict) else None

    kickoff_at = fx.get("date")  # ISO string
    provider_fixture_id = fx.get("id")
    if provider_fixture_id is None or not kickoff_at:
        return None

    home = (teams.get("home") or {}).get("name")
    away = (teams.get("away") or {}).get("name")

    row = {
        "league_id": league_uuid,                       # UUID string; we cast to uuid in SQL
        "provider_fixture_id": str(provider_fixture_id),
        "kickoff_at": kickoff_at,                       # castable to timestamptz
        "status": _normalize_status(st),
        "home_team": home,
        "away_team": away,
        "home_goals": goals.get("home"),
        "away_goals": goals.get("away"),
        "season": league.get("season"),
        "round": league.get("round"),
        "run_type": "sync",                             # optional field
    }
    return row


@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90, description="Câte zile în viitor să sincronizeze (max 90)."),
    past_days: int = Query(7, ge=0, le=90, description="Câte zile în trecut să includă (max 90)."),
    season: Optional[int] = Query(None, description="Sezon (ex: 2025). Dacă lipsește, se auto-detectează."),
    max_pages: int = Query(10, ge=1, le=50, description="Limită pagini per ligă (max 50)."),
    season_lookback: int = Query(2, ge=0, le=5, description="Câți ani înapoi să caute sezonul dacă nu e dat."),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    PRO++ Sync fixtures din API-Football în tabela fixtures, pentru ligile active din tabela leagues.

    - Folosește endpoint robust `next` (nu depinde de from/to).
    - Filtrează local după intervalul [now-past_days, now+days_ahead] ca să nu bagi date aiurea.
    - Auto-detect sezon dacă nu îl trimiți.
    - Paginare și limită de pagini per ligă.
    """

    _check_token(x_sync_token)
    _require_api_key()

    frm_dt, to_dt = _daterange_utc(past_days=past_days, days_ahead=days_ahead)
    # folosim < (to + 1 zi) ca să prindem toată ziua "to"
    to_dt_excl = to_dt + timedelta(days=1)

    inserted = 0
    updated = 0
    skipped = 0
    leagues_count = 0

    now_year = datetime.now(timezone.utc).year
    seasons_to_try: List[int] = (
        [season] if season is not None else [now_year - i for i in range(0, season_lookback + 1)]
    )

    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="Database not configured (missing DATABASE_URL).")

    # UPSERT by provider_fixture_id
    upsert_sql = """
    INSERT INTO fixtures (
        league_id,
        provider_fixture_id,
        kickoff_at,
        status,
        home_team,
        away_team,
        home_goals,
        away_goals,
        season,
        round,
        run_type
    )
    VALUES (
        %s::uuid,
        %s,
        %s::timestamptz,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s
    )
    ON CONFLICT (provider_fixture_id)
    DO UPDATE SET
        league_id   = EXCLUDED.league_id,
        kickoff_at  = EXCLUDED.kickoff_at,
        status      = EXCLUDED.status,
        home_team   = EXCLUDED.home_team,
        away_team   = EXCLUDED.away_team,
        home_goals  = EXCLUDED.home_goals,
        away_goals  = EXCLUDED.away_goals,
        season      = EXCLUDED.season,
        round       = EXCLUDED.round,
        run_type    = EXCLUDED.run_type
    RETURNING (xmax = 0) AS inserted;
    """

    try:
        with conn:
            with conn.cursor() as cur:
                # active leagues
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    ORDER BY provider_league_id ASC
                    """
                )
                leagues: List[Tuple[str, int]] = cur.fetchall()
                leagues_count = len(leagues)

                for league_uuid, provider_league_id in leagues:
                    # 1) auto-detect season (probe page=1)
                    chosen_season: Optional[int] = None

                    for s in seasons_to_try:
                        data = _api_get_fixtures_next(provider_league_id, s, page=1, next_count=50)
                        items = data.get("response") or []
                        if len(items) > 0 or season is not None:
                            chosen_season = s
                            break

                    if chosen_season is None:
                        # nothing found in lookback
                        continue

                    # 2) sync pages (limit max_pages)
                    page = 1
                    while True:
                        data = _api_get_fixtures_next(provider_league_id, chosen_season, page=page, next_count=50)
                        items = data.get("response") or []
                        paging = data.get("paging") or {}
                        total_pages = int(paging.get("total") or 1)

                        if not items and page == 1:
                            break

                        for it in items:
                            row = _parse_fixture_row(it, league_uuid)
                            if not row:
                                skipped += 1
                                continue

                            # filter local by range
                            k_dt = _parse_iso_dt(row.get("kickoff_at"))
                            if not k_dt:
                                skipped += 1
                                continue

                            if not (frm_dt <= k_dt < to_dt_excl):
                                # outside requested window -> ignore
                                continue

                            cur.execute(
                                upsert_sql,
                                (
                                    row["league_id"],
                                    row["provider_fixture_id"],
                                    row["kickoff_at"],
                                    row["status"],
                                    row["home_team"],
                                    row["away_team"],
                                    row["home_goals"],
                                    row["away_goals"],
                                    row["season"],
                                    row["round"],
                                    row["run_type"],
                                ),
                            )
                            res = cur.fetchone()
                            if res and res[0] is True:
                                inserted += 1
                            else:
                                updated += 1

                        # stop conditions
                        if page >= total_pages:
                            break
                        if page >= max_pages:
                            break
                        page += 1

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass

    return {
        "ok": True,
        "leagues": leagues_count,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "from": frm_dt.date().isoformat(),
        "to": to_dt.date().isoformat(),
        "season": season if season is not None else seasons_to_try[0],
        "seasons_tried": seasons_to_try,
        "max_pages": max_pages,
        "mode": "next+local_range_filter",
    }
