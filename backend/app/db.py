# backend/app/db.py
import os
from typing import Optional

import psycopg2
from psycopg2.extensions import connection as PGConnection

_DB_URL: Optional[str] = None

def get_db_url() -> Optional[str]:
    global _DB_URL
    if _DB_URL is None:
        _DB_URL = os.getenv("DATABASE_URL")
    return _DB_URL

def get_conn() -> PGConnection:
    db_url = get_db_url()
    if not db_url:
        raise RuntimeError("Missing DATABASE_URL env var")
    return psycopg2.connect(db_url, sslmode="require")
