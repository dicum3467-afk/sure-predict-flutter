from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, Tuple, List


@dataclass(frozen=True)
class MarketProbs:
    # FT
    one_x_two: Dict[str, float]            # {"1":p, "X":p, "2":p}
    double_chance: Dict[str, float]        # {"1X":p, "12":p, "X2":p}
    btts: Dict[str, float]                # {"GG":p, "NG":p}
    totals: Dict[str, Dict[str, float]]    # {"2.5": {"over":p,"under":p}, ...}
    correct_score: Dict[str, float]        # {"0-0":p, "1-0":p, ...}

    # HT
    ht_one_x_two: Dict[str, float]         # {"1":p, "X":p, "2":p}
    ht_totals: Dict[str, Dict[str, float]] # totals at HT
    ht_btts: Dict[str, float]              # BTTS at HT (rarely used, but ok)

    # HT/FT
    ht_ft: Dict[str, float]                # {"1/1":p, "1/X":p, ...}


def _pois_pmf(k: int, lam: float) -> float:
    # stable enough for small k up to ~10
    return math.exp(-lam) * (lam ** k) / math.factorial(k)


def score_matrix(lam_home: float, lam_away: float, max_goals: int = 6) -> List[List[float]]:
    # M[i][j] = P(home=i, away=j)
    home = [_pois_pmf(i, lam_home) for i in range(max_goals + 1)]
    away = [_pois_pmf(j, lam_away) for j in range(max_goals + 1)]
    m = [[home[i] * away[j] for j in range(max_goals + 1)] for i in range(max_goals + 1)]
    # normalize (tail beyond max_goals is cut)
    s = sum(sum(row) for row in m)
    if s > 0:
        m = [[v / s for v in row] for row in m]
    return m


def probs_from_matrix(m: List[List[float]]) -> Tuple[Dict[str, float], Dict[str, float], Dict[str, float], Dict[str, float], Dict[str, float]]:
    max_goals = len(m) - 1

    p1 = 0.0
    px = 0.0
    p2 = 0.0
    pgg = 0.0
    png = 0.0

    totals_cache: Dict[int, float] = {}  # P(total = t)

    for i in range(max_goals + 1):
        for j in range(max_goals + 1):
            p = m[i][j]
            if i > j:
                p1 += p
            elif i == j:
                px += p
            else:
                p2 += p

            if i >= 1 and j >= 1:
                pgg += p
            else:
                png += p

            t = i + j
            totals_cache[t] = totals_cache.get(t, 0.0) + p

    one_x_two = {"1": p1, "X": px, "2": p2}
    double_chance = {
        "1X": p1 + px,
        "12": p1 + p2,
        "X2": px + p2,
    }
    btts = {"GG": pgg, "NG": png}

    # Over/Under lines
    # line 2.5 => over if total >= 3 ; under if total <=2
    def over_under(line: float) -> Dict[str, float]:
        threshold = int(math.floor(line)) + 1  # e.g. 2.5 -> 3
        pover = sum(p for t, p in totals_cache.items() if t >= threshold)
        punder = 1.0 - pover
        return {"over": pover, "under": punder}

    totals = {
        "0.5": over_under(0.5),
        "1.5": over_under(1.5),
        "2.5": over_under(2.5),
        "3.5": over_under(3.5),
        "4.5": over_under(4.5),
    }

    correct_score: Dict[str, float] = {}
    for i in range(max_goals + 1):
        for j in range(max_goals + 1):
            correct_score[f"{i}-{j}"] = m[i][j]

    return one_x_two, double_chance, btts, totals, correct_score


def htft_probs(ht: Dict[str, float], ft: Dict[str, float]) -> Dict[str, float]:
    # MVP approximation: independence between HT and FT outcomes
    # ht keys: "1","X","2" ; ft keys: "1","X","2"
    out: Dict[str, float] = {}
    for h_key, h_p in ht.items():
        for f_key, f_p in ft.items():
            out[f"{h_key}/{f_key}"] = h_p * f_p
    # normalize just in case
    s = sum(out.values())
    if s > 0:
        for k in list(out.keys()):
            out[k] /= s
    return out


def build_markets(
    lam_home_ft: float,
    lam_away_ft: float,
    max_goals: int = 6,
    ht_goal_share: float = 0.45,  # ~45% goals in first half (rough average)
) -> MarketProbs:
    # FT matrix
    m_ft = score_matrix(lam_home_ft, lam_away_ft, max_goals=max_goals)
    ft_1x2, ft_dc, ft_btts, ft_totals, ft_cs = probs_from_matrix(m_ft)

    # HT matrix
    lam_home_ht = max(0.01, lam_home_ft * ht_goal_share)
    lam_away_ht = max(0.01, lam_away_ft * ht_goal_share)
    m_ht = score_matrix(lam_home_ht, lam_away_ht, max_goals=max_goals)
    ht_1x2, _, ht_btts, ht_totals, _ = probs_from_matrix(m_ht)

    # HT/FT
    ht_ft = htft_probs(ht_1x2, ft_1x2)

    return MarketProbs(
        one_x_two=ft_1x2,
        double_chance=ft_dc,
        btts=ft_btts,
        totals=ft_totals,
        correct_score=ft_cs,
        ht_one_x_two=ht_1x2,
        ht_totals=ht_totals,
        ht_btts=ht_btts,
        ht_ft=ht_ft,
          )
