from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.predictions import router as predictions_router

app = FastAPI(
    title="Sure Predict Backend",
    version=os.getenv("APP_VERSION", "1.0.0"),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
cors_origins = [o.strip() for o in cors_origins if o.strip()] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predictions_router)


@app.get("/", tags=["Meta"])
def root():
    return {
        "ok": True,
        "service": "sure-predict-backend",
        "version": app.version,
    }


@app.get("/health", tags=["Meta"])
def health():
    return {
        "ok": True,
        "status": "healthy",
    }
