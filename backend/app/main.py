from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# import corect pe fișiere
from app.routes.leagues import router as leagues_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

app = FastAPI(title="Sure Predict Backend")

# CORS (pentru Flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# include routers
app.include_router(leagues_router)
app.include_router(fixtures_by_league_router)
app.include_router(fixtures_sync_router)


@app.get("/health")
def health():
    return {"status": "ok"}
