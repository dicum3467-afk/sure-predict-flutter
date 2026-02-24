# backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Routers
from app.routes.leagues import router as leagues_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router


app = FastAPI(
    title="Sure Predict API",
    version="1.0.0",
)

# CORS (poți lăsa * pentru test; la producție pui domeniile tale)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check (warm-up / monitorizare)
@app.get("/health", tags=["health"])
def health():
    return {"ok": True}

# Include routes
app.include_router(leagues_router)            # /leagues
app.include_router(fixtures_by_league_router) # /fixtures/by-league
app.include_router(fixtures_sync_router)      # /fixtures/sync (și ce ai definit acolo)

# Optional root
@app.get("/", tags=["root"])
def root():
    return {"service": "sure-predict-backend", "docs": "/docs"}
