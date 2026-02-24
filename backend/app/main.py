from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import leagues_router, fixtures_by_league_router, fixtures_sync_router

app = FastAPI(
    title="Sure Predict Backend",
    version="0.1.0",
)

# CORS (poți restrânge după ce monetizezi)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True}


# Routes
app.include_router(leagues_router)            # /leagues
app.include_router(fixtures_by_league_router) # /fixtures/by-league
app.include_router(fixtures_sync_router)      # /fixtures/sync, /fixtures/sync-all
