from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone, date
from typing import Optional, Dict, Any, List, Tuple

import requests
from fastapi import APIRouter, HTTPException, Query, Header

from app.db import get_conn  # IMPORTANT: get_conn() e context manager

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


def _daterange_utc(past_days: int, days_ahead: int) -> Tuple[date, date]:
    """
    Returneaza (from_date, to_date_inclusive) ca date UTC.
    """
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=past_days)
    to_inclusive = today + timedelta(days=days_ahead)
    return frm, to_inclusive


def _to_dt_range_utc(frm: date, to_inclusive: date) -> Tuple[datetime, datetime]:
    """
    Convertim date -> datetime UTC:
    - from_dt = 00:00:00
    - to_dt_exclusive = ziua urmatoare la 00:00:00 (pentru interval [from, to))
    """
    frm_dt = datetime(frm.year, frm.month, frm.day, tzinfo=timezone.utc)
    to_dt_excl = datetime(to_inclusive.year, to_inclusive.month, to_inclusive.day, tzinfo=timezone.utc) + timedelta(days=1)
    return frm_dt, to_dt_excl


def _api_get_fixtures(league_id: int, season: int, frm: date, to_inclusive: date, page: int) -> Dict[str, Any]:
    """
    API-Football v3 Fixtures endpoint (cu paginare).
    """
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {
        "x-apisports-key": API_KEY,
        "accept": "application/json",
    }
    params = {
        "league": league_id,
        "season": season,
        "from": frm.isoformat(),
        "to": to_inclusive.isoformat(),
        "page": page,
    }

    try:
        resp = requests.get(url, headers=headers, params=params, timeout=30)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"API-Football request failed: {e}")

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football error status={resp.status_code} league={league_id} season={season} page={page}",
        )
    return resp.json()


def _parse_iso_dt(s: Optional[str]) -> Optional[datetime]:
    """
    Primeste ISO (de obicei cu 'Z' sau '+00:00') si intoarce datetime UTC.
    """
    if not s:
        return None
    try:
        s2 = s.replace("Z", "+00:00")
        dt = datetime.fromisoformat(s2)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _parse_fixture_row(item: Dict[str, Any], league_uuid: str) -> Optional[Dict[str, Any]]:
    """
    Normalizeaza un item API-Football in formatul nostru pentru DB.
    IMPORTANT: kickoff_at il pastram ISO string (Postgres stie sa parseze la timestamptz).
    """
    fx = item.get("fixture") or {}
    teams = item.get("teams") or {}
    goals = item.get("goals") or {}
    lg = item.get("league") or {}

    provider_fixture_id = fx.get("id")
    kickoff_at = fx.get("date")  # ISO string UTC (+00:00)
    if not provider_fixture_id or not kickoff_at:
        return None

    status_short = ((fx.get("status") or {}).get("short")) or None

    home = ((teams.get("home") or {}).get("name")) or None
    away = ((teams.get("away") or {}).get("name")) or None

    home_goals = goals.get("home")
    away_goals = goals.get("away")

    round_name = lg.get("round")
    run_type = "sync"

    return {
        "league_id": league_uuid,
        "provider_fixture_id": str(provider_fixture_id),
        "kickoff_at": kickoff_at,
        "status": status_short,
        "home_team": home,
        "away_team": away,
        "home_goals": home_goals,
        "away_goals": away_goals,
        "season": lg.get("season"),
        "round": round_name,
        "run_type": run_type,
    }


@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90, description="Câte zile în viitor să sincronizeze (max 90)."),
    past_days: int = Query(7, ge=0, le=90, description="Câte zile în trecut să includă (max 90)."),
    season: Optional[int] = Query(None, description="Sezonul (ex: 2025). Dacă lipsește, se auto-detectează."),
    max_pages: int = Query(10, ge=1, le=50, description="Limită pagini per ligă (max 50)."),
    season_lookback: int = Query(2, ge=0, le=5, description="Câți ani înapoi să caute sezonul dacă nu e dat."),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    Sync fixtures din API-Football în tabela fixtures, pentru ligile active din tabela leagues.
    Include:
    - viitor (days_ahead)
    - trecut (past_days)
    - paginare (max_pages)
    - auto-detect sezon (dacă season nu e trimis)
    """
    _check_token(x_sync_token)
    _require_api_key()

    frm, to_inclusive = _daterange_utc(past_days=past_days, days_ahead=days_ahead)
    frm_dt, to_dt_excl = _to_dt_range_utc(frm, to_inclusive)

    inserted = 0
    updated = 0
    skipped = 0

    now_year = datetime.now(timezone.utc).year
    seasons_to_try: List[int] = [season] if season is not None else [now_year - i for i in range(0, season_lookback + 1)]

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
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
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
        # IMPORTANT: aici luam CONEXIUNEA reala, nu context manager-ul
        with get_conn() as conn:
            with conn.cursor() as cur:
                # Ligile active
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    ORDER BY provider_league_id ASC
                    """
                )
                leagues = cur.fetchall()  # [(uuid, provider_league_id), ...]

                for league_uuid, provider_league_id in leagues:
                    # provider_league_id poate fi TEXT în DB -> convertim sigur
                    try:
                        provider_league_int = int(provider_league_id)
                    except Exception:
                        skipped += 1
                        continue

                    chosen_season: Optional[int] = None

                    # auto-detect sezon: probe page=1 până găsim răspuns cu items
                    for s in seasons_to_try:
                        data_probe = _api_get_fixtures(provider_league_int, s, frm, to_inclusive, page=1)
                        items_probe = data_probe.get("response") or []
                        if items_probe or season is not None:
                            chosen_season = s
                            break

                    if chosen_season is None:
                        continue

                    # sync pagini
                    page = 1
                    while True:
                        data = _api_get_fixtures(provider_league_int, chosen_season, frm, to_inclusive, page=page)
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

                            k_dt = _parse_iso_dt(row.get("kickoff_at"))
                            if not k_dt:
                                skipped += 1
                                continue

                            # filtrare extra sigură în interval [frm_dt, to_dt_excl)
                            if not (frm_dt <= k_dt < to_dt_excl):
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

                        if page >= total_pages:
                            break
                        if page >= max_pages:
                            break
                        page += 1

        return {
            "ok": True,
            "leagues": len(leagues),
            "inserted": inserted,
            "updated": updated,
            "skipped": skipped,
            "from": frm.isoformat(),
            "to": to_inclusive.isoformat(),
            "season": season if season is not None else seasons_to_try[0],
            "seasons_tried": seasons_to_try,
            "max_pages": max_pages,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
