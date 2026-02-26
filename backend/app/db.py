import os
import psycopg2
from psycopg2.extras import RealDictCursor


def get_db_url() -> str:
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("Missing DATABASE_URL env var")
    return db_url


def get_conn():
    """
    Returnează o conexiune psycopg2 la Postgres (Render).
    """
    return psycopg2.connect(
        get_db_url(),
        connect_timeout=10,
        cursor_factory=RealDictCursor,
    )
