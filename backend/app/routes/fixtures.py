from fastapi import APIRouter
from typing import Optional, List

from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


@router.get("")
def list_fixtures(
    league_ids: Optional[List[str]] = None,   # ?league_ids=uuid&league_ids=uuid
    status: Optional[str] = None,             # all/scheduled/live/finished (sau "All" din UI)
    date_from: Optional[str] = None,          # ISO
    date_to: Optional[str] = None,            # ISO
    run_type: str = "initial",
    limit: int = 50,
    offset: int = 0,
):
    # Normalize status (ca sa nu pice pe "All")
    if status is not None:
        s = status.strip().lower()
        if s in ("all", ""):
            status = None
        else:
            status = s

    conn = get_conn()
    cur = conn.cursor()

    where = ["f.run_type = %s"]
    params = [run_type]

    # league_ids optional
    if league_ids:
        where.append("f.league_id = ANY(%s)")
        params.append(league_ids)

    if date_from:
        where.append("f.kickoff_at >= %s")
        params.append(date_from)

    if date_to:
        where.append("f.kickoff_at <= %s")
        params.append(date_to)

    if status:
        where.append("f.status = %s")
        params.append(status)

    q = f"""
        SELECT
            f.id,
            f.provider_fixture_id,
            f.league_id,
            l.name AS league_name,
            f.kickoff_at,
            f.status,
            f.home,
            f.away,
            f.run_type,
            f.computed_at,
            f.p_home,
            f.p_draw,
            f.p_away,
            f.p_gg,
            f.p_over25,
            f.p_under25
        FROM fixtures f
        LEFT JOIN leagues l ON l.id = f.league_id
        WHERE {" AND ".join(where)}
        ORDER BY f.kickoff_at ASC
        LIMIT %s OFFSET %s
    """
    params.extend([limit, offset])

    cur.execute(q, params)
    rows = cur.fetchall()

    out = []
    for r in rows:
        out.append({
            "id": str(r[0]),
            "provider_fixture_id": r[1],
            "league_id": str(r[2]) if r[2] is not None else None,
            "league_name": r[3],
            "kickoff_at": r[4],
            "status": r[5],
            "home": r[6],
            "away": r[7],
            "run_type": r[8],
            "computed_at": r[9],
            "p_home": r[10],
            "p_draw": r[11],
            "p_away": r[12],
            "p_gg": r[13],
            "p_over25": r[14],
            "p_under25": r[15],
        })

    cur.close()
    conn.close()
    return out
