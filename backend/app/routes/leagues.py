from fastapi import APIRouter, Query
from app.db import get_conn

router = APIRouter(tags=["leagues"])

@router.get("/leagues")
def list_leagues(season: int | None = Query(None, description="ex: 2024")):
    """
    Returnează ligile din DB (nu din API).
    Dacă dai season, filtrează după last_season = season (simplu).
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if season:
                cur.execute(
                    """
                    SELECT league_id, name, type, country, logo, flag, last_season
                    FROM leagues
                    WHERE last_season = %s
                    ORDER BY country NULLS LAST, name
                    """,
                    (season,),
                )
            else:
                cur.execute(
                    """
                    SELECT league_id, name, type, country, logo, flag, last_season
                    FROM leagues
                    ORDER BY country NULLS LAST, name
                    """
                )
            return cur.fetchall()
    finally:
        conn.close()
