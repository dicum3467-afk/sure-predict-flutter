from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.db import supabase_client
from app.core.cache import build_cache_key, cache_get, cache_set
from app.core.queue import queue
from app.jobs.predictions_job import run_predictions_job
from app.services.predictions_engine import MODEL_VERSION

router = APIRouter(prefix="/predictions", tags=["Predictions"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


def _iso(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


@router.get("/by-fixture/{fixture_id}")
def get_prediction_by_fixture(
    fixture_id: int,
    model_version: str = Query(MODEL_VERSION),
):
    key = build_cache_key("pred:fixture", {"fixture_id": fixture_id, "model_version": model_version})
    cached = cache_get(key)
    if cached:
        return cached

    res = (
        supabase_client.table("predictions")
        .select("fixture_id, model_version, computed_at, inputs, probs, picks, metrics")
        .eq("fixture_id", fixture_id)
        .eq("model_version", model_version)
        .limit(1)
        .execute()
        .data
    )

    if not res:
        return {"ok": True, "exists": False, "fixture_id": fixture_id, "model_version": model_version}

    out = {"ok": True, "exists": True, **res[0]}
    cache_set(key, out, ttl_seconds=20)
    return out


@router.get("/upcoming")
def list_upcoming_predictions(
    days_ahead: int = Query(2, ge=1, le=7),
    league_id: int | None = Query(None),
    model_version: str = Query(MODEL_VERSION),
):
    now = datetime.now(timezone.utc)
    to_dt = now + timedelta(days=days_ahead)

    key = build_cache_key(
        "pred:upcoming",
        {"days_ahead": days_ahead, "league_id": league_id, "model_version": model_version},
    )
    cached = cache_get(key)
    if cached:
        return cached

    # 1) upcoming fixtures
    q = (
        supabase_client.table("fixtures")
        .select("id, league_id, kickoff_at, home_team_id, away_team_id, status")
        .gte("kickoff_at", _iso(now - timedelta(hours=1)))
        .lte("kickoff_at", _iso(to_dt))
    )
    if league_id is not None:
        q = q.eq("league_id", league_id)

    fixtures = q.order("kickoff_at", desc=False).limit(800).execute().data or []
    fixture_ids = [f["id"] for f in fixtures]

    if not fixture_ids:
        out = {"ok": True, "count": 0, "items": []}
        cache_set(key, out, ttl_seconds=15)
        return out

    # 2) predictions for those fixtures
    preds = (
        supabase_client.table("predictions")
        .select("fixture_id, model_version, computed_at, picks, metrics")
        .in_("fixture_id", fixture_ids)
        .eq("model_version", model_version)
        .execute()
        .data
        or []
    )
    pred_by_fx = {p["fixture_id"]: p for p in preds}

    items = []
    for f in fixtures:
        p = pred_by_fx.get(f["id"])
        items.append({
            "fixture": f,
            "prediction": p,  # poate fi None dacă încă nu e calculată
        })

    out = {"ok": True, "count": len(items), "items": items, "model_version": model_version}
    cache_set(key, out, ttl_seconds=15)
    return out


@router.post("/admin-run")
def admin_run_predictions(
    days_ahead: int = Query(2, ge=1, le=7),
    league_id: int | None = Query(None),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not queue:
        raise HTTPException(status_code=500, detail="Queue not configured. Set REDIS_URL.")

    job = queue.enqueue(
        run_predictions_job,
        days_ahead=days_ahead,
        past_limit_per_league=700,
        league_id=league_id,
        result_ttl=3600,
        ttl=3600,
        job_timeout=900,
    )

    return {"ok": True, "job_id": job.id, "status_url": f"/jobs/{job.id}", "model_version": MODEL_VERSION}
