from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

from app.services.calibration import PlattBinary, PlattOVR

MODEL_VERSION = "poisson_v2_mega_pro+++++"

# ----- helpers -----

def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))

def _clamp_p(p: float, eps: float = 1e-6) -> float:
    return max(eps, min(1.0 - eps, p))

def _poisson_pmf(lam: float, k: int) -> float:
    return math.exp(-lam) * (lam ** k) / math.factorial(k)

def _score_matrix(lam_home: float, lam_away: float, max_goals: int = 10) -> List[List[float]]:
    mat = []
    for i in range(max_goals + 1):
        row = []
        p_i = _poisson_pmf(lam_home, i)
        for j in range(max_goals + 1):
            row.append(p_i * _poisson_pmf(lam_away, j))
        mat.append(row)
    s = sum(sum(r) for r in mat)
    if s > 0:
        for i in range(len(mat)):
            for j in range(len(mat[i])):
                mat[i][j] /= s
    return mat

def _sum_region(mat: List[List[float]], cond) -> float:
    s = 0.0
    for i in range(len(mat)):
        for j in range(len(mat[i])):
            if cond(i, j):
                s += mat[i][j]
    return s

def _top_scorelines(mat: List[List[float]], topn: int = 7) -> List[Dict[str, Any]]:
    items = []
    for i in range(len(mat)):
        for j in range(len(mat[i])):
            items.append((mat[i][j], i, j))
    items.sort(reverse=True, key=lambda t: t[0])
    out = []
    for p, i, j in items[:topn]:
        out.append({"home": i, "away": j, "p": round(p, 6)})
    return out

def _odds_from_prob(p: float) -> Optional[float]:
    if p <= 0:
        return None
    return round(1.0 / p, 2)

def _pick_from_probs(probs: Dict[str, float]) -> Dict[str, Any]:
    best_k = max(probs.keys(), key=lambda k: probs[k])
    return {"pick": best_k, "p": round(probs[best_k], 6), "odds_fair": _odds_from_prob(probs[best_k])}

# ----- model core -----

@dataclass
class TeamStrength:
    attack: float
    defense: float

def compute_team_strengths(
    matches: List[Dict[str, Any]],
    team_id: int,
    *,
    half_life_matches: float = 20.0,
) -> Tuple[float, float, float]:
    w_sum = 0.0
    s_scored = 0.0
    s_conceded = 0.0
    n = len(matches)
    for idx, m in enumerate(matches):
        age = (n - 1 - idx)
        w = math.exp(-math.log(2) * (age / max(1e-6, half_life_matches)))

        h = int(m["home_team_id"])
        a = int(m["away_team_id"])
        hg = int(m.get("home_goals") or 0)
        ag = int(m.get("away_goals") or 0)

        if team_id == h:
            scored, conceded = hg, ag
        elif team_id == a:
            scored, conceded = ag, hg
        else:
            continue

        w_sum += w
        s_scored += w * scored
        s_conceded += w * conceded

    if w_sum <= 0:
        return 0.0, 0.0, 0.0

    return (s_scored / w_sum), (s_conceded / w_sum), w_sum

def strengths_from_form(team_scored_avg: float, team_conceded_avg: float, league_scored_avg: float) -> TeamStrength:
    league_scored_avg = max(0.8, league_scored_avg)
    attack = _clamp(team_scored_avg / league_scored_avg, 0.6, 1.6)
    defense = _clamp(team_conceded_avg / league_scored_avg, 0.6, 1.6)
    return TeamStrength(attack=attack, defense=defense)

def build_expected_goals(
    league_avg_goals: float,
    home_strength: TeamStrength,
    away_strength: TeamStrength,
    *,
    home_adv: float = 1.10,
    shrink: float = 0.65,
) -> Tuple[float, float, Dict[str, Any]]:
    base = max(0.2, league_avg_goals / 2.0)

    ha = 1.0 + shrink * (home_strength.attack - 1.0)
    hd = 1.0 + shrink * (home_strength.defense - 1.0)
    aa = 1.0 + shrink * (away_strength.attack - 1.0)
    ad = 1.0 + shrink * (away_strength.defense - 1.0)

    lam_home = base * ha * ad * home_adv
    lam_away = base * aa * hd

    lam_home = _clamp(lam_home, 0.2, 3.5)
    lam_away = _clamp(lam_away, 0.2, 3.5)

    inputs = {
        "league_avg_goals": league_avg_goals,
        "base": round(base, 4),
        "home_adv": home_adv,
        "shrink": shrink,
        "home_attack": round(ha, 4),
        "home_defense": round(hd, 4),
        "away_attack": round(aa, 4),
        "away_defense": round(ad, 4),
        "lambda_home": round(lam_home, 4),
        "lambda_away": round(lam_away, 4),
    }
    return lam_home, lam_away, inputs

def predict_markets_raw(lam_home: float, lam_away: float) -> Dict[str, Any]:
    mat = _score_matrix(lam_home, lam_away, max_goals=10)

    p_home = _sum_region(mat, lambda i, j: i > j)
    p_draw = _sum_region(mat, lambda i, j: i == j)
    p_away = _sum_region(mat, lambda i, j: i < j)

    p_gg = _sum_region(mat, lambda i, j: i >= 1 and j >= 1)
    p_u25 = _sum_region(mat, lambda i, j: (i + j) <= 2)
    p_o25 = 1.0 - p_u25

    p_1x = p_home + p_draw
    p_x2 = p_draw + p_away
    p_12 = p_home + p_away

    lam_h_ht = lam_home * 0.45
    lam_a_ht = lam_away * 0.45
    mat_ht = _score_matrix(lam_h_ht, lam_a_ht, max_goals=6)

    p_ht_h = _sum_region(mat_ht, lambda i, j: i > j)
    p_ht_d = _sum_region(mat_ht, lambda i, j: i == j)
    p_ht_a = _sum_region(mat_ht, lambda i, j: i < j)

    htft = {
        "H/H": p_ht_h * p_home,
        "H/D": p_ht_h * p_draw,
        "H/A": p_ht_h * p_away,
        "D/H": p_ht_d * p_home,
        "D/D": p_ht_d * p_draw,
        "D/A": p_ht_d * p_away,
        "A/H": p_ht_a * p_home,
        "A/D": p_ht_a * p_draw,
        "A/A": p_ht_a * p_away,
    }
    s = sum(htft.values())
    if s > 0:
        for k in list(htft.keys()):
            htft[k] /= s

    return {
        "1x2": {"1": p_home, "X": p_draw, "2": p_away},
        "double_chance": {"1X": p_1x, "X2": p_x2, "12": p_12},
        "gg": {"GG": p_gg, "NG": 1.0 - p_gg},
        "ou25": {"O2.5": p_o25, "U2.5": p_u25},
        "ht": {"HT1": p_ht_h, "HTX": p_ht_d, "HT2": p_ht_a},
        "htft": htft,
        "top_scorelines": _top_scorelines(mat, topn=7),
    }

def _apply_calibration(
    probs: Dict[str, Any],
    *,
    cal_binary: Dict[str, PlattBinary] | None = None,
    cal_ovr: PlattOVR | None = None,
) -> Dict[str, Any]:
    """
    Applies:
      - binary calibration to gg(GG) and ou25(O2.5) (and keeps complements)
      - ovr calibration to 1x2
    """
    cal_binary = cal_binary or {}

    # GG
    if "gg" in probs and "GG" in probs["gg"] and "gg" in cal_binary:
        p = float(probs["gg"]["GG"])
        p2 = cal_binary["gg"].apply(p)
        probs["gg"]["GG"] = p2
        probs["gg"]["NG"] = 1.0 - p2

    # O2.5
    if "ou25" in probs and "O2.5" in probs["ou25"] and "ou25" in cal_binary:
        p = float(probs["ou25"]["O2.5"])
        p2 = cal_binary["ou25"].apply(p)
        probs["ou25"]["O2.5"] = p2
        probs["ou25"]["U2.5"] = 1.0 - p2

    # 1X2 (OVR shared)
    if cal_ovr is not None and "1x2" in probs:
        probs["1x2"] = cal_ovr.apply_probs({k: float(v) for k, v in probs["1x2"].items()})

    # re-clamp + renorm for 1x2 just in case
    if "1x2" in probs:
        s = sum(probs["1x2"].values())
        if s > 0:
            probs["1x2"] = {k: _clamp_p(v / s) for k, v in probs["1x2"].items()}

    return probs

def compute_prediction_for_fixture(
    fixture: Dict[str, Any],
    past_matches: List[Dict[str, Any]],
    *,
    league_avg_goals: float,
    league_scored_avg: float,
    home_adv: float = 1.10,
    cal_binary: Dict[str, PlattBinary] | None = None,
    cal_ovr: PlattOVR | None = None,
) -> Dict[str, Any]:
    home_id = int(fixture["home_team_id"])
    away_id = int(fixture["away_team_id"])

    h_sc, h_conc, h_w = compute_team_strengths(past_matches, home_id, half_life_matches=20.0)
    a_sc, a_conc, a_w = compute_team_strengths(past_matches, away_id, half_life_matches=20.0)

    if h_w <= 0:
        h_sc, h_conc = league_scored_avg, league_scored_avg
    if a_w <= 0:
        a_sc, a_conc = league_scored_avg, league_scored_avg

    home_strength = strengths_from_form(h_sc, h_conc, league_scored_avg)
    away_strength = strengths_from_form(a_sc, a_conc, league_scored_avg)

    lam_home, lam_away, inputs = build_expected_goals(
        league_avg_goals=league_avg_goals,
        home_strength=home_strength,
        away_strength=away_strength,
        home_adv=home_adv,
        shrink=0.65,
    )

    probs = predict_markets_raw(lam_home, lam_away)
    probs = _apply_calibration(probs, cal_binary=cal_binary, cal_ovr=cal_ovr)

    picks = {
        "1x2": _pick_from_probs(probs["1x2"]),
        "double_chance": _pick_from_probs(probs["double_chance"]),
        "gg": _pick_from_probs(probs["gg"]),
        "ou25": _pick_from_probs(probs["ou25"]),
        "ht": _pick_from_probs(probs["ht"]),
        "htft": _pick_from_probs(probs["htft"]),
    }

    confidence = max(probs["1x2"].values())
    metrics = {
        "confidence_1x2": round(confidence, 6),
        "lambda_home": inputs["lambda_home"],
        "lambda_away": inputs["lambda_away"],
        "calibrated": bool(cal_binary or cal_ovr),
    }

    return {
        "model_version": MODEL_VERSION,
        "inputs": inputs,
        "probs": probs,
        "picks": picks,
        "metrics": metrics,
    }
