from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from fastapi import APIRouter, Header, HTTPException, Query
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])

logger = logging.getLogger("fixtures_sync")

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")
API_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY")
BASE_URL = os.getenv("APIFOOTBALL_BASE_URL", "https://v3.football.api-sports.io")

REQ_TIMEOUT = int(os.getenv("APIFOOTBALL_TIMEOUT", "30"))
MAX_RETRIES = int(os.getenv("APIFOOTBALL_MAX_RETRIES", "4"))
BACKOFF_FACTOR = float(os.getenv("APIFOOTBALL_BACKOFF", "0.7"))
MIN_SLEEP_BETWEEN_CALLS = float(os.getenv("APIFOOTBALL_MIN_SLEEP", "0.15"))


def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Missing APISPORTS_KEY / API_FOOTBALL_KEY",
        )


def _check_token(x_sync_token: Optional[str]) -> None:
    if not x_sync_token or x_sync_token.strip() != SYNC_TOKEN.strip():
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _daterange_utc(*, past_days: int, days_ahead: int) -> Tuple[date, date]:
    now_utc = datetime.now(timezone.utc).date()
    frm = now_utc - timedelta(days=past_days)
    to_inclusive = now_utc + timedelta(days=days_ahead)
    return frm, to_inclusive


def _to_dt_range_utc(frm: date, to_inclusive: date) -> Tuple[datetime, datetime]:
    frm_dt = datetime(frm.year, frm.month, frm.day, tzinfo=timezone.utc)
    to_dt_excl = datetime(
        to_inclusive.year, to_inclusive.month, to_inclusive.day, tzinfo=timezone.utc
    ) + timedelta(days=1)
    return frm_dt, to_dt_excl


def _parse_iso_dt(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        v = value.replace("Z", "+00:00")
        dt = datetime.fromisoformat(v)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _safe_int(x: Any) -> Optional[int]:
    try:
        if x is None:
            return None
        return int(x)
    except Exception:
        return None


@dataclass
class RateInfo:
    remaining: Optional[int] = None
    reset_epoch: Optional[int] = None


def _requests_session() -> requests.Session:
    session = requests.Session()

    retry = Retry(
        total=MAX_RETRIES,
        connect=MAX_RETRIES,
        read=MAX_RETRIES,
        status=MAX_RETRIES,
        backoff_factor=BACKOFF_FACTOR,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
        raise_on_status=False,
        respect_retry_after_header=True,
    )

    adapter = HTTPAdapter(max_retries=retry, pool_connections=20, pool_maxsize=20)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    return session


def _extract_rate_info(resp: requests.Response) -> RateInfo:
    h = resp.headers
    remaining = (
        _safe_int(h.get("x-ratelimit-requests-remaining"))
        or _safe_int(h.get("x-ratelimit-remaining"))
        or _safe_int(h.get("X-RateLimit-Remaining"))
    )
    reset_epoch = (
        _safe_int(h.get("x-ratelimit-requests-reset"))
        or _safe_int(h.get("x-ratelimit-reset"))
        or _safe_int(h.get("X-RateLimit-Reset"))
    )
    return RateInfo(remaining=remaining, reset_epoch=reset_epoch)


def _throttle_after_response(rate: RateInfo) -> None:
    if rate.remaining is None:
        time.sleep(MIN_SLEEP_BETWEEN_CALLS)
        return

    if rate.remaining <= 0 and rate.reset_epoch:
        now = int(time.time())
        wait_s = max(0, rate.reset_epoch - now)
        wait_s = min(wait_s, 60)
        if wait_s > 0:
            logger.warning("Rate limit hit. Sleeping %ss until reset.", wait_s)
            time.sleep(wait_s)
        return

    if rate.remaining <= 2:
        time.sleep(max(MIN_SLEEP_BETWEEN_CALLS, 1.0))
    else:
        time.sleep(MIN_SLEEP_BETWEEN_CALLS)


def _api_get_fixtures(
    *,
    session: requests.Session,
    provider_league_id: int,
    season: int,
    frm: date,
    to_inclusive: date,
    page: int,
) -> Dict[str, Any]:
    url = f"{BASE_URL}/fixtures"
    headers = {
        "x-apisports-key": API_KEY,
        "accept": "application/json",
    }
    params = {
        "league": provider_league_id,
        "season": season,
        "from": frm.isoformat(),
        "to": to_inclusive.isoformat(),
        "page": page,
    }

    try:
        resp = session.get(url, headers=headers, params=params, timeout=REQ_TIMEOUT)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football request failed: {e}",
        )

    _throttle_after_response(_extract_rate_info(resp))

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football error status={resp.status_code} league={provider_league_id} season={season} page={page}",
        )

    try:
        data = resp.json()
    except Exception:
        raise HTTPException(
            status_code=502,
            detail="API-Football returned invalid JSON",
        )

    errors = data.get("errors") or {}
    if errors:
        detail = str(errors)
        if "suspended" in detail.lower() or "access" in detail.lower() or "plan" in detail.lower():
            raise HTTPException(status_code=502, detail=f"API-Football errors: {detail}")
        raise HTTPException(status_code=502, detail=f"API-Football errors: {detail}")

    return data


def _parse_fixture_row(item: Dict[str, Any], league_uuid: str) -> Optional[Dict[str, Any]]:
    fx = item.get("fixture") or {}
    teams = item.get("teams") or {}
    goals = item.get("goals") or {}
    league = item.get("league") or {}

    provider_fixture_id = fx.get("id")
    kickoff_at = fx.get("date")

    if not provider_fixture_id or not kickoff_at:
        return None

    status_short = ((fx.get("status") or {}).get("short")) or None

    home = ((teams.get("home") or {}).get("name")) or None
    away = ((teams.get("away") or {}).get("name")) or None

    home_goals = goals.get("home")
    away_goals = goals.get("away")

    round_name = league.get("round")

    return {
        "league_id": league_uuid,
        "provider_fixture_id": str(provider_fixture_id),
        "kickoff_at": kickoff_at,
        "status": status_short,
        "home_team": home,
        "away_team": away,
        "home_goals": home_goals,
        "away_goals": away_goals,
        "season": league.get("season"),
        "round": round_name,
        "run_type": "sync",
    }


@router.post("/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90, description="Câte zile în viitor"),
    past_days: int = Query(7, ge=0, le=90, description="Câte zile în trecut"),
    season: Optional[int] = Query(None, description="Sezonul (ex: 2024)"),
    max_pages: int = Query(10, ge=1, le=50, description="Limita pagini per ligă"),
    season_lookback: int = Query(2, ge=0, le=5, description="Câți ani în urmă verificăm când sezonul nu e trimis"),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    Sync fixtures din API-Football în tabela `fixtures`.

    Cere:
    - tabela `leagues` cu coloane: id, provider_league_id, is_active
    - tabela `fixtures` cu UNIQUE(provider_fixture_id)
    """
    _check_token(x_sync_token)
    _require_api_key()

    frm, to_inclusive = _daterange_utc(past_days=past_days, days_ahead=days_ahead)
    frm_dt, to_dt_excl = _to_dt_range_utc(frm, to_inclusive)

    inserted = 0
    updated = 0
    skipped = 0
    leagues_count = 0

    now_year = datetime.now(timezone.utc).year
    seasons_to_try: List[int] = [season] if season is not None else [
        now_year - i for i in range(0, season_lookback + 1)
    ]

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
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
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

    session = _requests_session()

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, provider_league_id
                    FROM leagues
                    WHERE is_active = true
                    ORDER BY provider_league_id ASC
                    """
                )
                leagues: List[Tuple[str, Any]] = cur.fetchall()
                leagues_count = len(leagues)

                for league_uuid, provider_league_id in leagues:
                    try:
                        provider_league_int = int(provider_league_id)
                    except Exception:
                        skipped += 1
                        logger.warning(
                            "Skip league=%s invalid provider_league_id=%s",
                            league_uuid,
                            provider_league_id,
                        )
                        continue

                    chosen_season: Optional[int] = None

                    for s in seasons_to_try:
                        try:
                            probe = _api_get_fixtures(
                                session=session,
                                provider_league_id=provider_league_int,
                                season=s,
                                frm=frm,
                                to_inclusive=to_inclusive,
                                page=1,
                            )
                            probe_items = probe.get("response") or []
                            if probe_items or season is not None:
                                chosen_season = s
                                break
                        except HTTPException as he:
                            detail = str(he.detail)
                            if "suspended" in detail.lower() or "access" in detail.lower() or "plan" in detail.lower():
                                raise
                            continue

                    if chosen_season is None:
                        logger.info(
                            "No season found for league=%s provider_league_id=%s",
                            league_uuid,
                            provider_league_int,
                        )
                        continue

                    page = 1
                    total_pages = 1

                    while True:
                        data = _api_get_fixtures(
                            session=session,
                            provider_league_id=provider_league_int,
                            season=chosen_season,
                            frm=frm,
                            to_inclusive=to_inclusive,
                            page=page,
                        )

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

                        conn.commit()

                        if page >= total_pages:
                            break

                        if page >= max_pages:
                            logger.info(
                                "Reached max_pages=%s for league=%s provider_league_id=%s",
                                max_pages,
                                league_uuid,
                                provider_league_int,
                            )
                            break

                        page += 1

        return {
            "ok": True,
            "leagues": leagues_count,
            "inserted": inserted,
            "updated": updated,
            "skipped": skipped,
            "from": frm.isoformat(),
            "to": to_inclusive.isoformat(),
            "season": season,
            "seasons_tried": seasons_to_try,
            "max_pages": max_pages,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("admin_sync_fixtures failed")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
