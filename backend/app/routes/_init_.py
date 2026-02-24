from .leagues import router as leagues_router
from .fixtures_by_league import router as fixtures_by_league_router
from .fixtures_sync import router as fixtures_sync_router

__all__ = [
    "leagues_router",
    "fixtures_by_league_router",
    "fixtures_sync_router",
]
