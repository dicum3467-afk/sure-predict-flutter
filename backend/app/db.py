import os
import psycopg2


def get_conn():
    """
    Returnează o conexiune psycopg2 folosind DATABASE_URL din env.
    Render pune de obicei DATABASE_URL automat dacă ai Postgres atașat.
    """
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("Missing DATABASE_URL env var")

    # Render uneori dă postgres://; psycopg2 preferă postgresql://
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)

    return psycopg2.connect(db_url)
