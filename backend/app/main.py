from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Rutele existente (din repo-ul tău)
from app.routes import leagues
from app.routes import fixtures_by_league

# Dacă ai deja aceste fișiere/rute în proiect, lasă-le active:
# - health.py (GET /health)
# - fixtures.py (GET /fixtures, GET /fixtures/{provider_fixture_id}/prediction)
# Dacă NU le ai cu aceste nume, comentează importurile și include_router corespunzătoare.
try:
    from app.routes import health
except Exception:
    health = None

try:
    from app.routes import fixtures
except Exception:
    fixtures = None

# Ruta nouă (pe care ai creat-o la PASUL 1): backend/app/routes/fixtures_sync.py
from app.routes import fixtures_sync


app = FastAPI(title="Sure Predict API")

# CORS (ca să meargă din Flutter, browser, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # în producție poți restrânge
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Include routers ----
if health is not None:
    app.include_router(health.router)

app.include_router(leagues.router)
app.include_router(fixtures_by_league.router)

if fixtures is not None:
    app.include_router(fixtures.router)

app.include_router(fixtures_sync.router)
