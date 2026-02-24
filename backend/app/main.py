from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# rute existente
from app.routes import leagues
from app.routes import fixtures
from app.routes import predictions

# ✅ ruta nouă
from app.routes import fixtures_by_league

app = FastAPI(title="Sure Predict Backend", version="0.1.0")

# CORS (pentru Flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# health check
@app.get("/health")
async def health():
    return {"status": "ok"}

# ✅ include routers
app.include_router(leagues.router)
app.include_router(fixtures.router)
app.include_router(predictions.router)
app.include_router(fixtures_by_league.router)
