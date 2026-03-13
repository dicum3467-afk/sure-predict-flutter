from __future__ import annotations
import os
from fastapi import APIRouter, Header, HTTPException, Query

from app.core.queue import queue
from app.jobs.fixtures_sync_job import run_fixtures_sync_job

router = APIRouter(prefix="/fixtures", tags=["Fixtures Sync"])

SYNC_TOKEN = "surepredict123"  # sau os.getenv("SYNC_TOKEN")

@router.post("/admin-sync")
def admin_sync(
    days_ahead: int = Query(30, ge=1, le=90),
    past_days: int = Query(7, ge=0, le=90),
    season: int | None = Query(None),
    max_pages: int = Query(5, ge=1, le=50),
    season_lookback: int = Query(2, ge=0, le=5),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not queue:
        raise HTTPException(status_code=500, detail="Queue not configured. Set REDIS_URL.")

    job = queue.enqueue(
        run_fixtures_sync_job,
        days_ahead=days_ahead,
        past_days=past_days,
        season=season,
        max_pages=max_pages,
        season_lookback=season_lookback,
        retry=None,  # RQ retry e opțional; noi avem retry intern pe HTTP
        result_ttl=3600,  # păstrează rezultatul 1h
        ttl=3600,
        job_timeout=900,  # max 15 min
    )

    return {"ok": True, "job_id": job.id, "status_url": f"/jobs/{job.id}"}

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------
API_KEY = os.getenv("APISPORTS_KEY") or os.getenv("API_FOOTBALL_KEY") or os.getenv("API_KEY")
SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")  # schimbă în Render env
BASE_URL = os.getenv("APIFOOTBALL_BASE_URL", "https://v3.football.api-sports.io")

# Timeouts + retry
REQ_TIMEOUT = int(os.getenv("APIFOOTBALL_TIMEOUT", "30"))
MAX_RETRIES = int(os.getenv("APIFOOTBALL_MAX_RETRIES", "4"))
BACKOFF_FACTOR = float(os.getenv("APIFOOTBALL_BACKOFF", "0.7"))

# Throttle (sec) între requests (ajută la free/pro)
MIN_SLEEP_BETWEEN_CALLS = float(os.getenv("APIFOOTBALL_MIN_SLEEP", "0.15"))

logger = logging.getLogger("fixtures_sync")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
def _require_api_key() -> None:
    if not API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Missing APISPORTS_KEY / API_FOOTBALL_KEY in environment",
        )


def _check_token(x_sync_token: Optional[str]) -> None:
    if not x_sync_token or x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid X-Sync-Token")


def _daterange_utc(past_days: int, days_ahead: int) -> Tuple[date, date]:
    """
    Returneaza (from_date, to_date_inclusive) în UTC (date-only).
    """
    today = datetime.now(timezone.utc).date()
    frm = today - timedelta(days=past_days)
    to = today + timedelta(days=days_ahead)
    return frm, to


def _to_dt_range_utc(frm: date, to_inclusive: date) -> Tuple[datetime, datetime]:
    """
    Convert date range -> datetime UTC [from, to_exclusive)
    """
    frm_dt = datetime(frm.year, frm.month, frm.day, tzinfo=timezone.utc)
    to_excl = datetime(to_inclusive.year, to_inclusive.month, to_inclusive.day, tzinfo=timezone.utc) + timedelta(days=1)
    return frm_dt, to_excl


def _parse_iso_dt(s: Optional[str]) -> Optional[datetime]:
    """
    API-Football trimite ISO cu "Z" sau +00:00.
    Returneaza datetime UTC sau None.
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
    """
    Session cu retry pe erori de retea + 429/5xx.
    """
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
    """
    API-SPORTS uneori trimite:
      - x-ratelimit-requests-remaining
      - x-ratelimit-requests-reset (epoch sec)
    Numele pot varia; luam ce gasim.
    """
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
    """
    Daca remaining e foarte mic, asteptam putin.
    Daca e 0 si avem reset_epoch, asteptam pana la reset (max 60s).
    """
    if rate.remaining is None:
        time.sleep(MIN_SLEEP_BETWEEN_CALLS)
        return

    if rate.remaining <= 0 and rate.reset_epoch:
        now = int(time.time())
        wait_s = max(0, rate.reset_epoch - now)
        wait_s = min(wait_s, 60)  # nu blocam exagerat
        if wait_s > 0:
            logger.warning("Rate limit hit. Sleeping %ss until reset.", wait_s)
            time.sleep(wait_s)
        return

    # cand e mic, maresti un pic pauza
    if rate.remaining <= 2:
        time.sleep(max(MIN_SLEEP_BETWEEN_CALLS, 1.0))
    else:
        time.sleep(MIN_SLEEP_BETWEEN_CALLS)


def _api_get_fixtures(
    session: requests.Session,
    provider_league_id: int,
    season: int,
    frm: date,
    to_inclusive: date,
    page: int,
) -> Dict[str, Any]:
    """
    GET /fixtures (cu paginare). Nu folosim `next` (free plan nu-l are).
    """
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
        raise HTTPException(status_code=502, detail=f"API-Football request failed: {e}")

    # throttle (rate-limit friendly)
    _throttle_after_response(_extract_rate_info(resp))

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"API-Football error status={resp.status_code} league={provider_league_id} season={season}",
        )

    try:
        data = resp.json()
    except Exception:
        raise HTTPException(status_code=502, detail="API-Football returned non-JSON")

    # API-Football pune erori în "errors"
    errors = data.get("errors") or {}
    if errors:
        # exemple: {"plan": "..."} sau {"access": "Your account is suspended ..."}
        raise HTTPException(
            status_code=502,
            detail=f"API-Football errors: {errors}",
        )

    return data


def _parse_fixture_row(item: Dict[str, Any], league_uuid: str) -> Optional[Dict[str, Any]]:
    """
    Normalizeaza un item API-Football in formatul pentru DB.
    """
    fx = item.get("fixture") or {}
    teams = item.get("teams") or {}
    goals = item.get("goals") or {}
    league = item.get("league") or {}

    provider_fixture_id = fx.get("id")
    kickoff_at = fx.get("date")  # ISO
    if not provider_fixture_id or not kickoff_at:
        return None

    # status short: NS / 1H / HT / FT etc.
    status_short = ((fx.get("status") or {}).get("short")) or None

    home = ((teams.get("home") or {}).get("name")) or None
    away = ((teams.get("away") or {}).get("name")) or None

    home_goals = goals.get("home")
    away_goals = goals.get("away")

    # runda e string gen "Regular Season - 26"
    round_name = league.get("round")

    return {
        "league_id": league_uuid,
        "provider_fixture_id": str(provider_fixture_id),
        "kickoff_at": kickoff_at,  # lasam ISO; in DB e timestamptz (Supabase parseaza)
        "status": status_short,
        "home_team": home,
        "away_team": away,
        "home_goals": home_goals,
        "away_goals": away_goals,
        "season": league.get("season"),
        "round": round_name,
        "run_type": "sync",
    }


# -----------------------------------------------------------------------------
# PUBLIC LIST ENDPOINTS (utile pentru app)
# -----------------------------------------------------------------------------
@router.get("/fixtures")
def list_fixtures(
    league_uuid: Optional[str] = Query(None, description="UUID din tabela leagues (optional)"),
    provider_league_id: Optional[int] = Query(None, description="provider_league_id (optional)"),
    status: Optional[str] = Query(None, description="NS/FT/HT etc. (optional)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC) optional"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC) optional"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Listeaza fixtures din DB cu filtre si paginare.
    """
    try:
        where = []
        params: Dict[str, Any] = {}

        if league_uuid:
            where.append("f.league_id = %(league_uuid)s")
            params["league_uuid"] = league_uuid

        if provider_league_id is not None:
            where.append("l.provider_league_id = %(provider_league_id)s")
            params["provider_league_id"] = provider_league_id

        if status:
            where.append("f.status = %(status)s")
            params["status"] = status

        if date_from:
            where.append("f.kickoff_at >= %(date_from)s::timestamptz")
            params["date_from"] = f"{date_from}T00:00:00+00:00"

        if date_to:
            where.append("f.kickoff_at < (%(date_to)s::date + interval '1 day')::timestamptz")
            params["date_to"] = date_to

        where_sql = " AND ".join(where) if where else "TRUE"
        offset = (page - 1) * per_page

        count_sql = f"""
            SELECT COUNT(*)
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            WHERE {where_sql}
        """

        data_sql = f"""
            SELECT
                f.id,
                f.league_id,
                l.provider_league_id,
                l.name AS league_name,
                l.country AS league_country,
                f.provider_fixture_id,
                f.kickoff_at,
                f.status,
                f.home_team,
                f.away_team,
                f.home_goals,
                f.away_goals,
                f.season,
                f.round
            FROM fixtures f
            JOIN leagues l ON l.id = f.league_id
            WHERE {where_sql}
            ORDER BY f.kickoff_at {order}
            LIMIT %(limit)s OFFSET %(offset)s
        """

        params["limit"] = per_page
        params["offset"] = offset

        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(count_sql, params)
                total = int(cur.fetchone()[0])

                cur.execute(data_sql, params)
                rows = cur.fetchall()

        items: List[Dict[str, Any]] = []
        for r in rows:
            # r[6] kickoff_at e datetime
            kickoff_val = r[6].isoformat() if hasattr(r[6], "isoformat") else r[6]
            items.append(
                {
                    "id": r[0],
                    "league_id": r[1],
                    "provider_league_id": r[2],
                    "league_name": r[3],
                    "league_country": r[4],
                    "provider_fixture_id": r[5],
                    "kickoff_at": kickoff_val,
                    "status": r[7],
                    "home_team": r[8],
                    "away_team": r[9],
                    "home_goals": r[10],
                    "away_goals": r[11],
                    "season": r[12],
                    "round": r[13],
                }
            )

        return {
            "page": page,
            "per_page": per_page,
            "total": total,
            "items": items,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    provider_league_id: int = Query(..., description="ID liga API-Football (ex: 39, 140)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Shortcut: fixtures pentru o liga dupa provider_league_id.
    """
    return list_fixtures(
        league_uuid=None,
        provider_league_id=provider_league_id,
        status=None,
        date_from=date_from,
        date_to=date_to,
        page=page,
        per_page=per_page,
        order=order,
    )


# -----------------------------------------------------------------------------
# ADMIN SYNC ENDPOINT
# -----------------------------------------------------------------------------
@router.post("/fixtures/admin-sync")
def admin_sync_fixtures(
    days_ahead: int = Query(14, ge=1, le=90, description="Câte zile în viitor să sincronizeze (max 90)."),
    past_days: int = Query(7, ge=0, le=90, description="Câte zile în trecut să includă (max 90)."),
    season: Optional[int] = Query(None, description="Sezonul (ex: 2024). Dacă lipsește, se auto-detectează."),
    max_pages: int = Query(10, ge=1, le=50, description="Limită pagini per ligă (max 50)."),
    season_lookback: int = Query(2, ge=0, le=5, description="Câți ani înapoi să caute sezonul dacă nu e dat."),
    x_sync_token: Optional[str] = Header(default=None, alias="X-Sync-Token"),
) -> Dict[str, Any]:
    """
    PRO++ Sync fixtures din API-Football în tabela `fixtures`, pentru ligile active din tabela `leagues`.

    Include:
      - viitor (days_ahead)
      - trecut (past_days)
      - paginare (max_pages)
      - auto-detect sezon (dacă season nu e trimis)
      - retry + backoff + rate-limit friendly
      - NU CRAPĂ pe response gol (cel mai important)
    """
    _check_token(x_sync_token)
    _require_api_key()

    frm, to_inclusive = _daterange_utc(past_days=past_days, days_ahead=days_ahead)
    frm_dt, to_dt_excl = _to_dt_range_utc(frm, to_inclusive)

    inserted = 0
    updated = 0
    skipped = 0
    leagues_count = 0

    # ce sezoane încercăm (dacă nu e explicit)
    now_year = datetime.now(timezone.utc).year
    seasons_to_try: List[int] = [season] if season is not None else [now_year - i for i in range(0, season_lookback + 1)]

    # upsert (ne bazam pe UNIQUE(provider_fixture_id))
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
                # ligile active
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
                    # provider_league_id poate fi TEXT; îl convertim
                    try:
                        provider_league_int = int(provider_league_id)
                    except Exception:
                        skipped += 1
                        logger.warning("Skip league=%s invalid provider_league_id=%s", league_uuid, provider_league_id)
                        continue

                    # 1) auto-detect sezon: încercăm pagina 1; primul sezon care returnează response!=[] e bun
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
                                # dacă season e explicit și probe_items e gol, păstrăm totuși season (ca să nu buclăm inutil)
                                chosen_season = s
                                break
                        except HTTPException as he:
                            # dacă e suspend/plan/access, nu are rost să continuăm
                            detail = str(he.detail)
                            if "suspended" in detail.lower() or "access" in detail.lower() or "plan" in detail.lower():
                                raise
                            # altfel, încercăm următorul sezon
                            continue

                    if chosen_season is None:
                        # nimic găsit
                        logger.info("No season found for league=%s provider=%s", league_uuid, provider_league_int)
                        continue

                    # 2) sincronizăm paginile
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

                        # IMPORTANT: NU CRAPĂ pe gol
                        paging = data.get("paging") or {}
                        total_pages = int(paging.get("total") or 1)

                        if not items and page == 1:
                            # liga/interval fără meciuri
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

                            # extra safety: ținem doar fixtures în interval (API deja filtrează, dar verificăm)
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
                                "Reached max_pages=%s for league=%s provider=%s",
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
        # Aici prinzi orice crash și-l vezi clar în response (și în Render logs)
        logger.exception("admin_sync_fixtures failed")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
