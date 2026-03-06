from __future__ import annotations

from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

from app.db import get_conn

router = APIRouter(tags=["predictions"])


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _round1(value: float) -> float:
    return round(value, 1)


def _normalize_three(a: float, b: float, c: float) -> tuple[float, float, float]:
    total = a + b + c
    if total <= 0:
        return 33.3, 33.3, 33.4
    return (a / total * 100.0, b / total * 100.0, c / total * 100.0)


def _build_prediction_from_fixture_row(row: tuple) -> Dict[str, Any]:
    """
    row:
    0  fixture_id
    1  provider_fixture_id
    2  kickoff_at
    3  status
    4  round
    5  league_name
    6  league_country
    7  home_team_id
    8  home_name
    9  home_short
    10 away_team_id
    11 away_name
    12 away_short
    """

    fixture_id = str(row[0])
    provider_fixture_id = row[1]
    kickoff_at = row[2].isoformat() if hasattr(row[2], "isoformat") else str(row[2])
    status = row[3]
    round_name = row[4]
    league_name = row[5]
    league_country = row[6]
    home_team_id = str(row[7])
    home_name = row[8] or "Home"
    home_short = row[9]
    away_team_id = str(row[10])
    away_name = row[11] or "Away"
    away_short = row[12]

    # -----------------------------
    # Rule-based scoring engine
    # -----------------------------
    # Bază:
    # - avantaj gazde
    # - influență mică a lungimii numelor
    # - influență mică a ligii
    # - output stabil și repetabil
    # -----------------------------

    home_len = len(home_name)
    away_len = len(away_name)
    league_len = len(league_name or "")

    home_adv = 8.0
    team_name_edge = (home_len - away_len) * 0.9
    league_bias = (league_len % 7) - 3  # între -3 și +3
    home_strength = 50.0 + home_adv + team_name_edge + league_bias
    away_strength = 50.0 - home_adv - team_name_edge - league_bias

    draw_base = 26.0 - abs(team_name_edge) * 0.35
    draw_base = _clamp(draw_base, 18.0, 30.0)

    home_raw = _clamp(home_strength, 20.0, 75.0)
    away_raw = _clamp(away_strength, 15.0, 70.0)
    draw_raw = draw_base

    p1, px, p2 = _normalize_three(home_raw, draw_raw, away_raw)
    p1, px, p2 = _round1(p1), _round1(px), _round1(p2)

    # GG / O-U
    attack_index = (home_len + away_len + league_len) % 20
    gg_yes = _clamp(47.0 + attack_index * 1.2 - abs(home_len - away_len) * 0.8, 35.0, 78.0)
    gg_no = 100.0 - gg_yes

    over25 = _clamp(45.0 + attack_index * 1.4 - abs(home_len - away_len) * 0.5, 34.0, 80.0)
    under25 = 100.0 - over25

    x1 = _round1(p1 + px)
    x2 = _round1(px + p2)
    _12 = _round1(p1 + p2)

    # Pauză/final simplificat
    ht_home = _clamp(p1 * 0.72, 20.0, 65.0)
    ht_draw = _clamp(100.0 - ht_home - (p2 * 0.58), 18.0, 50.0)
    ht_away = _round1(100.0 - ht_home - ht_draw)
    ht_home = _round1(ht_home)
    ht_draw = _round1(ht_draw)

    fair_1 = _round1(100.0 / p1) if p1 > 0 else None
    fair_x = _round1(100.0 / px) if px > 0 else None
    fair_2 = _round1(100.0 / p2) if p2 > 0 else None
    fair_gg = _round1(100.0 / gg_yes) if gg_yes > 0 else None
    fair_o25 = _round1(100.0 / over25) if over25 > 0 else None

    market_scores = {
        "1": p1,
        "X": px,
        "2": p2,
        "GG": _round1(gg_yes),
        "NO_GG": _round1(gg_no),
        "OVER_2_5": _round1(over25),
        "UNDER_2_5": _round1(under25),
        "1X": x1,
        "X2": x2,
        "12": _12,
    }

    best_market = max(market_scores, key=market_scores.get)
    best_confidence = _round1(market_scores[best_market])

    return {
        "fixture_id": fixture_id,
        "provider_fixture_id": provider_fixture_id,
        "kickoff_at": kickoff_at,
        "status": status,
        "round": round_name,
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
        "markets": {
            "1x2": {
                "1": p1,
                "X": px,
                "2": p2,
                "fair_odds": {
                    "1": fair_1,
                    "X": fair_x,
                    "2": fair_2,
                },
            },
            "double_chance": {
                "1X": x1,
                "X2": x2,
                "12": _12,
            },
            "btts": {
                "GG": _round1(gg_yes),
                "NO_GG": _round1(gg_no),
                "fair_odds": {
                    "GG": fair_gg,
                },
            },
            "ou_2_5": {
                "OVER_2_5": _round1(over25),
                "UNDER_2_5": _round1(under25),
                "fair_odds": {
                    "OVER_2_5": fair_o25,
                },
            },
            "ht_1x2": {
                "1": ht_home,
                "X": ht_draw,
                "2": ht_away,
            },
        },
        "top_pick": {
            "market": best_market,
            "confidence": best_confidence,
        },
        "analysis": {
            "summary": (
                f"{home_name} pornește ușor favorit în fața lui {away_name}. "
                f"Top pick curent: {best_market} ({best_confidence}%)."
            ),
            "notes": [
                "Predicție rule-based pentru test și integrare UI.",
                "Avantaj mic pentru echipa gazdă.",
                "Piețele GG și Over 2.5 sunt estimate din profilul meciului.",
            ],
        },
    }


def _fetch_fixture_rows(limit: int = 50) -> List[tuple]:
    sql = """
        SELECT
            f.id,
            f.provider_fixture_id,
            f.kickoff_at,
            f.status,
            f.round,
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
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (limit,))
            return cur.fetchall()


def _fetch_fixture_row_by_id(fixture_id: str) -> tuple | None:
    sql = """
        SELECT
            f.id,
            f.provider_fixture_id,
            f.kickoff_at,
            f.status,
            f.round,
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
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (fixture_id,))
            return cur.fetchone()


@router.get("/predictions")
def list_predictions(limit: int = 50) -> Dict[str, Any]:
    rows = _fetch_fixture_rows(limit=limit)
    items = [_build_prediction_from_fixture_row(row) for row in rows]
    return {
        "count": len(items),
        "items": items,
    }


@router.get("/predictions/by-fixture/{fixture_id}")
def prediction_by_fixture(fixture_id: str) -> Dict[str, Any]:
    row = _fetch_fixture_row_by_id(fixture_id)
    if not row:
        raise HTTPException(status_code=404, detail="Fixture not found")
    return _build_prediction_from_fixture_row(row)
