from fastapi import APIRouter

from .fixtures import router as fixtures_router
from .predictions import router as predictions_router
from .team_stats import router as team_stats_router

api_router = APIRouter()

api_router.include_router(fixtures_router)
api_router.include_router(predictions_router)
api_router.include_router(team_stats_router)
