from app.utils.math_utils import round1, round2


def compute_value(model_prob_percent: float, bookmaker_odds: float):
    if not bookmaker_odds or bookmaker_odds <= 1.0:
        return None

    implied_prob = 100.0 / bookmaker_odds
    edge = model_prob_percent - implied_prob

    return {
        "bookmaker_odds": round2(bookmaker_odds),
        "implied_probability": round1(implied_prob),
        "model_probability": round1(model_prob_percent),
        "edge": round1(edge),
        "is_value": edge >= 3.0,
    }
