import os
from typing import Optional

import psycopg2
from psycopg2.extensions import connection as PGConnection


def get_db_url() -> Optional[str]:
    return os.getenv("DATABASE_URL")


def get_conn() -> PGConnection:
    db_url = get_db_url()
    if not db_url:
        raise RuntimeError("Missing DATABASE_URL env var")
    # pe Render, Postgres e de obicei cu SSL
    return psycopg2.connect(db_url, sslmode="require")
