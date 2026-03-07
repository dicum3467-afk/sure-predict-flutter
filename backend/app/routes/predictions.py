from __future__ import annotations

import math
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException

from app.db import get_conn

router = APIRouter(tags=["predictions"])


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _round1(value: float) -> float:
    return round(value, 1)


def _round2(value: float) -> float:
    return round(value, 2)


def _safe_div(a: float, b: float) -> float:
    return a / b if b else 0.0


def _poisson_pmf(k: int, lam: float) -> float:
    if lam < 0:
        lam = 0.0
    return math.exp(-lam) * (lam ** k) / math.factorial(k)


def _fetch_team_stats(team_id: str, league_id: str, season_id: str) -> dict | None:
    sql = """
        SELECT
            matches_played,
            wins,
            draws,
            losses,
            goals_for,
            goals_against,
            home_matches,
            home_wins,
            home_draws,
            home_losses,
            home_goals_for,
            home_goals_against,
            away_matches,
            away_wins,
            away_draws,
            away_losses,
            away_goals_for,
            away_goals_against,
            btts_hits,
            over25_hits,
            clean_sheets,
            failed_to_score,
            form_last5_points,
            form_last5_wins,
            form_last5_draws,
            form_last5_losses,
            form_last5_goals_for,
            form_last5_goals_against
        FROM team_stats
        WHERE team_id = %s
          AND league_id = %s
          AND season_id = %s
        LIMIT 1
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (team_id, league_id, season_id))
            row = cur.fetchone()

    if not row:
        return None

    return {
        "matches_played": row[0],
        "wins": row[1],
        "draws": row[2],
        "losses": row[3],
        "goals_for": row[4],
        "goals_against": row[5],
        "home_matches": row[6],
        "home_wins": row[7],
        "home_draws": row[8],
        "home_losses": row[9],
        "home_goals_for": row[10],
        "home_goals_against": row[11],
        "away_matches": row[12],
        "away_wins": row[13],
        "away_draws": row[14],
        "away_losses": row[15],
        "away_goals_for": row[16],
        "away_goals_against": row[17],
        "btts_hits": row[18],
        "over25_hits": row[19],
        "clean_sheets": row[20],
        "failed_to_score": row[21],
        "form_last5_points": row[22],
        "form_last5_wins": row[23],
        "form_last5_draws": row[24],
        "form_last5_losses": row[25],
        "form_last5_goals_for": row[26],
        "form_last5_goals_against": row[27],
    }


def _league_baselines(league_id: str, season_id: str) -> dict:
    sql = """
        SELECT
            COALESCE(AVG(CASE WHEN home_goals IS NOT NULL THEN home_goals END), 1.35) AS avg_home_goals,
            COALESCE(AVG(CASE WHEN away_goals IS NOT NULL THEN away_goals END), 1.10) AS avg_away_goals
        FROM fixtures
        WHERE league_id = %s
          AND season_id = %s
          AND home_goals IS NOT NULL
          AND away_goals IS NOT NULL
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (league_id, season_id))
            row = cur.fetchone()

    avg_home = float(row[0] or 1.35)
    avg_away = float(row[1] or 1.10)

    return {
        "avg_home_goals": _clamp(avg_home, 0.6, 3.0),
        "avg_away_goals": _clamp(avg_away, 0.4, 2.5),
    }


def _top_correct_scores(home_xg: float, away_xg: float, top_n: int = 4) -> List[Dict[str, Any]]:
    scores: List[Dict[str, Any]] = []
    for hg in range(0, 6):
        for ag in range(0, 6):
            p = _poisson_pmf(hg, home_xg) * _poisson_pmf(ag, away_xg)
            scores.append({
                "score": f"{hg}-{ag}",
                "home_goals": hg,
                "away_goals": ag,
                "probability": p * 100.0,
            })

    scores.sort(key=lambda x: x["probability"], reverse=True)
    return [
        {
            "score": s["score"],
            "home_goals": s["home_goals"],
            "away_goals": s["away_goals"],
            "probability": _round1(s["probability"]),
        }
        for s in scores[:top_n]
    ]


def _fallback_prediction(
    fixture_id: str,
    provider_fixture_id: Any,
    kickoff_at: str,
    status: str,
    round_name: Any,
    league_id: str,
    season_id: str,
    league_name: str,
    league_country: str,
    home_team_id: str,
    home_name: str,
    home_short: Any,
    away_team_id: str,
    away_name: str,
    away_short: Any,
) -> Dict[str, Any]:
    home_len = len(home_name)
    away_len = len(away_name)
    league_len = len(league_name or "")

    home_adv = 8.0
    team_name_edge = (home_len - away_len) * 0.9
    league_bias = (league_len % 7) - 3

    home_strength = 50.0 + home_adv + team_name_edge + league_bias
    away_strength = 50.0 - home_adv - team_name_edge - league_bias

    draw_base = 26.0 - abs(team_name_edge) * 0.35
    draw_base = _clamp(draw_base, 18.0, 30.0)

    total = max(home_strength + away_strength + draw_base, 1.0)
    p1 = _round1(home_strength / total * 100.0)
    px = _round1(draw_base / total * 100.0)
    p2 = _round1(away_strength / total * 100.0)

    gg_yes = _round1(_clamp(52.0, 35.0, 78.0))
    gg_no = _round1(100.0 - gg_yes)
    over25 = _round1(_clamp(54.0, 34.0, 80.0))
    under25 = _round1(100.0 - over25)

    x1 = _round1(p1 + px)
    x2 = _round1(px + p2)
    _12 = _round1(p1 + p2)

    best_market = max(
        {
            "1": p1,
            "X": px,
            "2": p2,
            "GG": gg_yes,
            "OVER_2_5": over25,
            "1X": x1,
            "X2": x2,
            "12": _12,
        },
        key=lambda k: {
            "1": p1,
            "X": px,
            "2": p2,
            "GG": gg_yes,
            "OVER_2_5": over25,
            "1X": x1,
            "X2": x2,
            "12": _12,
        }[k],
    )

    best_confidence = {
        "1": p1,
        "X": px,
        "2": p2,
        "GG": gg_yes,
        "OVER_2_5": over25,
        "1X": x1,
        "X2": x2,
        "12": _12,
    }[best_market]

    return {
        "fixture_id": fixture_id,
        "provider_fixture_id": provider_fixture_id,
        "kickoff_at": kickoff_at,
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
            "type": "fallback",
        },
        "markets": {
            "1x2": {"1": p1, "X": px, "2": p2},
            "double_chance": {"1X": x1, "X2": x2, "12": _12},
            "btts": {"GG": gg_yes, "NO_GG": gg_no},
            "ou_2_5": {"OVER_2_5": over25, "UNDER_2_5": under25},
        },
        "top_pick": {
            "market": best_market,
            "confidence": _round1(best_confidence),
        },
        "analysis": {
            "summary": f"{home_name} vs {away_name}: fallback model activ.",
            "notes": [
                "Nu există statistici suficiente pentru modelul Poisson.",
            ],
        },
    }


def _build_prediction_from_fixture_row(row: tuple) -> Dict[str, Any]:
    """
    row:
    0  fixture_id
    1  provider_fixture_id
    2  kickoff_at
    3  status
    4  round
    5  league_id
    6  season_id
    7  league_name
    8  league_country
    9  home_team_id
    10 home_name
    11 home_short
    12 away_team_id
    13 away_name
    14 away_short
    """

    fixture_id = str(row[0])
    provider_fixture_id = row[1]
    kickoff_at = row[2].isoformat() if hasattr(row[2], "isoformat") else str(row[2])
    status = row[3]
    round_name = row[4]
    league_id = str(row[5])
    season_id = str(row[6])
    league_name = row[7]
    league_country = row[8]
    home_team_id = str(row[9])
    home_name = row[10] or "Home"
    home_short = row[11]
    away_team_id = str(row[12])
    away_name = row[13] or "Away"
    away_short = row[14]

    home_stats = _fetch_team_stats(home_team_id, league_id, season_id)
    away_stats = _fetch_team_stats(away_team_id, league_id, season_id)

    if not home_stats or not away_stats:
        return _fallback_prediction(
            fixture_id,
            provider_fixture_id,
            kickoff_at,
            status,
            round_name,
            league_id,
            season_id,
            league_name,
            league_country,
            home_team_id,
            home_name,
            home_short,
            away_team_id,
            away_name,
            away_short,
        )

    league_base = _league_baselines(league_id, season_id)
    avg_home_goals = league_base["avg_home_goals"]
    avg_away_goals = league_base["avg_away_goals"]

    home_home_gf = _safe_div(home_stats["home_goals_for"], max(1, home_stats["home_matches"]))
    home_home_ga = _safe_div(home_stats["home_goals_against"], max(1, home_stats["home_matches"]))

    away_away_gf = _safe_div(away_stats["away_goals_for"], max(1, away_stats["away_matches"]))
    away_away_ga = _safe_div(away_stats["away_goals_against"], max(1, away_stats["away_matches"]))

    home_form_ppg = _safe_div(home_stats["form_last5_points"], 5.0)
    away_form_ppg = _safe_div(away_stats["form_last5_points"], 5.0)

    home_attack_strength = _safe_div(home_home_gf, avg_home_goals)
    away_attack_strength = _safe_div(away_away_gf, avg_away_goals)

    home_defense_weakness = _safe_div(home_home_ga, avg_away_goals)
    away_defense_weakness = _safe_div(away_away_ga, avg_home_goals)

    form_home_mult = 1.0 + ((home_form_ppg - 1.5) * 0.08)
    form_away_mult = 1.0 + ((away_form_ppg - 1.5) * 0.08)

    form_home_mult = _clamp(form_home_mult, 0.82, 1.18)
    form_away_mult = _clamp(form_away_mult, 0.82, 1.18)

    home_xg = avg_home_goals * home_attack_strength * away_defense_weakness * form_home_mult
    away_xg = avg_away_goals * away_attack_strength * home_defense_weakness * form_away_mult

    home_xg *= 1.06

    home_xg = _clamp(home_xg, 0.20, 3.80)
    away_xg = _clamp(away_xg, 0.15, 3.40)

    p_home = 0.0
    p_draw = 0.0
    p_away = 0.0
    p_over25 = 0.0
    p_under25 = 0.0
    p_btts_yes = 0.0
    p_btts_no = 0.0

    correct_scores_all: List[Dict[str, Any]] = []

    for hg in range(0, 6):
        for ag in range(0, 6):
            prob = _poisson_pmf(hg, home_xg) * _poisson_pmf(ag, away_xg)
            correct_scores_all.append({
                "home_goals": hg,
                "away_goals": ag,
                "probability": prob,
            })

            if hg > ag:
                p_home += prob
            elif hg == ag:
                p_draw += prob
            else:
                p_away += prob

            if hg + ag > 2:
                p_over25 += prob
            else:
                p_under25 += prob

            if hg > 0 and ag > 0:
                p_btts_yes += prob
            else:
                p_btts_no += prob

    p1 = _round1(p_home * 100.0)
    px = _round1(p_draw * 100.0)
    p2 = _round1(p_away * 100.0)

    gg_yes = _round1(p_btts_yes * 100.0)
    gg_no = _round1(p_btts_no * 100.0)

    over25 = _round1(p_over25 * 100.0)
    under25 = _round1(p_under25 * 100.0)

    x1 = _round1(p1 + px)
    x2 = _round1(px + p2)
    _12 = _round1(p1 + p2)

    ht_home_xg = home_xg * 0.46
    ht_away_xg = away_xg * 0.46

    ht_1 = 0.0
    ht_x = 0.0
    ht_2 = 0.0

    for hg in range(0, 5):
        for ag in range(0, 5):
            prob = _poisson_pmf(hg, ht_home_xg) * _poisson_pmf(ag, ht_away_xg)
            if hg > ag:
                ht_1 += prob
            elif hg == ag:
                ht_x += prob
            else:
                ht_2 += prob

    ht_1 = _round1(ht_1 * 100.0)
    ht_x = _round1(ht_x * 100.0)
    ht_2 = _round1(ht_2 * 100.0)

    fair_1 = _round2(100.0 / p1) if p1 > 0 else None
    fair_x = _round2(100.0 / px) if px > 0 else None
    fair_2 = _round2(100.0 / p2) if p2 > 0 else None
    fair_gg = _round2(100.0 / gg_yes) if gg_yes > 0 else None
    fair_o25 = _round2(100.0 / over25) if over25 > 0 else None

    correct_scores_all.sort(key=lambda x: x["probability"], reverse=True)
    correct_scores = [
        {
            "score": f"{s['home_goals']}-{s['away_goals']}",
            "home_goals": s["home_goals"],
            "away_goals": s["away_goals"],
            "probability": _round1(s["probability"] * 100.0),
        }
        for s in correct_scores_all[:4]
    ]

    market_scores = {
        "1": p1,
        "X": px,
        "2": p2,
        "GG": gg_yes,
        "NO_GG": gg_no,
        "OVER_2_5": over25,
        "UNDER_2_5": under25,
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
            "type": "poisson",
            "home_xg": _round2(home_xg),
            "away_xg": _round2(away_xg),
            "avg_home_goals_league": _round2(avg_home_goals),
            "avg_away_goals_league": _round2(avg_away_goals),
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
                "GG": gg_yes,
                "NO_GG": gg_no,
                "fair_odds": {
                    "GG": fair_gg,
                },
            },
            "ou_2_5": {
                "OVER_2_5": over25,
                "UNDER_2_5": under25,
                "fair_odds": {
                    "OVER_2_5": fair_o25,
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
            "market": best_market,
            "confidence": best_confidence,
        },
        "analysis": {
            "summary": (
                f"{home_name} vs {away_name}: model Poisson estimează "
                f"xG {home_name}={_round2(home_xg)}, {away_name}={_round2(away_xg)}."
            ),
            "notes": [
                "Modelul folosește team_stats + home/away split + formă recentă.",
                "Scorurile corecte sunt estimate din distribuția Poisson 0-5 goluri.",
                "Probabilitățile 1X2, GG și O2.5 sunt derivate din matricea scorurilor.",
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
            f.league_id,
            f.season_id,
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
            f.league_id,
            f.season_id,
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
