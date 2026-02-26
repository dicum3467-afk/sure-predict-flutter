import os
import psycopg2
from psycopg2.extras import RealDictCursor

def get_conn():
    """
    Returnează o conexiune psycopg2 la Postgres folosind DATABASE_URL.
    Render: pune DATABASE_URL la Environment Variables (ai făcut deja).
    """
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("Missing DATABASE_URL env var")

    conn = psycopg2.connect(db_url, cursor_factory=RealDictCursor)
    conn.autocommit = True
    return conn
