# backend/app/routes/fixtures_sync.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Any, Dict, List, Tuple
import uuid
from datetime import datetime

from app.db import get_conn
from app.services.api_football import fetch_fixtures_by_league

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


class SyncBody(BaseModel):
    league_id: str
    season: int = 2024
    run_type: str = "initial"
    # Optional: câte zile în viitor să tragi (depinde ce suportă fetch-ul tău)
    days_ahead: Optional[int] = None


class SyncAllBody(BaseModel):
    season: int = 2024
    run_type: str = "initial"
    days_ahead: Optional[int] = None


def _as_float(x: Any) -> Optional[float]:
    try:
        if x is None:
            return None
        return float(x)
    except Exception:
        return None


def _as_dt_iso(x: Any) -> Optional[str]:
    """
    Vrem să stocăm kickoff_at ca text ISO sau timestamp.
    În DB-ul tău poate fi timestamp; psycopg2 va converti ok dacă trimitem string ISO.
    """
    if x is None:
        return None
    if isinstance(x, str):
        return x
    if isinstance(x, datetime):
        return x.isoformat()
    return str(x)


def _upsert_fixture(cur, fx: Dict[str, Any], league_id: str, run_type: str) -> None:
    """
    Upsert în tabela fixtures.
    Cheia logică: (provider_fixture_id, league_id, run_type)

    Dacă ai deja UNIQUE pe aceste 3 coloane -> merge ON CONFLICT.
    Dacă nu ai UNIQUE -> facem fallback: UPDATE dacă există, altfel INSERT.
    """
    provider_fixture_id = str(fx.get("provider_fixture_id") or fx.get("fixture_id") or fx.get("id") or "").strip()
    if not provider_fixture_id:
        return

    kickoff_at = _as_dt_iso(fx.get("kickoff_at") or fx.get("date") or fx.get("kickoff"))
    status = (fx.get("status") or "").strip()
    home = (fx.get("home") or fx.get("home_name") or "").strip()
    away = (fx.get("away") or fx.get("away_name") or "").strip()

    computed_at = _as_dt_iso(fx.get("computed_at") or fx.get("computedAt") or datetime.utcnow().isoformat())

    p_home = _as_float(fx.get("p_home"))
    p_draw = _as_float(fx.get("p_draw"))
    p_away = _as_float(fx.get("p_away"))
    p_gg = _as_float(fx.get("p_gg"))
    p_over25 = _as_float(fx.get("p_over25"))
    p_under25 = _as_float(fx.get("p_under25"))

    # 1) încercăm varianta ON CONFLICT (rapidă) - merge doar dacă ai UNIQUE index
    try:
        cur.execute(
            """
            INSERT INTO fixtures (
              id,
              provider_fixture_id,
              league_id,
              kickoff_at,
              status,
              home,
              away,
              run_type,
              computed_at,
              p_home,
              p_draw,
              p_away,
              p_gg,
              p_over25,
              p_under25
            )
            VALUES (
              %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (provider_fixture_id, league_id, run_type)
            DO UPDATE SET
              kickoff_at = EXCLUDED.kickoff_at,
              status = EXCLUDED.status,
              home = EXCLUDED.home,
              away = EXCLUDED.away,
              computed_at = EXCLUDED.computed_at,
              p_home = EXCLUDED.p_home,
              p_draw = EXCLUDED.p_draw,
              p_away = EXCLUDED.p_away,
              p_gg = EXCLUDED.p_gg,
              p_over25 = EXCLUDED.p_over25,
              p_under25 = EXCLUDED.p_under25
            """,
            (
                str(uuid.uuid4()),
                provider_fixture_id,
                league_id,
                kickoff_at,
                status,
                home,
                away,
                run_type,
                computed_at,
                p_home,
                p_draw,
                p_away,
                p_gg,
                p_over25,
                p_under25,
            ),
        )
        return
    except Exception:
        # 2) fallback dacă nu ai UNIQUE constraint (sau numele coloanelor diferă)
        #    facem UPDATE dacă există rând, altfel INSERT.
        cur.execute(
            """
            SELECT id
            FROM fixtures
            WHERE provider_fixture_id = %s AND league_id = %s AND run_type = %s
            LIMIT 1
            """,
            (provider_fixture_id, league_id, run_type),
        )
        row = cur.fetchone()

        if row and row[0]:
            cur.execute(
                """
                UPDATE fixtures
                SET
                  kickoff_at = %s,
                  status = %s,
                  home = %s,
                  away = %s,
                  computed_at = %s,
                  p_home = %s,
                  p_draw = %s,
                  p_away = %s,
                  p_gg = %s,
                  p_over25 = %s,
                  p_under25 = %s
                WHERE id = %s
                """,
                (
                    kickoff_at,
                    status,
                    home,
                    away,
                    computed_at,
                    p_home,
                    p_draw,
                    p_away,
                    p_gg,
                    p_over25,
                    p_under25,
                    row[0],
                ),
            )
        else:
            cur.execute(
                """
                INSERT INTO fixtures (
                  id,
                  provider_fixture_id,
                  league_id,
                  kickoff_at,
                  status,
                  home,
                  away,
                  run_type,
                  computed_at,
                  p_home,
                  p_draw,
                  p_away,
                  p_gg,
                  p_over25,
                  p_under25
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    str(uuid.uuid4()),
                    provider_fixture_id,
                    league_id,
                    kickoff_at,
                    status,
                    home,
                    away,
                    run_type,
                    computed_at,
                    p_home,
                    p_draw,
                    p_away,
                    p_gg,
                    p_over25,
                    p_under25,
                ),
            )


def _sync_one_league(league_id: str, season: int, run_type: str, days_ahead: Optional[int]) -> Tuple[int, str]:
    """
    Returnează (count, error_message)
    """
    # 0) ia provider_league_id (numeric) din DB pe baza UUID-ului intern
    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT provider_league_id FROM leagues WHERE id = %s LIMIT 1", (league_id,))
        row = cur.fetchone()
        if not row or not row.get("provider_league_id"):
            return 0, f"league not found or missing provider_league_id for league_id={league_id}"
        provider_league_id = str(row["provider_league_id"]).strip()
    except Exception as e:
        return 0, f"cannot read provider_league_id: {e}"
    finally:
        try:
            if conn:
                conn.close()
        except Exception:
            pass

    # 1) Fetch de la provider (API-Football) folosind provider_league_id
    try:
        fixtures: List[Dict[str, Any]] = fetch_fixtures_by_league(
            league_id=provider_league_id,   # <-- ACUM e corect
            season=season,
            days_ahead=days_ahead,
        )
    except Exception as e:
        return 0, f"fetch failed: {e}"

    # 2) upsert în DB
    conn = None
    try:
        conn = get_conn()
        conn.autocommit = False
        cur = conn.cursor()

        n = 0
        for fx in fixtures or []:
            _upsert_fixture(cur, fx, league_id=league_id, run_type=run_type)  # league_id rămâne UUID intern!
            n += 1

        conn.commit()
        return n, ""
    except Exception as e:
        if conn:
            conn.rollback()
        return 0, f"db failed: {e}"
    finally:
        try:
            if conn:
                conn.close()
        except Exception:
            pass


@router.post("/sync")
def sync_league(body: SyncBody):
    league_id = body.league_id.strip()
    if not league_id:
        raise HTTPException(status_code=400, detail="league_id is required")

    n, err = _sync_one_league(
        league_id=league_id,
        season=body.season,
        run_type=body.run_type,
        days_ahead=body.days_ahead,
    )
    if err:
        raise HTTPException(status_code=500, detail={"league_id": league_id, "error": err})

    return {"ok": True, "league_id": league_id, "season": body.season, "run_type": body.run_type, "upserted": n}


@router.post("/sync-all")
def sync_all(body: SyncAllBody):
    # 1) luăm toate ligile din DB
    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id FROM leagues ORDER BY name ASC")
        league_ids = [str(r[0]) for r in cur.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"cannot read leagues: {e}")
    finally:
        try:
            if conn:
                conn.close()
        except Exception:
            pass

    if not league_ids:
        return {"ok": True, "season": body.season, "run_type": body.run_type, "leagues": 0, "total_upserted": 0, "results": []}

    # 2) sync pe fiecare ligă
    results = []
    total = 0
    for lid in league_ids:
        n, err = _sync_one_league(
            league_id=lid,
            season=body.season,
            run_type=body.run_type,
            days_ahead=body.days_ahead,
        )
        total += n
        results.append(
            {
                "league_id": lid,
                "upserted": n,
                "error": err or None,
            }
        )

    return {
        "ok": True,
        "season": body.season,
        "run_type": body.run_type,
        "leagues": len(league_ids),
        "total_upserted": total,
        "results": results,
                }
