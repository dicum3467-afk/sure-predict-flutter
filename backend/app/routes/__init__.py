from fastapi import APIRouter
from .fixtures import router as fixtures_router

api_router = APIRouter()

api_router.include_router(fixtures_router)
