from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, Query

from app.db import get_conn

router = APIRouter(tags=["leagues"])


@router.get("/leagues")
def get_leagues(active: Optional[bool] = Query(True, description="Return only active leagues")) -> List[Dict[str, Any]]:
    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="Database not configured (missing DATABASE_URL).")

    try:
        with conn:
            with conn.cursor() as cur:
                if active is None:
                    cur.execute(
                        """
                        SELECT id, api_league_id, name, country, active
                        FROM leagues
                        ORDER BY active DESC, name ASC
                        """
                    )
                else:
                    cur.execute(
                        """
                        SELECT id, api_league_id, name, country, active
                        FROM leagues
                        WHERE active = %s
                        ORDER BY name ASC
                        """,
                        (active,),
                    )

                rows = cur.fetchall()

        return [
            {
                "id": str(r[0]),
                "api_league_id": r[1],
                "name": r[2],
                "country": r[3],
                "active": r[4],
            }
            for r in rows
        ]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass
