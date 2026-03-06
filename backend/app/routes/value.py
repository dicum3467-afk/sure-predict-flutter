from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.db import supabase_client
from app.services.predictions_engine import MODEL_VERSION
from app.services.value_engine import build_value_rows

router = APIRouter(prefix="/value", tags=["Value Picks"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


def _get_prediction(fixture_id: int, model_version: str) -> Optional[Dict[str, Any]]:
    rows = (
        supabase_client.table("predictions")
        .select("fixture_id, model_version, probs, picks, metrics")
        .eq("fixture_id", fixture_id)
        .eq("model_version", model_version)
        .limit(1)
        .execute()
        .data
        or []
    )
    return rows[0] if rows else None


def _get_odds(fixture_id: int, bookmaker: str | None = None) -> List[Dict[str, Any]]:
    q = supabase_client.table("odds").select(
        "fixture_id, bookmaker, market, selection, odd"
    ).eq("fixture_id", fixture_id)

    if bookmaker:
        q = q.eq("bookmaker", bookmaker)

    return q.execute().data or []


@router.post("/admin-build/{fixture_id}")
def admin_build_value_for_fixture(
    fixture_id: int,
    bookmaker: str | None = Query(None),
    model_version: str = Query(MODEL_VERSION),
    min_edge: float = Query(0.03, ge=0.0, le=1.0),
    min_ev: float = Query(0.02, ge=0.0, le=10.0),
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    pred = _get_prediction(fixture_id, model_version)
    if not pred:
        raise HTTPException(status_code=404, detail="Prediction not found")

    odds_rows = _get_odds(fixture_id, bookmaker=bookmaker)
    if not odds_rows:
        return {"ok": True, "count": 0, "items": []}

    items = build_value_rows(
        fixture_id=fixture_id,
        model_version=model_version,
        prediction=pred,
        odds_rows=odds_rows,
        min_edge=min_edge,
        min_ev=min_ev,
    )

    if items:
        supabase_client.table("value_picks").upsert(
            items,
            on_conflict="fixture_id,model_version,bookmaker,market,selection",
        ).execute()

    return {"ok": True, "count": len(items), "items": items}


@router.get("/by-fixture/{fixture_id}")
def value_by_fixture(
    fixture_id: int,
    model_version: str = Query(MODEL_VERSION),
):
    items = (
        supabase_client.table("value_picks")
        .select(
            "fixture_id, model_version, bookmaker, market, selection, model_prob, fair_odd, book_odd, edge, expected_value, confidence, created_at"
        )
        .eq("fixture_id", fixture_id)
        .eq("model_version", model_version)
        .order("expected_value", desc=True)
        .execute()
        .data
        or []
    )
    return {"ok": True, "count": len(items), "items": items}


@router.get("/top")
def top_value_picks(
    days_ahead: int = Query(2, ge=1, le=7),
    min_ev: float = Query(0.03, ge=0.0, le=10.0),
    min_edge: float = Query(0.03, ge=0.0, le=1.0),
    limit: int = Query(50, ge=1, le=200),
    model_version: str = Query(MODEL_VERSION),
):
    # ia fixtures viitoare
    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)
    to_dt = now + timedelta(days=days_ahead)

    fixtures = (
        supabase_client.table("fixtures")
        .select("id")
        .gte("kickoff_at", now.isoformat())
        .lte("kickoff_at", to_dt.isoformat())
        .execute()
        .data
        or []
    )
    fixture_ids = [f["id"] for f in fixtures]
    if not fixture_ids:
        return {"ok": True, "count": 0, "items": []}

    items = (
        supabase_client.table("value_picks")
        .select(
            "fixture_id, model_version, bookmaker, market, selection, model_prob, fair_odd, book_odd, edge, expected_value, confidence, created_at"
        )
        .in_("fixture_id", fixture_ids)
        .eq("model_version", model_version)
        .gte("expected_value", min_ev)
        .gte("edge", min_edge)
        .order("expected_value", desc=True)
        .limit(limit)
        .execute()
        .data
        or []
    )
    return {"ok": True, "count": len(items), "items": items}
