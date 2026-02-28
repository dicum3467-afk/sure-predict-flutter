from fastapi import APIRouter, Query
from app.db import get_conn

router = APIRouter(tags=["leagues"])


@router.get("/leagues")
def list_leagues():
    """
    Returnează ligile din DB.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    id,
                    provider_league_id,
                    name,
                    country,
                    tier,
                    is_active
                FROM leagues
                ORDER BY name
            """)
            return cur.fetchall()
    finally:
        conn.close()
