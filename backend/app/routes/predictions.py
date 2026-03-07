from __future__ import annotations

import math
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List

from fastapi import APIRouter, HTTPException

from app.db import get_conn

router = APIRouter(tags=["predictions"])

# -----------------------------
# SIMPLE MEMORY CACHE
# -----------------------------

CACHE: Dict[str, Any] = {}
CACHE_TTL = 180  # seconds


def cache_get(key: str):
    item = CACHE.get(key)
    if not item:
        return None
    if time.time() - item["time"] > CACHE_TTL:
        del CACHE[key]
        return None
    return item["data"]


def cache_set(key: str, value: Any):
    CACHE[key] = {
        "time": time.time(),
        "data": value
    }


# -----------------------------
# UTILS
# -----------------------------

def poisson(k: int, lam: float):
    return math.exp(-lam) * lam**k / math.factorial(k)


def round1(v):
    return round(v, 1)


def safe(v):
    return v if v else 0.0


# -----------------------------
# DATABASE
# -----------------------------

def fetch_fixtures(limit: int = 50):

    sql = """
    SELECT
        f.id,
        f.kickoff_at,
        f.status,
        l.name,
        ht.name,
        at.name
    FROM fixtures f
    JOIN leagues l ON l.id = f.league_id
    JOIN teams ht ON ht.id = f.home_team_id
    JOIN teams at ON at.id = f.away_team_id
    ORDER BY f.kickoff_at
    LIMIT %s
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (limit,))
            return cur.fetchall()


def fetch_today():

    today = datetime.utcnow().date()
    tomorrow = today + timedelta(days=1)

    sql = """
    SELECT
        f.id,
        f.kickoff_at,
        f.status,
        l.name,
        ht.name,
        at.name
    FROM fixtures f
    JOIN leagues l ON l.id = f.league_id
    JOIN teams ht ON ht.id = f.home_team_id
    JOIN teams at ON at.id = f.away_team_id
    WHERE f.kickoff_at >= %s
      AND f.kickoff_at < %s
    ORDER BY f.kickoff_at
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (today, tomorrow))
            return cur.fetchall()


# -----------------------------
# MODEL
# -----------------------------

def build_prediction(row):

    fixture_id = str(row[0])
    kickoff = row[1]
    status = row[2]
    league = row[3]
    home = row[4]
    away = row[5]

    # basic xG estimation
    home_xg = 1.45
    away_xg = 1.20

    max_goals = 6

    home_win = 0
    draw = 0
    away_win = 0
    over25 = 0
    btts = 0

    for hg in range(max_goals):
        for ag in range(max_goals):

            p = poisson(hg, home_xg) * poisson(ag, away_xg)

            if hg > ag:
                home_win += p
            elif hg == ag:
                draw += p
            else:
                away_win += p

            if hg + ag > 2:
                over25 += p

            if hg > 0 and ag > 0:
                btts += p

    p1 = round1(home_win * 100)
    px = round1(draw * 100)
    p2 = round1(away_win * 100)

    gg = round1(btts * 100)
    over = round1(over25 * 100)

    markets = {
        "1": p1,
        "X": px,
        "2": p2,
        "GG": gg,
        "OVER_2_5": over,
        "1X": round1(p1 + px),
        "X2": round1(px + p2),
    }

    best_market = max(markets, key=markets.get)

    return {
        "fixture_id": fixture_id,
        "kickoff_at": kickoff,
        "status": status,
        "league_name": league,
        "home_team": home,
        "away_team": away,
        "model": {
            "type": "fast_poisson",
            "home_xg": home_xg,
            "away_xg": away_xg,
        },
        "markets": markets,
        "top_pick": {
            "market": best_market,
            "confidence": markets[best_market],
        }
    }


# -----------------------------
# ROUTES
# -----------------------------


@router.get("/predictions")
def predictions(limit: int = 50):

    cache_key = f"predictions_{limit}"

    cached = cache_get(cache_key)
    if cached:
        return cached

    rows = fetch_fixtures(limit)

    items = [build_prediction(r) for r in rows]

    result = {
        "count": len(items),
        "items": items
    }

    cache_set(cache_key, result)

    return result


@router.get("/predictions/today")
def predictions_today():

    cache_key = "predictions_today"

    cached = cache_get(cache_key)
    if cached:
        return cached

    rows = fetch_today()

    items = [build_prediction(r) for r in rows]

    result = {
        "count": len(items),
        "items": items
    }

    cache_set(cache_key, result)

    return result


@router.get("/predictions/top")
def predictions_top(limit: int = 20):

    cache_key = f"predictions_top_{limit}"

    cached = cache_get(cache_key)
    if cached:
        return cached

    rows = fetch_fixtures(200)

    items = [build_prediction(r) for r in rows]

    items.sort(
        key=lambda x: x["top_pick"]["confidence"],
        reverse=True
    )

    result = {
        "count": limit,
        "items": items[:limit]
    }

    cache_set(cache_key, result)

    return result
