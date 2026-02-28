# backend/app/db.py
import os
from contextlib import contextmanager
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

import psycopg2
from psycopg2.pool import SimpleConnectionPool


_POOL: SimpleConnectionPool | None = None


def _normalize_db_url(raw: str) -> str:
    """
    - accepta postgres:// sau postgresql://
    - adauga sslmode=require daca lipseste (Supabase)
    """
    if not raw:
        raise RuntimeError("DATABASE_URL is empty")

    url = raw.strip()

    # Render uneori are "postgres://", psycopg2 accepta dar e bine sa normalizam
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]

    p = urlparse(url)
    qs = parse_qs(p.query)

    # Force SSL for Supabase
    if "sslmode" not in qs:
        qs["sslmode"] = ["require"]

    new_query = urlencode(qs, doseq=True)
    return urlunparse((p.scheme, p.netloc, p.path, p.params, new_query, p.fragment))


def _get_pool() -> SimpleConnectionPool:
    global _POOL
    if _POOL is not None:
        return _POOL

    raw = os.getenv("DATABASE_URL", "")
    if not raw:
        raise RuntimeError("Database not configured (missing DATABASE_URL env var).")

    dsn = _normalize_db_url(raw)

    # Setari recomandate
    minconn = int(os.getenv("DB_POOL_MIN", "1"))
    maxconn = int(os.getenv("DB_POOL_MAX", "5"))

    connect_timeout = int(os.getenv("DB_CONNECT_TIMEOUT", "10"))  # sec
    statement_timeout_ms = int(os.getenv("DB_STATEMENT_TIMEOUT_MS", "15000"))  # ms

    _POOL = SimpleConnectionPool(
        minconn=minconn,
        maxconn=maxconn,
        dsn=dsn,
        connect_timeout=connect_timeout,
        options=f"-c statement_timeout={statement_timeout_ms}",
        application_name=os.getenv("APP_NAME", "sure-predict-backend"),
    )
    return _POOL


@contextmanager
def get_conn():
    """
    Folosire:
        from app.db import get_conn
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(...)
    """
    pool = _get_pool()
    conn = pool.getconn()
    try:
        conn.autocommit = True
        yield conn
    finally:
        pool.putconn(conn)


def close_pool() -> None:
    """Optional: cheama la shutdown daca vrei."""
    global _POOL
    if _POOL is not None:
        _POOL.closeall()
        _POOL = None
