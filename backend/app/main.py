from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# importă router-ele direct (fără app.routes/__init__.py)
from app.routes.leagues import router as leagues_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

app = FastAPI(
    title="Sure Predict Backend",
    version="0.1.0",
)

# CORS (ca să meargă din Flutter / browser)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # după monetizare poți restrânge
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True}

# ROUTERS
app.include_router(leagues_router)            # /leagues/...
app.include_router(fixtures_by_league_router) # /fixtures/by-league ...
app.include_router(fixtures_sync_router)      # /fixtures/sync + /fixtures/sync-all
