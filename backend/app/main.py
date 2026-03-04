from __future__ import annotations

import os
import time
import uuid
import logging
from typing import Optional, Dict, Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse

from app.routes import api_router


# ---------------------------
# Logging (PRO+++)
# ---------------------------
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger("sure_predict_backend")


# ---------------------------
# Simple in-memory rate limit (PRO+++)
# (Bun pentru Render free / single instance; pentru multi-instance -> Redis)
# ---------------------------
RATE_LIMIT_PER_MIN = int(os.getenv("RATE_LIMIT_PER_MIN", "240"))  # per IP
_rate_bucket: Dict[str, Dict[str, Any]] = {}  # ip -> {window, count}


def _rate_limit_allow(ip: str) -> bool:
    now = int(time.time())
    window = now // 60  # minute window
    rec = _rate_bucket.get(ip)
    if not rec or rec["window"] != window:
        _rate_bucket[ip] = {"window": window, "count": 1}
        return True
    if rec["count"] >= RATE_LIMIT_PER_MIN:
        return False
    rec["count"] += 1
    return True


# ---------------------------
# Optional Redis cache (PRO+++)
# If REDIS_URL exists, you can use it later in routes for caching.
# Here we only "detect" availability safely.
# ---------------------------
REDIS_URL = os.getenv("REDIS_URL", "").strip()
redis_ok = False
redis_client = None

if REDIS_URL:
    try:
        import redis  # type: ignore

        redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2)
        redis_client.ping()
        redis_ok = True
        logger.info("Redis: connected ✅")
    except Exception as e:
        redis_ok = False
        redis_client = None
        logger.warning(f"Redis: not available (will run without) ⚠️  err={e}")


# ---------------------------
# App (PRO+++)
# ---------------------------
app = FastAPI(
    title="Sure Predict Backend",
    version=os.getenv("APP_VERSION", "1.0.0"),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# GZip for faster responses
app.add_middleware(GZipMiddleware, minimum_size=800)

# CORS
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
cors_origins = [o.strip() for o in cors_origins if o.strip()] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
# Poți seta prefix "/api" dacă vrei: app.include_router(api_router, prefix="/api")
app.include_router(api_router)


# ---------------------------
# Middleware: request-id + timing + rate limit (PRO+++)
# ---------------------------
@app.middleware("http")
async def request_middleware(request: Request, call_next):
    req_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    start = time.time()

    # Rate limit (skip docs/openapi)
    path = request.url.path
    if not (path.startswith("/docs") or path.startswith("/openapi") or path.startswith("/redoc")):
        ip = request.client.host if request.client else "unknown"
        if not _rate_limit_allow(ip):
            return JSONResponse(
                status_code=429,
                content={"ok": False, "detail": "Rate limit exceeded. Try again later.", "request_id": req_id},
                headers={"x-request-id": req_id},
            )

    response = await call_next(request)

    ms = int((time.time() - start) * 1000)
    response.headers["x-request-id"] = req_id
    response.headers["x-response-ms"] = str(ms)

    # Log compact
    logger.info(f"{request.method} {request.url.path} -> {response.status_code} ({ms}ms) rid={req_id}")
    return response


# ---------------------------
# Error handlers (PRO+++)
# ---------------------------
@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    req_id = request.headers.get("x-request-id") or "n/a"
    logger.exception(f"Unhandled error rid={req_id} path={request.url.path} err={exc}")
    return JSONResponse(
        status_code=500,
        content={"ok": False, "detail": "Internal Server Error", "request_id": req_id},
    )


# ---------------------------
# Health / Meta (PRO+++)
# ---------------------------
@app.get("/", tags=["Meta"])
def root():
    return {
        "ok": True,
        "service": "sure-predict-backend",
        "version": app.version,
        "redis": bool(redis_ok),
    }


@app.get("/health", tags=["Meta"])
def health():
    # Render / load balancer check
    return {"ok": True, "ts": int(time.time()), "redis": bool(redis_ok)}


@app.get("/meta", tags=["Meta"])
def meta():
    return {
        "ok": True,
        "env": os.getenv("ENV", "production"),
        "rate_limit_per_min": RATE_LIMIT_PER_MIN,
        "cors_origins": cors_origins,
        "redis_enabled": bool(REDIS_URL),
        "redis_ok": bool(redis_ok),
    }


# ---------------------------
# Startup checks (PRO+++)
# ---------------------------
@app.on_event("startup")
def on_startup():
    logger.info("Startup: Sure Predict Backend 🚀")
    # aici poți adăuga ulterior verificări DB (supabase) / migrații etc.
