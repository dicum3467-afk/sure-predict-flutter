from fastapi import APIRouter, HTTPException
from typing import Optional
from app.db import get_db
from app.services.api_football import fetch_fixtures_by_league

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


@router.post("/sync")
def sync_fixtures(
    league_id: str,
    season: int = 2024,
):
    """
    Fetch fixtures from provider and store in DB.
    league_id = internal uuid from leagues table
    """

    db = get_db()

    # 🔎 luăm liga internă
    cur = db.cursor()
    cur.execute(
        """
        SELECT id, provider_league_id, name
        FROM leagues
        WHERE id = %s
        """,
        (league_id,),
    )
    league = cur.fetchone()

    if not league:
        raise HTTPException(status_code=404, detail="League not found")

    provider_league_id = league["provider_league_id"]

    # 📡 luăm meciuri de la provider
    fixtures = fetch_fixtures_by_league(
        league_id=provider_league_id,
        season=season,
    )

    inserted = 0

    for fx in fixtures:
        cur.execute(
            """
            INSERT INTO fixtures (
                provider_fixture_id,
                league_id,
                kickoff_at,
                status,
                home,
                away,
                run_type,
                computed_at
            )
            VALUES (%s,%s,%s,%s,%s,%s,'initial',NOW())
            ON CONFLICT (provider_fixture_id)
            DO NOTHING
            """,
            (
                fx["fixture_id"],
                league_id,
                fx["kickoff_at"],
                fx["status"],
                fx["home"],
                fx["away"],
            ),
        )
        inserted += 1

    db.commit()

    return {
        "ok": True,
        "inserted": inserted,
        "league": league["name"],
  }
