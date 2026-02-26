from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db_init import init_db

from app.routes.leagues import router as leagues_router
from app.routes.teams import router as teams_router

from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

from app.routes.leagues_sync import router as leagues_sync_router
from app.routes.teams_sync import router as teams_sync_router

app = FastAPI(title="Sure Predict Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def _startup():
    init_db()

# PUBLIC
app.include_router(leagues_router)
app.include_router(teams_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# ADMIN (sync)
app.include_router(fixtures_sync_router)
app.include_router(leagues_sync_router)
app.include_router(teams_sync_router)

@app.get("/health")
def health():
    return {"status": "ok"}
