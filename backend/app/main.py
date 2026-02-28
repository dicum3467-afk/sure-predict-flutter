from __future__ import annotations

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# IMPORTANT: import rutele tale
from app.routes.fixtures import router as fixtures_router
from app.routes.fixtures_sync import router as fixtures_sync_router


def create_app() -> FastAPI:
    app = FastAPI(
        title="Sure Predict Backend",
        version=os.getenv("APP_VERSION", "1.0.0"),
    )

    # CORS (pentru Flutter / web / swagger)
    cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[o.strip() for o in cors_origins if o.strip()],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # include routers
    app.include_router(fixtures_router)
    app.include_router(fixtures_sync_router)

    @app.get("/health")
    def health():
        return {"ok": True}

    return app


app = create_app()
