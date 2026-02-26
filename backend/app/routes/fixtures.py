from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


@router.get("/fixtures")
def list_fixtures(
    league_id: Optional[str] = Query(None),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Database not configured (missing DATABASE_URL).",
        )

    where = ["1=1"]
    params = []

    if league_id:
        where.append("league_id = %s")
        params.append(league_id)

    if date_from:
        where.append("fixture_date >= %s")
        params.append(date_from)

    if date_to:
        where.append("fixture_date <= %s")
        params.append(date_to)

    if status:
        where.append("status = %s")
        params.append(status)

    where_sql = "WHERE " + " AND ".join(where)

    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT
                        id,
                        league_id,
                        api_fixture_id,
                        home_team,
                        away_team,
                        fixture_date,
                        status,
                        home_goals,
                        away_goals,
                        run_type
                    FROM fixtures
                    {where_sql}
                    ORDER BY fixture_date ASC
                    LIMIT %s OFFSET %s
                    """,
                    (*params, limit, offset),
                )
                rows = cur.fetchall()

        return rows

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass
