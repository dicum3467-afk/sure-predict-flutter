from fastapi import APIRouter, Query, HTTPException
from app.db import get_conn

router = APIRouter(tags=["leagues"])

@router.get("/leagues")
def list_leagues(season: int | None = Query(None)):
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
                    is_active,
                    created_at
                FROM leagues
                ORDER BY country NULLS LAST, name
                """
            )
            rows = cur.fetchall()
            return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
