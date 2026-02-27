from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router

# HUB ADMIN (include init + sync fixtures)
from app.routes.admin_hub import router as admin_hub_router

app = FastAPI(title="Sure Predict Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# public
app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# admin (tot într-un singur loc)
app.include_router(admin_hub_router)

@app.get("/health")
def health():
    return {"status": "ok"}
