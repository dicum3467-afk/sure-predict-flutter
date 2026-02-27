from fastapi import APIRouter

# routerul tău existent cu /db/init
from app.routes.admin import router as admin_init_router

# routerul de sync fixtures cu /sync/fixtures
from app.routes.fixtures_sync import router as fixtures_sync_router

# Dacă ai și alte sync-uri, le vei include la fel:
# from app.routes.leagues_sync import router as leagues_sync_router
# from app.routes.teams_sync import router as teams_sync_router

router = APIRouter(prefix="/admin", tags=["admin"])

# IMPORTANT:
# routerele copil NU trebuie să aibă prefix="/admin" (dar la tine AU deja).
# Ca să nu ajungi la /admin/admin/..., “de-prefixăm” corect mai jos.

def _strip_admin_prefix(child: APIRouter) -> APIRouter:
    """
    Dacă un router copil are deja prefix '/admin', îl eliminăm,
    ca să fie inclus corect sub /admin din hub.
    """
    if getattr(child, "prefix", "") == "/admin":
        child.prefix = ""
    return child

router.include_router(_strip_admin_prefix(admin_init_router))
router.include_router(_strip_admin_prefix(fixtures_sync_router))

# router.include_router(_strip_admin_prefix(leagues_sync_router))
# router.include_router(_strip_admin_prefix(teams_sync_router))
