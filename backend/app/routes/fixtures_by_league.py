from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, Query

from app.db import get_conn

router = APIRouter(tags=["fixtures"])


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    league_id: str = Query(..., description="UUID (din tabela leagues)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    run_type: Optional[str] = Query(None, description="initial/daily/manual etc (optional)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="Database not configured (missing DATABASE_URL).")

    where = ["league_id = %s"]
    params = [league_id]

    if date_from:
        where.append("fixture_date >= %s")
        params.append(date_from)
    if date_to:
        where.append("fixture_date <= %s")
        params.append(date_to)
    if status:
        where.append("status = %s")
        params.append(status)
    if run_type:
        where.append("run_type = %s")
        params.append(run_type)

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

        return [
            {
                "id": str(r[0]),
                "league_id": str(r[1]),
                "api_fixture_id": r[2],
                "home_team": r[3],
                "away_team": r[4],
                "fixture_date": (r[5].isoformat() if hasattr(r[5], "isoformat") else r[5]),
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
