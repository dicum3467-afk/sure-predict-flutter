import os
from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

from app.db_init import init_db

# optional (dacă există fișierul)
try:
    from app.routes.prediction import router as prediction_router
except Exception:
    prediction_router = None

app = FastAPI(title="Sure Predict Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# public routes
app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# admin routes (sync din API-Football)
app.include_router(fixtures_sync_router)

# optional predictions
if prediction_router:
    app.include_router(prediction_router)


@app.get("/health")
def health():
    return {"status": "ok"}


# IMPORTANT:
# Endpoint temporar pentru a crea tabelele în Postgres.
# Protejat cu token (SYNC_TOKEN) dacă îl setezi în Render.
@app.post("/admin/init-db")
def init_database(
    x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token"),
):
    expected = os.getenv("SYNC_TOKEN")
    if expected:
        if not x_sync_token or x_sync_token.strip() != expected.strip():
            raise HTTPException(status_code=401, detail="Invalid SYNC token")

    init_db()
    return {"status": "database initialized"}
