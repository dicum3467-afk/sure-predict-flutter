from __future__ import annotations

import math
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, List, Optional

from fastapi import APIRouter, HTTPException

from app.db import get_conn

router = APIRouter(tags=["predictions"])

# =========================================================
# CACHE
# =========================================================

_CACHE: Dict[str, Dict[str, Any]] = {}
_CACHE_TTL_SECONDS = 180


def _cache_get(key: str):
    item = _CACHE.get(key)
    if not item:
        return None
    if time.time() - item["time"] > _CACHE_TTL_SECONDS:
        del _CACHE[key]
        return None
    return item["data"]


def _cache_set(key: str, value: Any):
    _CACHE[key] = {
        "time": time.time(),
        "data": value,
    }


# =========================================================
# HELPERS
# =========================================================

def _round1(v: float) -> float:
    return round(v, 1)


def _round2(v: float) -> float:
    return round(v, 2)


def _clamp(v: float, low: float, high: float) -> float:
    return max(low, min(high, v))


def _safe_div(a: float, b: float) -> float:
    return a / b if b else 0.0


def _poisson_pmf(k: int, lam: float) -> float:
    lam = max(lam, 0.0001)
    return math.exp(-lam) * (lam ** k) / math.factorial(k)


def _fair_odds(prob_percent: float) -> Optional[float]:
    if prob_percent <= 0:
        return None
    return _round2(100.0 / prob_percent)


# =========================================================
# DATABASE READS
# =========================================================

def _fetch_team_elo(team_id: str) -> float:
    sql = """
        SELECT elo_rating
        FROM team_elo
        WHERE team_id = %s
        LIMIT 1
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (team_id,))
            row = cur.fetchone()
    return float(row[0]) if row else 1500.0


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
        "matches_played": row[0] or 0,
        "wins": row[1] or 0,
        "draws": row[2] or 0,
        "losses": row[3] or 0,
        "goals_for": float(row[4] or 0),
        "goals_against": float(row[5] or 0),
        "home_matches": row[6] or 0,
        "home_wins": row[7] or 0,
        "home_draws": row[8] or 0,
        "home_losses": row[9] or 0,
        "home_goals_for": float(row[10] or 0),
        "home_goals_against": float(row[11] or 0),
        "away_matches": row[12] or 0,
        "away_wins": row[13] or 0,
        "away_draws": row[14] or 0,
        "away_losses": row[15] or 0,
        "away_goals_for": float(row[16] or 0),
        "away_goals_against": float(row[17] or 0),
        "btts_hits": row[18] or 0,
        "over25_hits": row[19] or 0,
        "clean_sheets": row[20] or 0,
        "failed_to_score": row[21] or 0,
        "form_last5_points": row[22] or 0,
        "form_last5_wins": row[23] or 0,
        "form_last5_draws": row[24] or 0,
        "form_last5_losses": row[25] or 0,
        "form_last5_goals_for": float(row[26] or 0),
        "form_last5_goals_against": float(row[27] or 0),
    }


def _league_baselines(league_id: str, season_id: str) -> dict:
    sql = """
        SELECT
            COALESCE(AVG(home_goals), 1.40) AS avg_home_goals,
            COALESCE(AVG(away_goals), 1.15) AS avg_away_goals
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

    return {
        "avg_home_goals": _clamp(float(row[0] or 1.40), 0.6, 3.5),
        "avg_away_goals": _clamp(float(row[1] or 1.15), 0.4, 3.0),
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


def _fetch_fixture_rows_today() -> List[tuple]:
    now_utc = datetime.now(timezone.utc)
    start_day = datetime(now_utc.year, now_utc.month, now_utc.day, tzinfo=timezone.utc)
    end_day = start_day + timedelta(days=1)

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
        WHERE f.kickoff_at >= %s
          AND f.kickoff_at < %s
        ORDER BY f.kickoff_at ASC
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (start_day, end_day))
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


# =========================================================
# MODEL CORE
# =========================================================

def _correct_score_top(home_xg: float, away_xg: float, top_n: int = 4) -> List[Dict[str, Any]]:
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
    home_xg = 1.45
    away_xg = 1.15

    p_home = 0.0
    p_draw = 0.0
    p_away = 0.0
    p_over25 = 0.0
    p_btts = 0.0

    for hg in range(0, 6):
        for ag in range(0, 6):
            prob = _poisson_pmf(hg, home_xg) * _poisson_pmf(ag, away_xg)
            if hg > ag:
                p_home += prob
            elif hg == ag:
                p_draw += prob
            else:
                p_away += prob
            if hg + ag > 2:
                p_over25 += prob
            if hg > 0 and ag > 0:
                p_btts += prob

    p1 = _round1(p_home * 100)
    px = _round1(p_draw * 100)
    p2 = _round1(p_away * 100)
    gg = _round1(p_btts * 100)
    no_gg = _round1(100 - gg)
    over25 = _round1(p_over25 * 100)
    under25 = _round1(100 - over25)
    x1 = _round1(p1 + px)
    x2 = _round1(px + p2)
    _12 = _round1(p1 + p2)

    market_scores = {
        "1": p1,
        "X": px,
        "2": p2,
        "GG": gg,
        "NO_GG": no_gg,
        "OVER_2_5": over25,
        "UNDER_2_5": under25,
        "1X": x1,
        "X2": x2,
        "12": _12,
    }

    best_market = max(market_scores, key=market_scores.get)
    best_confidence = market_scores[best_market]

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
            "type": "fallback_propp",
            "home_xg": _round2(home_xg),
            "away_xg": _round2(away_xg),
        },
        "markets": {
            "1x2": {
                "1": p1,
                "X": px,
                "2": p2,
                "fair_odds": {
                    "1": _fair_odds(p1),
                    "X": _fair_odds(px),
                    "2": _fair_odds(p2),
                },
            },
            "double_chance": {
                "1X": x1,
                "X2": x2,
                "12": _12,
            },
            "btts": {
                "GG": gg,
                "NO_GG": no_gg,
                "fair_odds": {
                    "GG": _fair_odds(gg),
                },
            },
            "ou_2_5": {
                "OVER_2_5": over25,
                "UNDER_2_5": under25,
                "fair_odds": {
                    "OVER_2_5": _fair_odds(over25),
                },
            },
            "correct_score_top": _correct_score_top(home_xg, away_xg),
        },
        "top_pick": {
            "market": best_market,
            "confidence": _round1(best_confidence),
        },
        "analysis": {
            "summary": f"{home_name} vs {away_name}: fallback model activ.",
            "notes": [
                "Statistici insuficiente pentru engine PRO++ complet.",
            ],
        },
    }


def _build_prediction_from_fixture_row(row: tuple) -> Dict[str, Any]:
    fixture_id = str(row[0])
    provider_fixture_id = row[1]
    kickoff_at = row[2].isoformat() if hasattr(row[2], "isoformat") else str(row[2])
    status = row[3]
    round_name = row[4]
    league_id = str(row[5])
    season_id = str(row[6])
    league_name = row[7] or ""
    league_country = row[8] or ""
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
            fixture_id=fixture_id,
            provider_fixture_id=provider_fixture_id,
            kickoff_at=kickoff_at,
            status=status,
            round_name=round_name,
            league_id=league_id,
            season_id=season_id,
            league_name=league_name,
            league_country=league_country,
            home_team_id=home_team_id,
            home_name=home_name,
            home_short=home_short,
            away_team_id=away_team_id,
            away_name=away_name,
            away_short=away_short,
        )

    home_elo = _fetch_team_elo(home_team_id)
    away_elo = _fetch_team_elo(away_team_id)

    league_base = _league_baselines(league_id, season_id)
    avg_home_goals = league_base["avg_home_goals"]
    avg_away_goals = league_base["avg_away_goals"]

    home_matches = max(1, home_stats["home_matches"])
    away_matches = max(1, away_stats["away_matches"])
    total_home_matches = max(1, home_stats["matches_played"])
    total_away_matches = max(1, away_stats["matches_played"])

    # Home/Away attack-defense
    home_home_gf = _safe_div(home_stats["home_goals_for"], home_matches)
    home_home_ga = _safe_div(home_stats["home_goals_against"], home_matches)

    away_away_gf = _safe_div(away_stats["away_goals_for"], away_matches)
    away_away_ga = _safe_div(away_stats["away_goals_against"], away_matches)

    # Overall attack-defense
    home_overall_gf = _safe_div(home_stats["goals_for"], total_home_matches)
    home_overall_ga = _safe_div(home_stats["goals_against"], total_home_matches)

    away_overall_gf = _safe_div(away_stats["goals_for"], total_away_matches)
    away_overall_ga = _safe_div(away_stats["goals_against"], total_away_matches)

    # Form
    home_form_ppg = _safe_div(home_stats["form_last5_points"], 5.0)
    away_form_ppg = _safe_div(away_stats["form_last5_points"], 5.0)

    home_form_gf = _safe_div(home_stats["form_last5_goals_for"], 5.0)
    home_form_ga = _safe_div(home_stats["form_last5_goals_against"], 5.0)

    away_form_gf = _safe_div(away_stats["form_last5_goals_for"], 5.0)
    away_form_ga = _safe_div(away_stats["form_last5_goals_against"], 5.0)

    # Strength factors
    home_attack_strength = _safe_div((home_home_gf * 0.65) + (home_overall_gf * 0.35), avg_home_goals)
    away_attack_strength = _safe_div((away_away_gf * 0.65) + (away_overall_gf * 0.35), avg_away_goals)

    away_defense_weakness = _safe_div((away_away_ga * 0.65) + (away_overall_ga * 0.35), avg_home_goals)
    home_defense_weakness = _safe_div((home_home_ga * 0.65) + (home_overall_ga * 0.35), avg_away_goals)

    # Recent form multipliers
    home_form_mult = 1.0 + ((home_form_ppg - 1.5) * 0.10)
    away_form_mult = 1.0 + ((away_form_ppg - 1.5) * 0.10)

    home_form_mult = _clamp(home_form_mult, 0.82, 1.22)
    away_form_mult = _clamp(away_form_mult, 0.82, 1.22)

    # Goal trend multipliers
    home_goal_trend_mult = 1.0 + ((home_form_gf - home_overall_gf) * 0.07)
    away_goal_trend_mult = 1.0 + ((away_form_gf - away_overall_gf) * 0.07)

    home_goal_trend_mult = _clamp(home_goal_trend_mult, 0.90, 1.12)
    away_goal_trend_mult = _clamp(away_goal_trend_mult, 0.90, 1.12)

    # Defensive trend
    home_def_trend_mult = 1.0 + ((home_form_ga - home_overall_ga) * 0.06)
    away_def_trend_mult = 1.0 + ((away_form_ga - away_overall_ga) * 0.06)

    home_def_trend_mult = _clamp(home_def_trend_mult, 0.90, 1.12)
    away_def_trend_mult = _clamp(away_def_trend_mult, 0.90, 1.12)

    # ELO influence
    elo_diff = home_elo - away_elo
    elo_factor_home = _clamp(1.0 + (elo_diff / 4000.0), 0.86, 1.16)
    elo_factor_away = _clamp(1.0 - (elo_diff / 4000.0), 0.86, 1.16)

    # BTTS / Over rates
    home_btts_rate = _safe_div(home_stats["btts_hits"], total_home_matches)
    away_btts_rate = _safe_div(away_stats["btts_hits"], total_away_matches)
    home_over25_rate = _safe_div(home_stats["over25_hits"], total_home_matches)
    away_over25_rate = _safe_div(away_stats["over25_hits"], total_away_matches)

    btts_mult = 1.0 + ((((home_btts_rate + away_btts_rate) / 2.0) - 0.5) * 0.10)
    over25_mult = 1.0 + ((((home_over25_rate + away_over25_rate) / 2.0) - 0.5) * 0.18)

    btts_mult = _clamp(btts_mult, 0.94, 1.08)
    over25_mult = _clamp(over25_mult, 0.90, 1.14)

    # Base xG
    home_xg = avg_home_goals * home_attack_strength * away_defense_weakness
    away_xg = avg_away_goals * away_attack_strength * home_defense_weakness

    # Adjustments
    home_xg *= 1.06  # home advantage
    home_xg *= home_form_mult
    away_xg *= away_form_mult

    home_xg *= home_goal_trend_mult
    away_xg *= away_goal_trend_mult

    home_xg *= away_def_trend_mult
    away_xg *= home_def_trend_mult

    home_xg *= elo_factor_home
    away_xg *= elo_factor_away

    home_xg *= over25_mult
    away_xg *= over25_mult

    home_xg *= btts_mult
    away_xg *= btts_mult

    home_xg = _clamp(home_xg, 0.20, 3.90)
    away_xg = _clamp(away_xg, 0.15, 3.60)

    # Poisson matrix
    p_home = 0.0
    p_draw = 0.0
    p_away = 0.0
    p_over25 = 0.0
    p_under25 = 0.0
    p_btts_yes = 0.0
    p_btts_no = 0.0

    for hg in range(0, 6):
        for ag in range(0, 6):
            prob = _poisson_pmf(hg, home_xg) * _poisson_pmf(ag, away_xg)

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

    correct_scores = _correct_score_top(home_xg, away_xg)

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
            "type": "engine_pro_pp",
            "home_xg": _round2(home_xg),
            "away_xg": _round2(away_xg),
            "avg_home_goals_league": _round2(avg_home_goals),
            "avg_away_goals_league": _round2(avg_away_goals),
            "home_elo": _round1(home_elo),
            "away_elo": _round1(away_elo),
            "elo_diff": _round1(elo_diff),
        },
        "markets": {
            "1x2": {
                "1": p1,
                "X": px,
                "2": p2,
                "fair_odds": {
                    "1": _fair_odds(p1),
                    "X": _fair_odds(px),
                    "2": _fair_odds(p2),
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
                    "GG": _fair_odds(gg_yes),
                },
            },
            "ou_2_5": {
                "OVER_2_5": over25,
                "UNDER_2_5": under25,
                "fair_odds": {
                    "OVER_2_5": _fair_odds(over25),
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
                f"{home_name} vs {away_name}: xG {_round2(home_xg)} - {_round2(away_xg)}, "
                f"top pick {best_market} ({best_confidence}%)."
            ),
            "notes": [
                "Engine PRO++: formă recentă + home/away split + ELO + Poisson.",
                "Scorurile corecte sunt estimate din matricea Poisson 0-5 goluri.",
                "Probabilitățile 1X2, GG și O2.5 sunt derivate din xG ajustat.",
            ],
        },
    }


def _serialize_items(rows: List[tuple]) -> List[Dict[str, Any]]:
    return [_build_prediction_from_fixture_row(r) for r in rows]


# =========================================================
# ROUTES
# =========================================================

@router.get("/predictions")
def list_predictions(limit: int = 50) -> Dict[str, Any]:
    cache_key = f"predictions:{limit}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    rows = _fetch_fixture_rows(limit=limit)
    items = _serialize_items(rows)

    result = {
        "count": len(items),
        "items": items,
    }
    _cache_set(cache_key, result)
    return result


@router.get("/predictions/today")
def list_predictions_today() -> Dict[str, Any]:
    cache_key = "predictions:today"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    rows = _fetch_fixture_rows_today()
    items = _serialize_items(rows)

    result = {
        "count": len(items),
        "items": items,
    }
    _cache_set(cache_key, result)
    return result


@router.get("/predictions/top")
def list_top_predictions(limit: int = 20) -> Dict[str, Any]:
    cache_key = f"predictions:top:{limit}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    rows = _fetch_fixture_rows(limit=200)
    items = _serialize_items(rows)

    items.sort(key=lambda x: x["top_pick"]["confidence"], reverse=True)
    items = items[:limit]

    result = {
        "count": len(items),
        "items": items,
    }
    _cache_set(cache_key, result)
    return result


@router.get("/predictions/by-fixture/{fixture_id}")
def prediction_by_fixture(fixture_id: str) -> Dict[str, Any]:
    cache_key = f"predictions:fixture:{fixture_id}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    row = _fetch_fixture_row_by_id(fixture_id)
    if not row:
        raise HTTPException(status_code=404, detail="Fixture not found")

    result = _build_prediction_from_fixture_row(row)
    _cache_set(cache_key, result)
    return result
