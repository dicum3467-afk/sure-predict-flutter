from __future__ import annotations

from fastapi import APIRouter, Query

router = APIRouter(prefix="/value", tags=["Value"])

MODEL_VERSION = "engine_pro_pp"


@router.get("")
def get_value(
    bankroll: float = Query(100.0, gt=0),
    min_confidence: float = Query(60.0, ge=0, le=100),
):
    return {
        "ok": True,
        "model_version": MODEL_VERSION,
        "bankroll": bankroll,
        "min_confidence": min_confidence,
        "items": [],
        "message": "Value endpoint fallback active",
    }


@router.get("/by-fixture/{fixture_id}")
def value_by_fixture(
    fixture_id: int,
    model_version: str = Query(MODEL_VERSION),
):
    return {
        "ok": True,
        "fixture_id": fixture_id,
        "model_version": model_version,
        "count": 0,
        "items": [],
        "message": "Value by fixture fallback active",
    }


@router.get("/top")
def top_value_picks(
    days_ahead: int = Query(2, ge=1, le=7),
    min_ev: float = Query(0.03, ge=0.0, le=10.0),
    min_edge: float = Query(0.03, ge=0.0, le=1.0),
    limit: int = Query(50, ge=1, le=200),
    model_version: str = Query(MODEL_VERSION),
):
    return {
        "ok": True,
        "days_ahead": days_ahead,
        "min_ev": min_ev,
        "min_edge": min_edge,
        "limit": limit,
        "model_version": model_version,
        "count": 0,
        "items": [],
        "message": "Top value picks fallback active",
    }
