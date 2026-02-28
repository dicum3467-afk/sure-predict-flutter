from __future__ import annotations

import os
from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor


@contextmanager
def get_conn():
    """
    Context manager pentru conexiune Postgres.

    ✔ ia DATABASE_URL din env
    ✔ commit automat la succes
    ✔ rollback la eroare
    ✔ închide conexiunea automat

    Folosire corectă:
        with get_conn() as conn:
            with conn.cursor() as cur:
                ...
    """
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL is missing")

    conn = psycopg2.connect(dsn)

    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def dict_cursor(conn):
    """Cursor care returnează dict-uri (JSON friendly)."""
    return conn.cursor(cursor_factory=RealDictCursor)
