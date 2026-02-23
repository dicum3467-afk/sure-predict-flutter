from fastapi import APIRouter
from app.db import get_db_connection

router = APIRouter()


@router.get("/leagues")
def get_leagues(active: bool = True):
    conn = get_db_connection()
    cursor = conn.cursor()

    query = """
        SELECT id, provider_league_id, name, country, tier, is_active
        FROM leagues
    """

    if active:
        query += " WHERE is_active = TRUE"

    cursor.execute(query)
    rows = cursor.fetchall()

    leagues = []
    for row in rows:
        leagues.append(
            {
                "id": str(row[0]),
                "provider_league_id": row[1],  # 🔥 IMPORTANT
                "name": row[2],
                "country": row[3],
                "tier": row[4],
                "is_active": row[5],
            }
        )

    cursor.close()
    conn.close()

    return leagues
