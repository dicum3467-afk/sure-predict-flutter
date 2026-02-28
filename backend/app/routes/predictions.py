from __future__ import annotations

from fastapi import APIRouter, HTTPException
from typing import Dict, Any

from app.services.prediction_engine import build_markets

router = APIRouter(tags=["predictions"])


@router.get("/predictions/match/{fixture_id}")
def predict_match(fixture_id: str) -> Dict[str, Any]:
    """
    Întoarce probabilități estimate (nu odds).
    Ai nevoie să înlocuiești partea de "lam_home_ft/lam_away_ft" cu ce calculezi tu din DB.
    """
    # TODO: calculează din DB:
    # lam_home_ft, lam_away_ft = estimate_lambdas_from_db(fixture_id)

    # MVP demo (înlocuiește):
    lam_home_ft = 1.45
    lam_away_ft = 1.10

    if lam_home_ft <= 0 or lam_away_ft <= 0:
        raise HTTPException(status_code=400, detail="Invalid lambdas")

    markets = build_markets(lam_home_ft, lam_away_ft, max_goals=6)

    return {
        "fixture_id": fixture_id,
        "xg_estimate": {"home": lam_home_ft, "away": lam_away_ft},
        "ft": {
            "1x2": markets.one_x_two,
            "double_chance": markets.double_chance,
            "btts": markets.btts,
            "totals": markets.totals,
            "correct_score_top10": dict(
                sorted(markets.correct_score.items(), key=lambda kv: kv[1], reverse=True)[:10]
            ),
        },
        "ht": {
            "1x2": markets.ht_one_x_two,
            "btts": markets.ht_btts,
            "totals": markets.ht_totals,
        },
        "ht_ft": markets.ht_ft,
    }
