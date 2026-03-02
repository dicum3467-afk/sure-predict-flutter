# backend/app/main.py
from __future__ import annotations

import os
import time
import logging
from typing import Optional

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from starlette.middleware.trustedhost import TrustedHostMiddleware

# Routers (importă-le DOAR pe cele pe care le ai în proiect)
from app.routes import fixtures_sync

logger = logging.getLogger("sure_predict")
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)

APP_NAME = os.getenv("APP_NAME", "Sure Predict Backend")
ENV = os.getenv("ENV", "production")

# CORS
# În producție, pune domeniile tale reale în env: CORS_ORIGINS="https://app.com,https://www.app.com"
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")
ALLOW_ALL = CORS_ORIGINS.strip() == "*"
origins = ["*"] if ALLOW_ALL else [o.strip() for o in CORS_ORIGINS.split(",") if o.strip()]

# Trusted hosts (opțional, dar recomandat)
# În Render, dacă nu știi hosturile, lasă "*"
TRUSTED_HOSTS = os.getenv("TRUSTED_HOSTS", "*")
trusted_hosts = ["*"] if TRUSTED_HOSTS.strip() == "*" else [h.strip() for h in TRUSTED_HOSTS.split(",") if h.strip()]

# -----------------------------------------------------------------------------
# APP
# -----------------------------------------------------------------------------
app = FastAPI(
    title=APP_NAME,
    version=os.getenv("APP_VERSION", "1.0.0"),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# -----------------------------------------------------------------------------
# MIDDLEWARE
# -----------------------------------------------------------------------------
# TrustedHost: previne Host-header attacks (safe default)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=trusted_hosts)

# CORS: pentru Flutter/web sau orice client
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=not ALLOW_ALL,  # dacă ai "*", nu ai voie credentials
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple request timing middleware
@app.middleware("http")
async def add_timing_header(request: Request, call_next):
    start = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception as e:
        logger.exception("Unhandled exception")
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": "Internal Server Error", "detail": str(e)},
        )
    took_ms = (time.perf_counter() - start) * 1000.0
    response.headers["X-Response-Time-ms"] = f"{took_ms:.2f}"
    return response


# -----------------------------------------------------------------------------
# ROUTERS
# -----------------------------------------------------------------------------
# Fixtures + admin sync
app.include_router(fixtures_sync.router)

# (Aici mai adaugi ulterior: leagues, predictions, odds etc.)
# from app.routes import leagues, predictions
# app.include_router(leagues.router)
# app.include_router(predictions.router)


# -----------------------------------------------------------------------------
# HEALTH + ROOT
# -----------------------------------------------------------------------------
@app.get("/", response_class=PlainTextResponse)
def root():
    return "Sure Predict Backend is running."

@app.get("/health")
def health():
    return {
        "ok": True,
        "name": APP_NAME,
        "env": ENV,
    }


# -----------------------------------------------------------------------------
# GLOBAL ERROR HANDLERS (PRO++)
# -----------------------------------------------------------------------------
@app.exception_handler(404)
async def not_found_handler(_: Request, __):
    return JSONResponse(status_code=404, content={"ok": False, "error": "Not Found"})

@app.exception_handler(405)
async def method_not_allowed_handler(_: Request, __):
    return JSONResponse(status_code=405, content={"ok": False, "error": "Method Not Allowed"})

@app.exception_handler(Exception)
async def global_exception_handler(_: Request, exc: Exception):
    logger.exception("Global exception handler caught an error")
    return JSONResponse(
        status_code=500,
        content={"ok": False, "error": "Internal Server Error", "detail": str(exc)},
    )
