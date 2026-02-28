from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


@router.get("/by-league")
def fixtures_by_league(
    league: int = Query(...),
    season: int = Query(...)
):
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:

                # 1️⃣ luăm UUID-ul ligii din DB
                cur.execute(
                    """
                    SELECT id
                    FROM leagues
                    WHERE api_league_id = %s
                    LIMIT 1
                    """,
                    (league,),
                )
                row = cur.fetchone()

                if not row:
                    raise HTTPException(
                        status_code=404,
                        detail=f"League {league} not found"
                    )

                league_uuid = row["id"]

                # 2️⃣ luăm meciurile
                cur.execute(
                    """
                    SELECT
                        api_fixture_id,
                        fixture_date,
                        status_short,
                        home_team,
                        away_team,
                        home_goals,
                        away_goals
                    FROM fixtures
                    WHERE league_id = %s
                      AND season = %s
                    ORDER BY fixture_date ASC
                    LIMIT 200
                    """,
                    (league_uuid, season),
                )

                fixtures = cur.fetchall()

                return fixtures

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
