from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.admin import router as admin_router
from app.routes.admin_hub import router as admin_hub_router
from app.routes.evaluation import router as evaluation_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router
from app.routes.job import router as job_router
from app.routes.leagues import router as leagues_router
from app.routes.leagues_sync import router as leagues_sync_router
from app.routes.odds import router as odds_router
from app.routes.predictions import router as predictions_router
from app.routes.team_stats import router as team_stats_router
from app.routes.teams import router as teams_router
from app.routes.teams_sync import router as teams_sync_router
from app.routes.value import router as value_router

app = FastAPI(
    title="Sure Predict Backend",
    version=os.getenv("APP_VERSION", "1.0.0"),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
cors_origins = [o.strip() for o in cors_origins if o.strip()] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin_router)
app.include_router(admin_hub_router)
app.include_router(evaluation_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)
app.include_router(fixtures_sync_router)
app.include_router(job_router)
app.include_router(leagues_router)
app.include_router(leagues_sync_router)
app.include_router(odds_router)
app.include_router(predictions_router)
app.include_router(team_stats_router)
app.include_router(teams_router)
app.include_router(teams_sync_router)
app.include_router(value_router)


@app.get("/", tags=["Meta"])
def root():
    return {
        "ok": True,
        "service": "sure-predict-backend",
        "version": app.version,
    }


@app.get("/health", tags=["Meta"])
def health():
    return {
        "ok": True,
        "status": "healthy",
    }
