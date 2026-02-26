from fastapi import APIRouter
from app.services.ingest_service import ingest_upcoming

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/sync")
async def manual_sync():
    await ingest_upcoming(days=7)
    return {"status": "ok"}
