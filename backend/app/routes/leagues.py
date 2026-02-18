from fastapi import APIRouter
from app.db import get_conn

router = APIRouter()

@router.get("/leagues")
async def get_leagues():
    conn = await get_conn()
    rows = await conn.fetch("""
        select id, provider_league_id, name, country
        from public.leagues
        where is_active = true
        order by country, name
    """)
    return [dict(row) for row in rows]
