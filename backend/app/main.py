from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# public routes
from app.routes.leagues import router as leagues_router
from app.routes.fixtures import router as fixtures_router

# admin routes
from app.routes.admin import router as admin_router
from app.routes.fixtures_sync import router as fixtures_sync_router

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

# admin
app.include_router(admin_router)
app.include_router(fixtures_sync_router)


@app.get("/health")
def health():
    return {"status": "ok"}
