from fastapi import APIRouter, HTTPException
from app.db import get_conn, dict_cursor

router = APIRouter(prefix="/leagues", tags=["leagues"])


@router.get("")
def list_leagues():
    """
    Returnează ligile din DB.
    """
    try:
        with get_conn() as conn:
            with dict_cursor(conn) as cur:
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
                    ORDER BY name ASC
                    """
                )
                rows = cur.fetchall()
                return rows
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        # ca să vezi exact în logs
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
