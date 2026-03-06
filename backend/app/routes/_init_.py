from fastapi import APIRouter

# Import routers
from .leagues import router as leagues_router
from .fixtures import router as fixtures_router
from .fixtures_by_league import router as fixtures_by_league_router
from .teams import router as teams_router
from .predictions import router as predictions_router

from .admin import router as admin_router
from .admin_hub import router as admin_hub_router

from .leagues_sync import router as leagues_sync_router
from .teams_sync import router as teams_sync_router
from .fixtures_sync import router as fixtures_sync_router

from .jobs import router as jobs_router
from .odds import router as odds_router
from .value import router as value_router
from .evaluation import router as evaluation_router


# Create main router
api_router = APIRouter()


# Public endpoints
api_router.include_router(leagues_router)
api_router.include_router(fixtures_router)
api_router.include_router(fixtures_by_league_router)
api_router.include_router(teams_router)
api_router.include_router(predictions_router)


# Betting / analytics
api_router.include_router(odds_router)
api_router.include_router(value_router)
api_router.include_router(evaluation_router)


# Admin
api_router.include_router(admin_router)
api_router.include_router(admin_hub_router)


# Sync / jobs
api_router.include_router(leagues_sync_router)
api_router.include_router(teams_sync_router)
api_router.include_router(fixtures_sync_router)
api_router.include_router(jobs_router)
