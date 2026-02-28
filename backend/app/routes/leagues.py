from fastapi import APIRouter, Query, HTTPException
from app.db import get_conn

router = APIRouter(tags=["leagues"])


@router.get("/leagues")
def list_leagues(season: int | None = Query(None, description="ex: 2024")):
    """
    Returnează ligile din DB (nu din API).
    Dacă dai season, filtrează după last_season.
    """

    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Database not configured (missing DATABASE_URL)."
        )

    try:
        with conn.cursor() as cur:
            if season:
                cur.execute(
                    """
                    SELECT id, name, country, tier, is_active
                    FROM leagues
                    WHERE last_season = %s
                    ORDER BY country NULLS LAST, name
                    """,
                    (season,),
                )
            else:
                cur.execute(
                    """
                    SELECT id, name, country, tier, is_active
                    FROM leagues
                    ORDER BY country NULLS LAST, name
                    """
                )

            rows = cur.fetchall()
            return rows

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")

    finally:
        try:
            conn.close()
        except Exception:
            pass
