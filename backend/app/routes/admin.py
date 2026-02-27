import os
from typing import Optional
from fastapi import APIRouter, Header, HTTPException

from app.db_init import init_db

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_token(x_sync_token: Optional[str]) -> None:
    expected = os.getenv("SYNC_TOKEN")
    if not expected:
        raise HTTPException(status_code=500, detail="SYNC_TOKEN not set in environment.")
    if not x_sync_token or x_sync_token.strip() != expected.strip():
        raise HTTPException(status_code=401, detail="Invalid SYNC token")


@router.post("/db/init")
def db_init(x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token")):
    _check_token(x_sync_token)
    init_db()
    return {"status": "ok", "message": "db initialized"}
