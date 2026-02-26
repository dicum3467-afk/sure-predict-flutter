from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_by_league import router as fixtures_by_league_router
from app.routes.fixtures_sync import router as fixtures_sync_router

# init DB (creare tabele)
from app.db_init import init_db

# dacă ai și prediction router separat, îl includem (dacă nu există, nu crapă)
try:
    from app.routes.prediction import router as prediction_router
except Exception:
    prediction_router = None

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

# routes admin (sync din API-Football)
app.include_router(fixtures_sync_router)

# opțional predictions
if prediction_router:
    app.include_router(prediction_router)


@app.get("/health")
def health():
    return {"status": "ok"}


# IMPORTANT:
# Endpoint temporar pentru a crea tabelele în Postgres.
# Rulează o singură dată din Swagger: POST /admin/init-db
# După ce a mers, recomand să-l ștergi sau să-l protejezi cu token.
@app.post("/admin/init-db")
def init_database(x_sync_token: str | None = Header(None, alias="X-Sync-Token")):
    expected = __import__("os").getenv("SYNC_TOKEN")

    # dacă ai setat SYNC_TOKEN în Render, îl cerem și aici (siguranță)
    if expected:
        if not x_sync_token or x_sync_token.strip() != expected.strip():
            raise HTTPException(status_code=401, detail="Invalid SYNC token")

    init_db()
    return {"status": "database initialized"}
