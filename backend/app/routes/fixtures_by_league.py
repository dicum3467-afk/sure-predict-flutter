from fastapi import APIRouter, HTTPException, Query
from app.services.api_football import fetch_fixtures_by_league

router = APIRouter()


@router.get("/fixtures/by-league")
async def fixtures_by_league(
    provider_league_id: str = Query(..., description="Ex: api_39"),
    season: int = Query(2024, description="Ex: 2024"),
):
    # provider_league_id vine ca "api_39" -> API-Football vrea "39"
    if not provider_league_id.startswith("api_"):
        raise HTTPException(status_code=400, detail="provider_league_id must look like api_39")

    league_num = provider_league_id.replace("api_", "").strip()
    if not league_num.isdigit():
        raise HTTPException(status_code=400, detail="Invalid provider_league_id")

    try:
        data = await fetch_fixtures_by_league(league_num, season=season)
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
