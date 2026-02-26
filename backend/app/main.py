from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

# prediction router optional
try:
    from app.routes.prediction import router as prediction_router
except Exception:
    prediction_router = None

# DB init (auto create tables)
from app.db import engine, Base
from app.models import fixture  # IMPORTANT: incarcam modelul ca sa fie in metadata
Base.metadata.create_all(bind=engine)

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

if prediction_router:
    app.include_router(prediction_router)

@app.get("/health")
def health():
    return {"status": "ok"}
