from fastapi import APIRouter

from .fixtures import router as fixtures_router
from .fixtures_by_league import router as fixtures_by_league_router
from .leagues import router as leagues_router
from .teams import router as teams_router
from .predictions import router as predictions_router

api_router = APIRouter()

api_router.include_router(fixtures_router)
api_router.include_router(fixtures_by_league_router)
api_router.include_router(leagues_router)
api_router.include_router(teams_router)
api_router.include_router(predictions_router)
