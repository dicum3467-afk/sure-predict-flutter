from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import leagues_router, fixtures_by_league_router, fixtures_sync_router

app = FastAPI(
    title="Sure Predict Backend",
    version="0.1.0",
)

# CORS (ca să meargă și din Flutter / browser)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # poți restrânge după ce îl monetizezi
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True}

# --- ROUTERS ---
app.include_router(leagues_router)            # /leagues/...
app.include_router(fixtures_by_league_router) # /fixtures/by-league ...
app.include_router(fixtures_sync_router)      # /fixtures/sync-all + /fixtures/sync-league (dacă există)
