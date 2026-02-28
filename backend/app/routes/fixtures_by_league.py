from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def normalize_status(status: Optional[str]) -> Optional[str]:
    """Map API-Football statuses to DB statuses."""
    if not status:
        return status

    mapping = {
        "NS": "scheduled",
        "TBD": "scheduled",
        "FT": "finished",
        "AET": "finished",
        "PEN": "finished",
    }

    return mapping.get(status.upper(), status)


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    league_id: Optional[str] = Query(None, description="UUID din tabela leagues"),
    provider_league_id: Optional[int] = Query(None, description="ID liga API-Football"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT etc"),
    run_type: Optional[str] = Query(None, description="initial/daily/manual"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:

    # 🔴 VALIDARE
    if not league_id and not provider_league_id:
        raise HTTPException(
            status_code=422,
            detail="Trebuie league_id sau provider_league_id",
        )

    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Database not configured (missing DATABASE_URL).",
        )

    status = normalize_status(status)

    where = []
    params: List[Any] = []

    # ✅ filtrare liga
    if provider_league_id:
        where.append("l.provider_league_id = %s")
        params.append(provider_league_id)
    elif league_id:
        where.append("f.league_id = %s")
        params.append(league_id)

    # ✅ implicit doar meciuri viitoare
    if not date_from and not date_to:
        where.append("f.kickoff_at >= NOW()")

    if date_from:
        where.append("f.kickoff_at >= %s")
        params.append(date_from)

    if date_to:
        where.append("f.kickoff_at <= %s")
        params.append(date_to)

    if status:
        where.append("f.status = %s")
        params.append(status)

    if run_type:
        where.append("f.run_type = %s")
        params.append(run_type)

    where_sql = "WHERE " + " AND ".join(where) if where else ""

    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT
                        f.id,
                        f.league_id,
                        f.provider_fixture_id,
                        f.home_team,
                        f.away_team,
                        f.kickoff_at,
                        f.status,
                        f.home_goals,
                        f.away_goals,
                        f.run_type
                    FROM fixtures f
                    JOIN leagues l ON l.id = f.league_id
                    {where_sql}
                    ORDER BY f.kickoff_at ASC
                    LIMIT %s OFFSET %s
                    """,
                    (*params, limit, offset),
                )

                rows = cur.fetchall()

        return [
            {
                "id": str(r[0]),
                "league_id": str(r[1]),
                "provider_fixture_id": r[2],
                "home_team": r[3],
                "away_team": r[4],
                "kickoff_at": r[5].isoformat() if r[5] else None,
                "status": r[6],
                "home_goals": r[7],
                "away_goals": r[8],
                "run_type": r[9],
            }
            for r in rows
        ]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass
