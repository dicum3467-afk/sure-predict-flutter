from fastapi import APIRouter, HTTPException
from typing import Optional, List

from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


@router.get("/by-league")
def list_fixtures_by_league(
    league_id: str,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    status: Optional[str] = None,
    run_type: str = "initial",
    limit: int = 50,
    offset: int = 0,
):
    """
    Return fixtures for a league_id (our internal uuid from /leagues),
    filtered by optional date range/status, and run_type.
    """

    db = get_db()

    q = """
    SELECT
      id,
      provider_fixture_id,
      league_id,
      kickoff_at,
      status,
      home,
      away,
      run_type,
      computed_at,
      p_home,
      p_draw,
      p_away,
      p_gg,
      p_over25,
      p_under25
    FROM fixtures
    WHERE league_id = ?
      AND run_type = ?
    """

    params: List[object] = [league_id, run_type]

    if status:
        q += " AND status = ?"
        params.append(status)

    if date_from:
        q += " AND kickoff_at >= ?"
        params.append(date_from)

    if date_to:
        q += " AND kickoff_at <= ?"
        params.append(date_to)

    q += " ORDER BY kickoff_at ASC LIMIT ? OFFSET ?"
    params.extend([limit, offset])

    try:
        rows = db.execute(q, params).fetchall()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # sqlite row -> dict
    res = []
    for r in rows:
        res.append(
            {
                "id": r[0],
                "provider_fixture_id": r[1],
                "league_id": r[2],
                "kickoff_at": r[3],
                "status": r[4],
                "home": r[5],
                "away": r[6],
                "run_type": r[7],
                "computed_at": r[8],
                "p_home": r[9],
                "p_draw": r[10],
                "p_away": r[11],
                "p_gg": r[12],
                "p_over25": r[13],
                "p_under25": r[14],
            }
        )

    return res
