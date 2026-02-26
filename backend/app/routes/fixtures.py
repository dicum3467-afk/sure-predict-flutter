from fastapi import APIRouter
from typing import Optional, List

from app.db import get_conn

router = APIRouter(prefix="/fixtures", tags=["fixtures"])


@router.get("")
def list_fixtures(
    league_ids: Optional[List[str]] = None,  # ?league_ids=uuid&league_ids=uuid
    status: Optional[str] = None,            # all/scheduled/live/finished
    date_from: Optional[str] = None,         # ISO string
    date_to: Optional[str] = None,           # ISO string
    run_type: str = "initial",
    limit: int = 50,
    offset: int = 0,
):
    # normalizare status (ca să nu pice pe "All")
    if status:
        s = status.strip().lower()
        if s == "all":
            status = None
        else:
            status = s

    conn = get_conn()
    cur = conn.cursor()

    where = ["run_type = %s"]
    params = [run_type]

    # filtrare după league_ids (uuid-urile interne din tabela leagues)
    if league_ids:
        where.append("league_id = ANY(%s)")
        params.append(league_ids)

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
        out.append({
            "id": str(r[0]),
            "provider_fixture_id": r[1],
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
        })

    cur.close()
    conn.close()
    return out
