from fastapi import APIRouter, HTTPException
from typing import Optional

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
    Return fixtures for a league_id (UUID intern din tabela leagues),
    filtrate optional după date/status și run_type.
    """
    if not league_id:
        raise HTTPException(status_code=400, detail="league_id is required")

    conn = None
    try:
        conn = get_conn()
        cur = conn.cursor()

        where = ["league_id = %s", "run_type = %s"]
        params = [league_id, run_type]

        # date_from/date_to sunt string ISO (ex: "2026-02-24" sau "2026-02-24T00:00:00Z")
        if date_from:
            where.append("kickoff_at >= %s")
            params.append(date_from)

        if date_to:
            where.append("kickoff_at <= %s")
            params.append(date_to)

        if status:
            where.append("status = %s")
            params.append(status)

        q = f"""
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
            WHERE {" AND ".join(where)}
            ORDER BY kickoff_at ASC
            LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])

        cur.execute(q, params)
        rows = cur.fetchall()

        out = []
        for r in rows:
            out.append(
                {
                    "id": str(r[0]),
                    "provider_fixture_id": str(r[1]) if r[1] is not None else None,
                    "league_id": str(r[2]) if r[2] is not None else None,
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

        cur.close()
        return out
    finally:
        if conn:
            conn.close()
