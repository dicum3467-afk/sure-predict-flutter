from fastapi import APIRouter

# import routers
from .leagues import router as leagues_router
from .fixtures import router as fixtures_router
from .fixtures_by_league import router as fixtures_by_league_router
from .fixtures_sync import router as fixtures_sync_router
from .leagues_sync import router as leagues_sync_router
from .teams import router as teams_router
from .teams_sync import router as teams_sync_router
from .predictions import router as predictions_router
from .admin import router as admin_router
from .admin_hub import router as admin_hub_router

api_router = APIRouter()

# 🔹 public routes
api_router.include_router(leagues_router, tags=["Leagues"])
api_router.include_router(fixtures_router, tags=["Fixtures"])
api_router.include_router(fixtures_by_league_router, tags=["Fixtures by League"])
api_router.include_router(predictions_router, tags=["Predictions"])
api_router.include_router(teams_router, tags=["Teams"])

# 🔹 sync/admin routes
api_router.include_router(fixtures_sync_router, tags=["Sync Fixtures"])
api_router.include_router(leagues_sync_router, tags=["Sync Leagues"])
api_router.include_router(teams_sync_router, tags=["Sync Teams"])
api_router.include_router(admin_router, tags=["Admin"])
api_router.include_router(admin_hub_router, tags=["Admin Hub"])
