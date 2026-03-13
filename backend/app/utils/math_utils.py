import math


def clamp(v: float, low: float, high: float) -> float:
    return max(low, min(high, v))


def safe_div(a: float, b: float) -> float:
    return a / b if b else 0.0


def round1(v: float) -> float:
    return round(v, 1)


def round2(v: float) -> float:
    return round(v, 2)


def poisson_pmf(k: int, lam: float) -> float:
    lam = max(lam, 0.0001)
    return math.exp(-lam) * (lam ** k) / math.factorial(k)


def fair_odds(prob_percent: float):
    if prob_percent <= 0:
        return None
    return round(100.0 / prob_percent, 2)
