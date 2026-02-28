from fastapi import APIRouter, Query
from app.db import get_conn

router = APIRouter(tags=["leagues"])

@router.get("/leagues")
def list_leagues(season: int | None = Query(None, description="ex: 2024")):
    """
    Returnează ligile din DB.
    NOTĂ: tabelul nu are last_season → ignorăm filtrul season.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    provider_league_id,
                    name,
                    country,
                    tier,
                    is_active
                FROM leagues
                ORDER BY country NULLS LAST, name
                """
            )
            return cur.fetchall()
    finally:
        conn.close()
