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


def _safe_div(a: float, b: float) -> float:
    return a / b if b else 0.0


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

    if home_stats and away_stats:
        # Formă + producție ofensivă/defensivă
        home_points_per_match = _safe_div(
            home_stats["wins"] * 3 + home_stats["draws"],
            max(1, home_stats["matches_played"])
        )
        away_points_per_match = _safe_div(
            away_stats["wins"] * 3 + away_stats["draws"],
            max(1, away_stats["matches_played"])
        )

        home_goals_for_avg = _safe_div(
            home_stats["goals_for"],
            max(1, home_stats["matches_played"])
        )
        home_goals_against_avg = _safe_div(
            home_stats["goals_against"],
            max(1, home_stats["matches_played"])
        )

        away_goals_for_avg = _safe_div(
            away_stats["goals_for"],
            max(1, away_stats["matches_played"])
        )
        away_goals_against_avg = _safe_div(
            away_stats["goals_against"],
            max(1, away_stats["matches_played"])
        )

        home_form_score = _safe_div(home_stats["form_last5_points"], 15) * 100.0
        away_form_score = _safe_div(away_stats["form_last5_points"], 15) * 100.0

        home_btts_rate = _safe_div(
            home_stats["btts_hits"],
            max(1, home_stats["matches_played"])
        ) * 100.0
        away_btts_rate = _safe_div(
            away_stats["btts_hits"],
            max(1, away_stats["matches_played"])
        ) * 100.0

        home_over25_rate = _safe_div(
            home_stats["over25_hits"],
            max(1, home_stats["matches_played"])
        ) * 100.0
        away_over25_rate = _safe_div(
            away_stats["over25_hits"],
            max(1, away_stats["matches_played"])
        ) * 100.0

        # Split home/away mai realist
        home_home_points = _safe_div(
            home_stats["home_wins"] * 3 + home_stats["home_draws"],
            max(1, home_stats["home_matches"])
        )
        away_away_points = _safe_div(
            away_stats["away_wins"] * 3 + away_stats["away_draws"],
            max(1, away_stats["away_matches"])
        )

        home_home_gf_avg = _safe_div(
            home_stats["home_goals_for"],
            max(1, home_stats["home_matches"])
        )
        home_home_ga_avg = _safe_div(
            home_stats["home_goals_against"],
            max(1, home_stats["home_matches"])
        )

        away_away_gf_avg = _safe_div(
            away_stats["away_goals_for"],
            max(1, away_stats["away_matches"])
        )
        away_away_ga_avg = _safe_div(
            away_stats["away_goals_against"],
            max(1, away_stats["away_matches"])
        )

        # Scor compozit
        home_attack = (
            home_goals_for_avg * 18.0 +
            home_home_gf_avg * 18.0 +
            home_points_per_match * 10.0 +
            home_home_points * 10.0 +
            home_form_score * 0.30
        )

        away_attack = (
            away_goals_for_avg * 18.0 +
            away_away_gf_avg * 18.0 +
            away_points_per_match * 10.0 +
            away_away_points * 10.0 +
            away_form_score * 0.30
        )

        # Cu cât primește mai puține goluri, cu atât e mai bun defensiv
        home_def = (
            100.0
            - home_goals_against_avg * 14.0
            - home_home_ga_avg * 10.0
        )
        away_def = (
            100.0
            - away_goals_against_avg * 14.0
            - away_away_ga_avg * 10.0
        )

        home_score = home_attack + away_def + 10.0  # mic avantaj gazde
        away_score = away_attack + home_def

        draw_raw = 24.0 + (4.0 - abs(home_points_per_match - away_points_per_match) * 2.5)
        draw_raw = _clamp(draw_raw, 18.0, 30.0)

        p1, px, p2 = _normalize_three(
            _clamp(home_score, 20.0, 140.0),
            draw_raw,
            _clamp(away_score, 20.0, 140.0),
        )
        p1, px, p2 = _round1(p1), _round1(px), _round1(p2)

        gg_yes = _clamp((home_btts_rate + away_btts_rate) / 2.0, 25.0, 85.0)
        gg_no = _round1(100.0 - gg_yes)

        over25 = _clamp((home_over25_rate + away_over25_rate) / 2.0, 25.0, 85.0)
        under25 = _round1(100.0 - over25)

    else:
        # fallback rule-based dacă nu există team_stats
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

        home_raw = _clamp(home_strength, 20.0, 75.0)
        away_raw = _clamp(away_strength, 15.0, 70.0)
        draw_raw = draw_base

        p1, px, p2 = _normalize_three(home_raw, draw_raw, away_raw)
        p1, px, p2 = _round1(p1), _round1(px), _round1(p2)

        attack_index = (home_len + away_len + league_len) % 20
        gg_yes = _clamp(
            47.0 + attack_index * 1.2 - abs(home_len - away_len) * 0.8,
            35.0,
            78.0,
        )
        gg_no = _round1(100.0 - gg_yes)

        over25 = _clamp(
            45.0 + attack_index * 1.4 - abs(home_len - away_len) * 0.5,
            34.0,
            80.0,
        )
        under25 = _round1(100.0 - over25)

    x1 = _round1(p1 + px)
    x2 = _round1(px + p2)
    _12 = _round1(p1 + p2)

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
                f"{home_name} vs {away_name}: top pick {best_market} "
                f"cu încredere {best_confidence}%."
            ),
            "notes": [
                "Predicția folosește team_stats dacă există.",
                "Sunt incluse forma recentă, goluri marcate/primite și profil BTTS/O2.5.",
                "Dacă lipsesc statisticile, se folosește fallback rule-based.",
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
