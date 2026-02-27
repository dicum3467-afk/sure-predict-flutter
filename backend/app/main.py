import os
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router

# admin routes (init-db / sync etc) -> din app/routes/admin.py
from app.routes.admin import router as admin_router

app = FastAPI(title="Sure Predict Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# routes publice
app.include_router(leagues_router)
app.include_router(fixtures_router)
app.include_router(fixtures_by_league_router)

# routes admin
app.include_router(admin_router)

@app.get("/health")
def health():
    return {"status": "ok"}
