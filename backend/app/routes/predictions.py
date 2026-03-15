from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query

from app.db import get_conn
from app.services.prediction_engine import MODEL_VERSION, compute_prediction_for_fixture

router = APIRouter(prefix="/predictions", tags=["Predictions"])


# =========================================================
# HELPERS
# =========================================================

_CACHE: Dict[str, Dict[str, Any]] = {}
_CACHE_TTL_SECONDS = 180


def _cache_get(key: str):
    item = _CACHE.get(key)
    if not item:
        return None
    if (datetime.now(timezone.utc).timestamp() - item["ts"]) > _CACHE_TTL_SECONDS:
        del _CACHE[key]
        return None
    return item["data"]


def _cache_set(key: str, value: Any):
    _CACHE[key] = {
        "ts": datetime.now(timezone.utc).timestamp(),
        "data": value,
    }


def _round1(v: float) -> float:
    return round(float(v), 1)


def _round2(v: float) -> float:
    return round(float(v), 2)


def _safe_int(v: Any, default: int = 0) -> int:
    try:
        if v is None:
            return default
        return int(v)
    except Exception:
        return default


def _safe_float(v: Any, default: float = 0.0) -> float:
    try:
        if v is None:
            return default
        return float(v)
    except Exception:
        return default


def _fair_odds_from_percent(pct: float) -> Optional[float]:
    if pct <= 0:
        return None
    return _round2(100.0 / pct)


def _correct_score_top_from_engine(pred: Dict[str, Any], top_n: int = 4) -> List[Dict[str, Any]]:
    rows = pred.get("probs", {}).get("top_scorelines", []) or []
    out: List[Dict[str, Any]] = []

    for r in rows[:top_n]:
        p = _safe_float(r.get("p"), 0.0) * 100.0
        hg = _safe_int(r.get("home_goals"))
        ag = _safe_int(r.get("away_goals"))
        out.append(
            {
                "score": f"{hg}-{ag}",
                "home_goals": hg,
                "away_goals": ag,
                "probability": _round1(p),
            }
        )
    return out


def _pick_label_to_market_key(label: str) -> str:
    mapping = {
        "1": "1x2",
        "X": "1x2",
        "2": "1x2",
        "1X": "double_chance",
        "X2": "double_chance",
        "12": "double_chance",
        "GG": "btts",
        "NG": "btts",
        "O2.5": "ou_2_5",
        "U2.5": "ou_2_5",
        "HT1": "ht_1x2",
        "HTX": "ht_1x2",
        "HT2": "ht_1x2",
    }
    return mapping.get(label, "1x2")


def _best_market_pick(pred: Dict[str, Any]) -> Dict[str, Any]:
    picks = pred.get("picks", {}) or {}

    candidates: List[Dict[str, Any]] = []
    for _, block in picks.items():
        if not isinstance(block, dict):
            continue
        label = block.get("pick")
        p = _safe_float(block.get("p"), 0.0)
        if not label:
            continue
        candidates.append(
            {
                "market": _pick_label_to_market_key(str(label)),
                "selection": str(label),
                "confidence": _round1(p * 100.0),
                "odds_fair": block.get("odds_fair"),
            }
        )

    if not candidates:
        return {
            "market": "1x2",
            "selection": "X",
            "confidence": 0.0,
            "odds_fair": None,
        }

    candidates.sort(key=lambda x: x["confidence"], reverse=True)
    return candidates[0]


# =========================================================
# DATABASE READS
# =========================================================

def _league_baselines(cur, league_id: str) -> Dict[str, float]:
    cur.execute(
        """
        SELECT
            COALESCE(AVG(home_goals + away_goals), 2.60) AS avg_total_goals,
            COALESCE(AVG((home_goals + away_goals) / 2.0), 1.30) AS avg_scored_per_team
        FROM fixtures
        WHERE league_id = %s
          AND home_goals IS NOT NULL
          AND away_goals IS NOT NULL
        """,
        (league_id,),
    )
    row = cur.fetchone()
    if not row:
        return {"league_avg_goals": 2.60, "league_scored_avg": 1.30}

    return {
        "league_avg_goals": _safe_float(row[0], 2.60),
        "league_scored_avg": _safe_float(row[1], 1.30),
    }


def _fetch_fixture_rows(cur, limit: int = 50) -> List[tuple]:
    cur.execute(
        """
        SELECT
            f.id,
            f.provider_fixture_id,
            f.kickoff_at,
            f.status,
            f.round,
            f.league_id,
            f.season,
            l.name AS league_name,
            l.country AS league_country,
            ht.id AS home_team_id,
            ht.name AS home_name,
            ht.short_name AS home_short,
            at.id AS away_team_id,
            at.name AS away_name,
            at.short_name AS away_short
        FROM fixtures f
        JOIN leagues l ON l.id = f.league_id
        JOIN teams ht ON ht.id = f.home_team_id
        JOIN teams at ON at.id = f.away_team_id
        ORDER BY f.kickoff_at ASC
        LIMIT %s
        """,
        (limit,),
    )
    return cur.fetchall()


def _fetch_fixture_rows_today(cur) -> List[tuple]:
    now_utc = datetime.now(timezone.utc)
    start_day = datetime(now_utc.year, now_utc.month, now_utc.day, tzinfo=timezone.utc)
    end_day = start_day + timedelta(days=1)

    cur.execute(
        """
        SELECT
            f.id,
            f.provider_fixture_id,
            f.kickoff_at,
            f.status,
            f.round,
            f.league_id,
            f.season,
            l.name AS league_name,
            l.country AS league_country,
            ht.id AS home_team_id,
            ht.name AS home_name,
            ht.short_name AS home_short,
            at.id AS away_team_id,
            at.name AS away_name,
            at.short_name AS away_short
        FROM fixtures f
        JOIN leagues l ON l.id = f.league_id
        JOIN teams ht ON ht.id = f.home_team_id
        JOIN teams at ON at.id = f.away_team_id
        WHERE f.kickoff_at >= %s
          AND f.kickoff_at < %s
        ORDER BY f.kickoff_at ASC
        """,
        (start_day, end_day),
    )
    return cur.fetchall()


def _fetch_fixture_row_by_id(cur, fixture_id: str):
    cur.execute(
        """
        SELECT
            f.id,
            f.provider_fixture_id,
            f.kickoff_at,
            f.status,
            f.round,
            f.league_id,
            f.season,
            l.name AS league_name,
            l.country AS league_country,
            ht.id AS home_team_id,
            ht.name AS home_name,
            ht.short_name AS home_short,
            at.id AS away_team_id,
            at.name AS away_name,
            at.short_name AS away_short
        FROM fixtures f
        JOIN leagues l ON l.id = f.league_id
        JOIN teams ht ON ht.id = f.home_team_id
        JOIN teams at ON at.id = f.away_team_id
        WHERE f.id = %s
        LIMIT 1
        """,
        (fixture_id,),
    )
    return cur.fetchone()


def _fetch_past_matches_for_league(
    cur,
    league_id: str,
    before_kickoff: datetime,
    limit: int = 400,
) -> List[Dict[str, Any]]:
    cur.execute(
        """
        SELECT
            home_team_id,
            away_team_id,
            home_goals,
            away_goals,
            kickoff_at
        FROM fixtures
        WHERE league_id = %s
          AND kickoff_at < %s
          AND home_goals IS NOT NULL
          AND away_goals IS NOT NULL
        ORDER BY kickoff_at DESC
        LIMIT %s
        """,
        (league_id, before_kickoff, limit),
    )
    rows = cur.fetchall()

    out: List[Dict[str, Any]] = []
    for r in reversed(rows):
        out.append(
            {
                "home_team_id": r[0],
                "away_team_id": r[1],
                "home_goals": r[2],
                "away_goals": r[3],
                "kickoff_at": r[4].isoformat() if hasattr(r[4], "isoformat") else r[4],
            }
        )
    return out


# =========================================================
# MODEL CORE
# =========================================================

def _build_prediction_from_fixture_row(cur, row: tuple) -> Dict[str, Any]:
    fixture_id = str(row[0])
    provider_fixture_id = row[1]
    kickoff_at = row[2]
    status = row[3]
    round_name = row[4]
    league_id = str(row[5])
    season_id = str(row[6]) if row[6] is not None else None
    league_name = row[7] or ""
    league_country = row[8] or ""
    home_team_id = _safe_int(row[9])
    home_name = row[10] or "Home"
    home_short = row[11]
    away_team_id = _safe_int(row[12])
    away_name = row[13] or "Away"
    away_short = row[14]

    kickoff_iso = kickoff_at.isoformat() if hasattr(kickoff_at, "isoformat") else str(kickoff_at)

    baselines = _league_baselines(cur, league_id)
    past_matches = _fetch_past_matches_for_league(cur, league_id=league_id, before_kickoff=kickoff_at, limit=400)

    pred = compute_prediction_for_fixture(
        fixture={
            "home_team_id": home_team_id,
            "away_team_id": away_team_id,
        },
        past_matches=past_matches,
        league_avg_goals=baselines["league_avg_goals"],
        league_scored_avg=baselines["league_scored_avg"],
        home_adv=1.10,
        cal_binary=None,
        cal_ovr=None,
    )

    probs = pred.get("probs", {}) or {}
    inputs = pred.get("inputs", {}) or {}

    p1 = _round1(_safe_float(probs.get("1x2", {}).get("1"), 0.0) * 100.0)
    px = _round1(_safe_float(probs.get("1x2", {}).get("X"), 0.0) * 100.0)
    p2 = _round1(_safe_float(probs.get("1x2", {}).get("2"), 0.0) * 100.0)

    x1 = _round1(_safe_float(probs.get("double_chance", {}).get("1X"), 0.0) * 100.0)
    x2 = _round1(_safe_float(probs.get("double_chance", {}).get("X2"), 0.0) * 100.0)
    _12 = _round1(_safe_float(probs.get("double_chance", {}).get("12"), 0.0) * 100.0)

    gg_yes = _round1(_safe_float(probs.get("gg", {}).get("GG"), 0.0) * 100.0)
    gg_no = _round1(_safe_float(probs.get("gg", {}).get("NG"), 0.0) * 100.0)

    over25 = _round1(_safe_float(probs.get("ou25", {}).get("O2.5"), 0.0) * 100.0)
    under25 = _round1(_safe_float(probs.get("ou25", {}).get("U2.5"), 0.0) * 100.0)

    ht_1 = _round1(_safe_float(probs.get("ht", {}).get("HT1"), 0.0) * 100.0)
    ht_x = _round1(_safe_float(probs.get("ht", {}).get("HTX"), 0.0) * 100.0)
    ht_2 = _round1(_safe_float(probs.get("ht", {}).get("HT2"), 0.0) * 100.0)

    best_pick = _best_market_pick(pred)
    correct_scores = _correct_score_top_from_engine(pred, top_n=4)

    home_xg = _round2(inputs.get("lambda_home", 0.0))
    away_xg = _round2(inputs.get("lambda_away", 0.0))

    return {
        "fixture_id": fixture_id,
        "provider_fixture_id": provider_fixture_id,
        "kickoff_at": kickoff_iso,
        "status": status,
        "round": round_name,
        "league_id": league_id,
        "season_id": season_id,
        "league_name": league_name,
        "league_country": league_country,
        "home_team": {
            "id": home_team_id,
            "name": home_name,
            "short": home_short,
        },
        "away_team": {
            "id": away_team_id,
            "name": away_name,
            "short": away_short,
        },
        "model": {
            "type": "engine_pro_pp",
            "home_xg": home_xg,
            "away_xg": away_xg,
            "avg_goals_league": _round2(inputs.get("league_avg_goals", 0.0)),
            "avg_scored_team_baseline": _round2(inputs.get("base", 0.0)),
        },
        "markets": {
            "1x2": {
                "1": p1,
                "X": px,
                "2": p2,
                "fair_odds": {
                    "1": _fair_odds_from_percent(p1),
                    "X": _fair_odds_from_percent(px),
                    "2": _fair_odds_from_percent(p2),
                },
            },
            "double_chance": {
                "1X": x1,
                "X2": x2,
                "12": _12,
            },
            "btts": {
                "GG": gg_yes,
                "NO_GG": gg_no,
                "fair_odds": {
                    "GG": _fair_odds_from_percent(gg_yes),
                    "NO_GG": _fair_odds_from_percent(gg_no),
                },
            },
            "ou_2_5": {
                "OVER_2_5": over25,
                "UNDER_2_5": under25,
                "fair_odds": {
                    "OVER_2_5": _fair_odds_from_percent(over25),
                    "UNDER_2_5": _fair_odds_from_percent(under25),
                },
            },
            "ht_1x2": {
                "1": ht_1,
                "X": ht_x,
                "2": ht_2,
            },
            "correct_score_top": correct_scores,
        },
        "top_pick": {
            "market": best_pick["market"],
            "selection": best_pick["selection"],
            "confidence": best_pick["confidence"],
            "odds_fair": best_pick["odds_fair"],
        },
        "analysis": {
            "summary": f"{home_name} vs {away_name}: xG {home_xg} - {away_xg}. Top pick {best_pick['selection']} ({best_pick['confidence']}%).",
            "notes": [
                "Engine PRO++: formă recentă + avantaj teren propriu + Poisson.",
                "Probabilitățile 1X2, GG și O2.5 sunt derivate din matrice Poisson.",
            ],
        },
    }


def _serialize_items(cur, rows: List[tuple]) -> List[Dict[str, Any]]:
    return [_build_prediction_from_fixture_row(cur, r) for r in rows]


# =========================================================
# ROUTES
# =========================================================

@router.get("")
def list_predictions(limit: int = Query(50, ge=1, le=200)) -> Dict[str, Any]:
    cache_key = f"predictions:{limit}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                rows = _fetch_fixture_rows(cur, limit=limit)
                items = _serialize_items(cur, rows)

        result = {
            "count": len(items),
            "items": items,
        }
        _cache_set(cache_key, result)
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/today")
def list_predictions_today() -> Dict[str, Any]:
    cache_key = "predictions:today"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                rows = _fetch_fixture_rows_today(cur)
                items = _serialize_items(cur, rows)

        result = {
            "count": len(items),
            "items": items,
        }
        _cache_set(cache_key, result)
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/top")
def list_top_predictions(limit: int = Query(20, ge=1, le=100)) -> Dict[str, Any]:
    cache_key = f"predictions:top:{limit}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                rows = _fetch_fixture_rows(cur, limit=200)
                items = _serialize_items(cur, rows)

        items.sort(key=lambda x: x["top_pick"]["confidence"], reverse=True)
        items = items[:limit]

        result = {
            "count": len(items),
            "items": items,
        }
        _cache_set(cache_key, result)
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@router.get("/by-fixture/{fixture_id}")
def prediction_by_fixture(fixture_id: str) -> Dict[str, Any]:
    cache_key = f"predictions:fixture:{fixture_id}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                row = _fetch_fixture_row_by_id(cur, fixture_id)
                if not row:
                    raise HTTPException(status_code=404, detail="Fixture not found")

                item = _build_prediction_from_fixture_row(cur, row)

        _cache_set(cache_key, item)
        return item
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
