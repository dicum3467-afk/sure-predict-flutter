from fastapi import APIRouter
from app.db import get_conn

router = APIRouter(prefix="/leagues", tags=["leagues"])


@router.get("")
def get_leagues(active: bool = True):
    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()

        query = """
            SELECT id, provider_league_id, name, country, tier, is_active
            FROM leagues
        """
        params = []
        if active:
            query += " WHERE is_active = TRUE"
        query += " ORDER BY name ASC"

        cur.execute(query, params)
        rows = cur.fetchall()

        leagues = []
        for row in rows:
            leagues.append(
                {
                    "id": str(row[0]),
                    "provider_league_id": row[1],
                    "name": row[2],
                    "country": row[3],
                    "tier": row[4],
                    "is_active": row[5],
                }
            )

        cur.close()
        return leagues
    finally:
        if conn:
            conn.close()
