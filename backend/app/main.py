from __future__ import annotations

import os
import traceback
from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# routers
from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

# init DB
from app.db_init import init_db

# optional predictions router (dacă există în proiect)
try:
    from app.routes.prediction import router as prediction_router  # type: ignore
except Exception:
    prediction_router = None


app = FastAPI(title="Sure Predict Backend")

# CORS (pentru test e ok; la producție restrângi origin-urile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# routes publice
app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# routes admin (sync din API-Football)
app.include_router(fixtures_sync_router)

# optional predictions
if prediction_router:
    app.include_router(prediction_router)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/admin/init-db")
def init_database(x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token")):
    """
    Creează tabelele în Postgres (o singură dată).
    Protejat cu SYNC_TOKEN din env (Render). Dacă SYNC_TOKEN nu e setat, endpoint-ul rămâne liber.
    """
    expected = os.getenv("SYNC_TOKEN")

    if expected:
        if not x_sync_token or x_sync_token.strip() != expected.strip():
            raise HTTPException(status_code=401, detail="Invalid SYNC token")

    try:
        init_db()
        return {"status": "ok", "message": "database initialized"}
    except Exception as e:
        # log complet în Render
        print("init_db failed:", repr(e))
        traceback.print_exc()

        # și mesaj în răspuns, ca să vezi cauza direct în ReqBin/Postman
        raise HTTPException(status_code=500, detail=str(e))
