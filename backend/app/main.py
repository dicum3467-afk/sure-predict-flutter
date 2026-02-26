from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router
from app.routes.admin import router as admin_router

app = FastAPI(title="Sure Predict Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)
app.include_router(fixtures_sync_router)
app.include_router(admin_router)

@app.get("/health")
def health():
    return {"status": "ok"}
