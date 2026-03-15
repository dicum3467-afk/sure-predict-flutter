from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Tuple

supabase_client = None
from app.services.predictions_engine import MODEL_VERSION, compute_prediction_for_fixture
from app.services.evaluation_metrics import (
    brier_binary, logloss_binary,
    brier_multiclass, logloss_multiclass,
    accuracy_from_probs,
)
from app.services.calibration import fit_platt_binary, fit_platt_ovr, serialize_calibration


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)

def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()

def _fetch_finished_fixtures(from_dt: datetime, to_dt: datetime, league_id: int | None = None, limit: int = 5000):
    q = (
        supabase_client.table("fixtures")
        .select("id, league_id, kickoff_at, home_team_id, away_team_id, home_goals, away_goals, status")
        .gte("kickoff_at", _iso(from_dt))
        .lte("kickoff_at", _iso(to_dt))
    )
    if league_id is not None:
        q = q.eq("league_id", league_id)

    data = q.order("kickoff_at", desc=False).limit(limit).execute().data or []
    out = []
    for f in data:
        if f.get("home_goals") is None or f.get("away_goals") is None:
            continue
        out.append(f)
    return out

def _fetch_past_matches_for_league(league_id: int, before_dt: datetime, limit: int = 2000):
    res = (
        supabase_client.table("fixtures")
        .select("id, league_id, kickoff_at, home_team_id, away_team_id, home_goals, away_goals, status")
        .eq("league_id", league_id)
        .lt("kickoff_at", _iso(before_dt))
        .order("kickoff_at", desc=True)
        .limit(limit)
        .execute()
        .data
        or []
    )
    out = []
    for m in res:
        if m.get("home_goals") is None or m.get("away_goals") is None:
            continue
        out.append(m)
    out.sort(key=lambda x: x["kickoff_at"])
    return out

def _league_avg_goals(past):
    if not past:
        return 2.6
    s, n = 0, 0
    for m in past:
        s += int(m.get("home_goals") or 0) + int(m.get("away_goals") or 0)
        n += 1
    return max(1.8, min(3.4, s / max(1, n)))

def _league_scored_avg(past):
    return _league_avg_goals(past) / 2.0

def _outcome_1x2(hg: int, ag: int) -> str:
    if hg > ag:
        return "1"
    if hg < ag:
        return "2"
    return "X"

def _label_gg(hg: int, ag: int) -> int:
    return 1 if (hg >= 1 and ag >= 1) else 0

def _label_o25(hg: int, ag: int) -> int:
    return 1 if (hg + ag) >= 3 else 0

def _save_calibration(params: Dict[str, Any], meta: Dict[str, Any]):
    row = {
        "model_version": MODEL_VERSION,
        "params": params,
        "meta": meta,
        "updated_at": _iso(_utc_now()),
    }
    supabase_client.table("model_calibration").upsert(row, on_conflict="model_version").execute()

def _insert_eval_run(model_version: str, range_obj: Dict[str, Any], sample: Dict[str, Any], metrics: Dict[str, Any]) -> int:
    row = {"model_version": model_version, "range": range_obj, "sample": sample, "metrics": metrics}
    ins = supabase_client.table("model_eval_runs").insert(row).execute().data
    return int(ins[0]["id"])

def _insert_league_metrics(run_id: int, league_metrics: Dict[int, Dict[str, Any]]):
    rows = []
    for lg_id, m in league_metrics.items():
        rows.append({"run_id": run_id, "league_id": int(lg_id), "metrics": m})
    if rows:
        supabase_client.table("model_eval_league").insert(rows).execute()

def run_evaluation_and_calibration_job(
    days_back: int = 120,
    min_samples: int = 120,
    league_id: int | None = None,
) -> Dict[str, Any]:
    """
    1) ia fixtures terminate in ultimii days_back
    2) genereaza predicții "raw" (fără calibrare) pentru fiecare fixture folosind istoricul de dinainte
    3) face calibrare Platt (GG, O2.5, 1X2)
    4) evaluează înainte și după calibrare; salvează
    """
    now = _utc_now()
    from_dt = now - timedelta(days=days_back)
    finished = _fetch_finished_fixtures(from_dt, now, league_id=league_id)

    if len(finished) < min_samples:
        return {
            "ok": False,
            "reason": "not_enough_samples",
            "have": len(finished),
            "need": min_samples,
            "range": {"from": _iso(from_dt), "to": _iso(now)},
            "league_id": league_id,
        }

    # group by league for efficiency
    by_league: Dict[int, List[Dict[str, Any]]] = {}
    for f in finished:
        by_league.setdefault(int(f["league_id"]), []).append(f)

    # collect datasets
    probs_1x2_raw: List[Dict[str, float]] = []
    y_1x2: List[str] = []
    p_gg_raw: List[float] = []
    y_gg: List[int] = []
    p_o25_raw: List[float] = []
    y_o25: List[int] = []

    # also per-league store
    per_league_raw = {}  # league -> lists
    for lg_id in by_league.keys():
        per_league_raw[lg_id] = {
            "probs_1x2": [], "y_1x2": [],
            "p_gg": [], "y_gg": [],
            "p_o25": [], "y_o25": [],
        }

    for lg_id, fixtures in by_league.items():
        fixtures.sort(key=lambda x: x["kickoff_at"])
        # history for league: take matches before each fixture kickoff
        # We'll fetch a big past pool once, then slice by kickoff.
        past_pool = _fetch_past_matches_for_league(lg_id, before_dt=now, limit=2500)
        # create an index by kickoff to slice
        past_pool_sorted = sorted(past_pool, key=lambda x: x["kickoff_at"])

        for fx in fixtures:
            fx_kick = fx["kickoff_at"]
            # build past list strictly before this fixture kickoff
            past = [m for m in past_pool_sorted if m["kickoff_at"] < fx_kick]
            if len(past) < 40:
                # too little context -> still allow but will be noisy
                pass

            league_avg = _league_avg_goals(past)
            league_scored = _league_scored_avg(past)

            # raw prediction (no calibration)
            pred = compute_prediction_for_fixture(
                fixture=fx,
                past_matches=past,
                league_avg_goals=league_avg,
                league_scored_avg=league_scored,
                home_adv=1.10,
                cal_binary=None,
                cal_ovr=None,
            )

            hg = int(fx["home_goals"])
            ag = int(fx["away_goals"])

            y1 = _outcome_1x2(hg, ag)
            ygg = _label_gg(hg, ag)
            yo = _label_o25(hg, ag)

            pr1x2 = {k: float(v) for k, v in pred["probs"]["1x2"].items()}
            pgg = float(pred["probs"]["gg"]["GG"])
            po = float(pred["probs"]["ou25"]["O2.5"])

            probs_1x2_raw.append(pr1x2); y_1x2.append(y1)
            p_gg_raw.append(pgg); y_gg.append(ygg)
            p_o25_raw.append(po); y_o25.append(yo)

            per_league_raw[lg_id]["probs_1x2"].append(pr1x2)
            per_league_raw[lg_id]["y_1x2"].append(y1)
            per_league_raw[lg_id]["p_gg"].append(pgg)
            per_league_raw[lg_id]["y_gg"].append(ygg)
            per_league_raw[lg_id]["p_o25"].append(po)
            per_league_raw[lg_id]["y_o25"].append(yo)

    # ----- fit calibration -----
    cal_gg = fit_platt_binary(p_gg_raw, y_gg)
    cal_ou25 = fit_platt_binary(p_o25_raw, y_o25)
    cal_1x2 = fit_platt_ovr(probs_1x2_raw, y_1x2)

    params = serialize_calibration(binary={"gg": cal_gg, "ou25": cal_ou25}, ovr=cal_1x2)
    meta = {
        "trained_at": _iso(now),
        "days_back": days_back,
        "samples": len(finished),
        "league_id": league_id,
    }
    _save_calibration(params=params, meta=meta)

    # ----- evaluate raw vs calibrated -----
    # apply calibration to datasets
    probs_1x2_cal = [cal_1x2.apply_probs(p) for p in probs_1x2_raw]
    p_gg_cal = [cal_gg.apply(p) for p in p_gg_raw]
    p_o25_cal = [cal_ou25.apply(p) for p in p_o25_raw]

    metrics = {
        "raw": {
            "1x2": {
                "accuracy": round(accuracy_from_probs(probs_1x2_raw, y_1x2), 6),
                "brier": round(brier_multiclass(probs_1x2_raw, y_1x2), 6),
                "logloss": round(logloss_multiclass(probs_1x2_raw, y_1x2), 6),
            },
            "gg": {
                "brier": round(brier_binary(p_gg_raw, y_gg), 6),
                "logloss": round(logloss_binary(p_gg_raw, y_gg), 6),
            },
            "ou25": {
                "brier": round(brier_binary(p_o25_raw, y_o25), 6),
                "logloss": round(logloss_binary(p_o25_raw, y_o25), 6),
            },
        },
        "calibrated": {
            "1x2": {
                "accuracy": round(accuracy_from_probs(probs_1x2_cal, y_1x2), 6),
                "brier": round(brier_multiclass(probs_1x2_cal, y_1x2), 6),
                "logloss": round(logloss_multiclass(probs_1x2_cal, y_1x2), 6),
            },
            "gg": {
                "brier": round(brier_binary(p_gg_cal, y_gg), 6),
                "logloss": round(logloss_binary(p_gg_cal, y_gg), 6),
            },
            "ou25": {
                "brier": round(brier_binary(p_o25_cal, y_o25), 6),
                "logloss": round(logloss_binary(p_o25_cal, y_o25), 6),
            },
        },
        "calibration_params": params,
    }

    run_id = _insert_eval_run(
        model_version=MODEL_VERSION,
        range_obj={"from": _iso(from_dt), "to": _iso(now), "league_id": league_id},
        sample={"fixtures": len(finished)},
        metrics=metrics,
    )

    # per-league metrics (raw + calibrated)
    league_metrics: Dict[int, Dict[str, Any]] = {}
    for lg_id, d in per_league_raw.items():
        if len(d["y_1x2"]) < 30:
            continue
        probs_raw = d["probs_1x2"]
        probs_cal = [cal_1x2.apply_probs(p) for p in probs_raw]
        gg_raw = d["p_gg"]; gg_cal = [cal_gg.apply(p) for p in gg_raw]
        ou_raw = d["p_o25"]; ou_cal = [cal_ou25.apply(p) for p in ou_raw]

        league_metrics[int(lg_id)] = {
            "n": len(d["y_1x2"]),
            "raw": {
                "1x2": {
                    "accuracy": round(accuracy_from_probs(probs_raw, d["y_1x2"]), 6),
                    "brier": round(brier_multiclass(probs_raw, d["y_1x2"]), 6),
                    "logloss": round(logloss_multiclass(probs_raw, d["y_1x2"]), 6),
                },
                "gg": {
                    "brier": round(brier_binary(gg_raw, d["y_gg"]), 6),
                    "logloss": round(logloss_binary(gg_raw, d["y_gg"]), 6),
                },
                "ou25": {
                    "brier": round(brier_binary(ou_raw, d["y_o25"]), 6),
                    "logloss": round(logloss_binary(ou_raw, d["y_o25"]), 6),
                },
            },
            "calibrated": {
                "1x2": {
                    "accuracy": round(accuracy_from_probs(probs_cal, d["y_1x2"]), 6),
                    "brier": round(brier_multiclass(probs_cal, d["y_1x2"]), 6),
                    "logloss": round(logloss_multiclass(probs_cal, d["y_1x2"]), 6),
                },
                "gg": {
                    "brier": round(brier_binary(gg_cal, d["y_gg"]), 6),
                    "logloss": round(logloss_binary(gg_cal, d["y_gg"]), 6),
                },
                "ou25": {
                    "brier": round(brier_binary(ou_cal, d["y_o25"]), 6),
                    "logloss": round(logloss_binary(ou_cal, d["y_o25"]), 6),
                },
            },
        }

    _insert_league_metrics(run_id, league_metrics)

    return {
        "ok": True,
        "run_id": run_id,
        "model_version": MODEL_VERSION,
        "range": {"from": _iso(from_dt), "to": _iso(now)},
        "fixtures": len(finished),
        "calibration_saved": True,
        "league_id": league_id,
  }
