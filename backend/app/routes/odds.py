from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.db import supabase_client

router = APIRouter(prefix="/odds", tags=["Odds"])

SYNC_TOKEN = os.getenv("SYNC_TOKEN", "surepredict123")


class OddIn(BaseModel):
    fixture_id: int
    bookmaker: str = Field(min_length=1)
    market: str = Field(min_length=1)
    selection: str = Field(min_length=1)
    odd: float = Field(gt=1.0)
    source: str = "manual"


class OddsBatchIn(BaseModel):
    items: List[OddIn]


@router.post("/admin-upsert")
def admin_upsert_odds(
    payload: OddsBatchIn,
    x_sync_token: str | None = Header(None, alias="X-Sync-Token"),
):
    if x_sync_token != SYNC_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    rows = [item.model_dump() for item in payload.items]
    if not rows:
        return {"ok": True, "inserted": 0}

    supabase_client.table("odds").upsert(
        rows,
        on_conflict="fixture_id,bookmaker,market,selection",
    ).execute()

    return {"ok": True, "upserted": len(rows)}


@router.get("/by-fixture/{fixture_id}")
def odds_by_fixture(
    fixture_id: int,
    bookmaker: Optional[str] = Query(None),
    market: Optional[str] = Query(None),
):
    q = supabase_client.table("odds").select(
        "fixture_id, bookmaker, market, selection, odd, source, updated_at"
    ).eq("fixture_id", fixture_id)

    if bookmaker:
        q = q.eq("bookmaker", bookmaker)
    if market:
        q = q.eq("market", market)

    data = q.execute().data or []
    return {"ok": True, "count": len(data), "items": data}
