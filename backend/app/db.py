from __future__ import annotations

import os
from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor


@contextmanager
def get_conn():
    """
    Context manager pt conexiune Postgres.
    - ia DATABASE_URL din env
    - face commit la succes, rollback la eroare
    - inchide conexiunea automat
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
