from __future__ import annotations

import os
from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor


@contextmanager
def get_conn():
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
    return conn.cursor(cursor_factory=RealDictCursor)
