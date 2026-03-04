from __future__ import annotations

import os
from fastapi import APIRouter, HTTPException

from rq.job import Job

from app.core.queue import redis_conn

router = APIRouter(prefix="/jobs", tags=["Jobs"])

@router.get("/{job_id}")
def job_status(job_id: str):
    if not redis_conn:
        raise HTTPException(status_code=500, detail="Redis not configured (REDIS_URL missing).")
    try:
        job = Job.fetch(job_id, connection=redis_conn)
    except Exception:
        raise HTTPException(status_code=404, detail="Job not found")

    return {
        "ok": True,
        "job_id": job.id,
        "status": job.get_status(),  # queued/started/finished/failed
        "enqueued_at": str(job.enqueued_at) if job.enqueued_at else None,
        "started_at": str(job.started_at) if job.started_at else None,
        "ended_at": str(job.ended_at) if job.ended_at else None,
        "result": job.result if job.is_finished else None,
        "error": job.exc_info if job.is_failed else None,
    }
