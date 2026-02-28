from fastapi import APIRouter, Query
from app.db import get_conn

router = APIRouter(tags=["leagues"])

@router.get("/leagues")
def list_leagues(season: int | None = Query(None, description="ex: 2024")):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Dacă ai coloană last_season, păstrează filtrarea.
            # Dacă NU ai last_season, scoate IF-ul și rulează doar SELECT-ul simplu.
            if season:
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
                    WHERE last_season = %s
                    ORDER BY country NULLS LAST, name
                    """,
                    (season,),
                )
            else:
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
