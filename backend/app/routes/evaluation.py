from __future__ import annotations

import os
from fastapi import APIRouter, Header, HTTPException, Query

from app.core.queue import queue
from app.db import supabase_client
from app.jobs.evaluation_job import run_evaluation_and_calibration_job
from app.services.predictions_engine import MODEL_VERSION

router = APIRouter(prefix="/evaluation", tags=["Evaluation"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


@router.post("/admin-run")
def admin_run_eval(
    days_back: int = Query(120, ge=30, le=365),
    min_samples: int = Query(120, ge=30, le=5000),
    league_id: int | None = Query(None),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not queue:
        raise HTTPException(status_code=500, detail="Queue not configured. Set REDIS_URL.")

    job = queue.enqueue(
        run_evaluation_and_calibration_job,
        days_back=days_back,
        min_samples=min_samples,
        league_id=league_id,
        result_ttl=6 * 3600,
        ttl=6 * 3600,
        job_timeout=1800,
    )
    return {"ok": True, "job_id": job.id, "status_url": f"/jobs/{job.id}", "model_version": MODEL_VERSION}


@router.get("/latest")
def latest_eval(model_version: str = Query(MODEL_VERSION)):
    res = (
        supabase_client.table("model_eval_runs")
        .select("id, model_version, created_at, range, sample, metrics")
        .eq("model_version", model_version)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
        .data
    )
    if not res:
        return {"ok": True, "exists": False, "model_version": model_version}
    return {"ok": True, "exists": True, "run": res[0]}


@router.get("/latest-leagues")
def latest_eval_leagues(model_version: str = Query(MODEL_VERSION)):
    run = (
        supabase_client.table("model_eval_runs")
        .select("id")
        .eq("model_version", model_version)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
        .data
    )
    if not run:
        return {"ok": True, "exists": False, "items": []}
    run_id = int(run[0]["id"])
    items = (
        supabase_client.table("model_eval_league")
        .select("league_id, metrics")
        .eq("run_id", run_id)
        .execute()
        .data
        or []
    )
    return {"ok": True, "exists": True, "run_id": run_id, "items": items}
