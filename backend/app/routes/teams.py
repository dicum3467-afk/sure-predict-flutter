from fastapi import APIRouter, Query, HTTPException
from app.db import get_conn

router = APIRouter(tags=["teams"])

@router.get("/teams")
def list_teams(
    league: int = Query(..., description="API-Football league id (ex: 39)"),
    season: int = Query(..., description="ex: 2024"),
):
    """
    Echipe din DB pe liga+sezon.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT t.team_id, t.name, t.code, t.country, t.founded, t.national, t.logo
                FROM league_teams lt
                JOIN teams t ON t.team_id = lt.team_id
                WHERE lt.league_id = %s AND lt.season = %s
                ORDER BY t.name
                """,
                (league, season),
            )
            rows = cur.fetchall()
            if rows is None:
                return []
            return rows
    finally:
        conn.close()
