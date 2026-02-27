from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os

from app.routes.leagues import router as leagues_router
from app.routes.fixtures_sync import router as fixtures_sync_router

# init DB (endpoint direct aici)
from app.db_init import init_db

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

# routes admin (sync din API-Football)
app.include_router(fixtures_sync_router)

@app.get("/health")
def health():
    return {"status": "ok"}

# Endpoint pentru a crea tabelele in Postgres
@app.post("/admin/init-db")
def init_database(x_sync_token: str | None = Header(None, alias="X-Sync-Token")):
    expected = os.getenv("SYNC_TOKEN")

    # daca ai setat SYNC_TOKEN in Render, il verificam aici
    if expected:
        if not x_sync_token or x_sync_token.strip() != expected.strip():
            raise HTTPException(status_code=401, detail="Invalid SYNC token")

    init_db()
    return {"status": "ok", "message": "database initialized"}
