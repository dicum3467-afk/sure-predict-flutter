from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

from app.db import supabase_client
from app.services.predictions_engine import (
    MODEL_VERSION,
    compute_prediction_for_fixture,
)
from app.services.calibration import load_calibration


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)

def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()

def _fetch_calibration():
    res = (
        supabase_client.table("model_calibration")
        .select("model_version, params, updated_at")
        .eq("model_version", MODEL_VERSION)
        .limit(1)
        .execute()
        .data
    )
    if not res:
        return {}, None
    params = res[0].get("params") or {}
    cal_binary, cal_ovr = load_calibration(params)
    return cal_binary, cal_ovr

def _fetch_upcoming_fixtures(from_dt: datetime, to_dt: datetime, league_id: int | None = None) -> List[Dict[str, Any]]:
    q = supabase_client.table("fixtures").select(
        "id, league_id, kickoff_at, home_team_id, away_team_id, status"
    ).gte("kickoff_at", _iso(from_dt)).lte("kickoff_at", _iso(to_dt))

    if league_id is not None:
        q = q.eq("league_id", league_id)

    res = q.order("kickoff_at", desc=False).limit(1200).execute().data or []
    out = []
    for f in res:
        st = (f.get("status") or "").lower()
        if st in ("ft", "aet", "pen", "finished"):
            continue
        out.append(f)
    return out

def _fetch_past_matches_for_league(league_id: int, before_dt: datetime, limit: int = 1200) -> List[Dict[str, Any]]:
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

def _league_avg_goals(past: List[Dict[str, Any]]) -> float:
    if not past:
        return 2.6
    s, n = 0, 0
    for m in past:
        s += int(m.get("home_goals") or 0) + int(m.get("away_goals") or 0)
        n += 1
    return max(1.8, min(3.4, s / max(1, n)))

def _league_scored_avg(past: List[Dict[str, Any]]) -> float:
    return _league_avg_goals(past) / 2.0

def _upsert_prediction(fixture_id: int, payload: Dict[str, Any]) -> None:
    row = {
        "fixture_id": fixture_id,
        "model_version": payload["model_version"],
        "inputs": payload["inputs"],
        "probs": payload["probs"],
        "picks": payload["picks"],
        "metrics": payload["metrics"],
        "computed_at": _iso(_utc_now()),
    }
    supabase_client.table("predictions").upsert(row, on_conflict="fixture_id,model_version").execute()

def run_predictions_job(
    days_ahead: int = 2,
    past_limit_per_league: int = 1200,
    league_id: int | None = None,
) -> Dict[str, Any]:
    now = _utc_now()
    from_dt = now - timedelta(hours=1)
    to_dt = now + timedelta(days=days_ahead)

    fixtures = _fetch_upcoming_fixtures(from_dt, to_dt, league_id=league_id)

    by_league: Dict[int, List[Dict[str, Any]]] = {}
    for f in fixtures:
        by_league.setdefault(int(f["league_id"]), []).append(f)

    cal_binary, cal_ovr = _fetch_calibration()

    total = 0
    leagues = 0

    for lg_id, fx_list in by_league.items():
        leagues += 1
        past = _fetch_past_matches_for_league(lg_id, before_dt=now, limit=past_limit_per_league)
        league_avg = _league_avg_goals(past)
        league_scored = _league_scored_avg(past)

        for fx in fx_list:
            pred = compute_prediction_for_fixture(
                fixture=fx,
                past_matches=past,
                league_avg_goals=league_avg,
                league_scored_avg=league_scored,
                home_adv=1.10,
                cal_binary=cal_binary,
                cal_ovr=cal_ovr,
            )
            _upsert_prediction(int(fx["id"]), pred)
            total += 1

    return {
        "ok": True,
        "model_version": MODEL_VERSION,
        "fixtures_predicted": total,
        "leagues": leagues,
        "range": {"from": _iso(from_dt), "to": _iso(to_dt)},
        "league_id": league_id,
        "calibration_loaded": bool(cal_binary or cal_ovr),
    }
