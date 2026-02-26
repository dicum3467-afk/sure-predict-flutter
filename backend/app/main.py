import os
from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

from app.db_init import init_db

# opțional (dacă există)
try:
    from app.routes.prediction import router as prediction_router  # type: ignore
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

# routes publice
app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# routes admin (sync)
app.include_router(fixtures_sync_router)

# optional predictions
if prediction_router:
    app.include_router(prediction_router)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.on_event("startup")
def on_startup():
    """
    Inițializează tabelele la pornire, doar dacă DATABASE_URL există.
    (Pe Render, variabila e setată -> tabelele se creează automat la deploy.)
    """
    if os.getenv("DATABASE_URL"):
        try:
            init_db()
        except Exception as e:
            # nu crăpăm aplicația dacă DB e temporar indisponibilă
            print(f"[startup] init_db failed: {e}")


@app.post("/admin/init-db")
def init_database(x_sync_token: Optional[str] = Header(None, alias="X-Sync-Token")):
    """
    Endpoint manual (fallback) pentru a crea tabelele.
    Protejat cu X-Sync-Token (SYNC_TOKEN din env).
    """
    expected = os.getenv("SYNC_TOKEN")
    if expected:
        if not x_sync_token or x_sync_token.strip() != expected.strip():
            raise HTTPException(status_code=401, detail="Invalid SYNC token")

    init_db()
    return {"status": "database initialized"}
