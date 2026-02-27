from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# routers
from app.routes.leagues import router as leagues_router
from app.routes.fixtures_sync import router as fixtures_sync_router
from app.routes.admin_init import router as admin_init_router

app = FastAPI(title="Sure Predict API")

# CORS (pentru Flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# health check
@app.get("/")
def root():
    return {"status": "ok"}

# include routers
app.include_router(leagues_router)
app.include_router(fixtures_sync_router)
app.include_router(admin_init_router)
