from __future__ import annotations

from typing import Dict, Any, List, Optional


def fair_odd_from_prob(p: float) -> Optional[float]:
    if p <= 0:
        return None
    return round(1.0 / p, 4)


def expected_value(prob: float, odd: float) -> float:
    """
    EV per 1 unit stake:
      EV = p*(odd-1) - (1-p)
         = p*odd - 1
    """
    return (prob * odd) - 1.0


def edge_from_fair(book_odd: float, fair_odd: float | None) -> float:
    if fair_odd is None or fair_odd <= 0:
        return 0.0
    return (book_odd / fair_odd) - 1.0


def extract_market_probs(prediction: Dict[str, Any]) -> Dict[str, Dict[str, float]]:
    """
    Normalizează shape-ul prediction['probs'] într-un map:
      market -> selection -> prob
    """
    probs = prediction.get("probs") or {}
    out: Dict[str, Dict[str, float]] = {}

    if "1x2" in probs:
        out["1x2"] = {k: float(v) for k, v in probs["1x2"].items()}

    if "double_chance" in probs:
        out["double_chance"] = {k: float(v) for k, v in probs["double_chance"].items()}

    if "gg" in probs:
        out["gg"] = {k: float(v) for k, v in probs["gg"].items()}

    if "ou25" in probs:
        out["ou25"] = {k: float(v) for k, v in probs["ou25"].items()}

    if "ht" in probs:
        out["ht"] = {k: float(v) for k, v in probs["ht"].items()}

    if "htft" in probs:
        out["htft"] = {k: float(v) for k, v in probs["htft"].items()}

    return out


def build_value_rows(
    fixture_id: int,
    model_version: str,
    prediction: Dict[str, Any],
    odds_rows: List[Dict[str, Any]],
    *,
    min_edge: float = 0.03,
    min_ev: float = 0.02,
) -> List[Dict[str, Any]]:
    """
    odds_rows: [{bookmaker, market, selection, odd}, ...]
    """
    markets = extract_market_probs(prediction)
    confidence = float((prediction.get("metrics") or {}).get("confidence_1x2", 0.0))

    out: List[Dict[str, Any]] = []

    for row in odds_rows:
        market = str(row["market"])
        selection = str(row["selection"])
        bookmaker = str(row["bookmaker"])
        odd = float(row["odd"])

        if market not in markets:
            continue
        if selection not in markets[market]:
            continue

        p = float(markets[market][selection])
        f_odd = fair_odd_from_prob(p)
        ev = expected_value(p, odd)
        edge = edge_from_fair(odd, f_odd)

        if edge < min_edge:
            continue
        if ev < min_ev:
            continue

        out.append(
            {
                "fixture_id": fixture_id,
                "model_version": model_version,
                "bookmaker": bookmaker,
                "market": market,
                "selection": selection,
                "model_prob": round(p, 6),
                "fair_odd": round(f_odd, 4) if f_odd else None,
                "book_odd": round(odd, 4),
                "edge": round(edge, 6),
                "expected_value": round(ev, 6),
                "confidence": round(confidence, 6),
            }
        )

    out.sort(key=lambda x: (x["expected_value"], x["edge"]), reverse=True)
    return out
