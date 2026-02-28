from typing import Optional, List, Dict, Any
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

# IMPORTANT - router trebuie definit
router = APIRouter(tags=["fixtures"])


@router.get("/fixtures")
def list_fixtures(
    league_id: Optional[int] = Query(None),          # api_league_id (ex: 39, 140 etc)
    date_from: Optional[str] = Query(None),          # ISO string (ex: 2026-02-01)
    date_to: Optional[str] = Query(None),            # ISO string
    status: Optional[str] = Query(None),             # optional
    include_recent_days: int = Query(0, ge=0, le=7), # ⭐ NOU: include ultimele X zile (0..7)
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    """
    Returnează meciuri din DB.
    - implicit: doar viitoare (fixture_date >= now)
    - dacă include_recent_days > 0: include și ultimele X zile
    - dacă trimiți date_from/date_to: se folosește intervalul tău
    """

    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Database not configured (missing DATABASE_URL).",
        )

    where = ["1=1"]
    params: List[Any] = []

    try:
        with conn:
            with conn.cursor() as cur:

                # ✅ convert API league_id -> UUID league_id
                if league_id is not None:
                    cur.execute(
                        "SELECT id FROM leagues WHERE api_league_id = %s LIMIT 1",
                        (league_id,),
                    )
                    row = cur.fetchone()
                    if not row:
                        raise HTTPException(
                            status_code=404,
                            detail=f"League {league_id} not found in DB",
                        )
                    league_uuid = row[0]

                    where.append("league_id = %s")
                    params.append(league_uuid)

                # ⭐ DEFAULT: doar viitoare (cu opțiune de ultimele X zile)
                # Dacă user NU a trimis date_from, setăm automat un prag.
                if date_from is None:
                    base_dt = datetime.now(timezone.utc)
                    if include_recent_days > 0:
                        base_dt = base_dt - timedelta(days=include_recent_days)
                    where.append("kickoff_at >= %s")
                    params.append(base_dt)
                else:
                    where.append("kickoff_at >= %s")
                    params.append(date_from)

                if date_to:
                    where.append("kickoff_at <= %s")
                    params.append(date_to)

                if status:
                    where.append("status = %s")
                    params.append(status)

                where_sql = " WHERE " + " AND ".join(where)

                cur.execute(
                    f"""
                    SELECT
                        id,
                        league_id,
                        provider_fixture_id,
                        season_id,
                        home_team_id,
                        away_team_id,
                        kickoff_at,
                        round,
                        status,
                        created_at
                    FROM fixtures
                    {where_sql}
                    ORDER BY kickoff_at ASC
                    LIMIT %s OFFSET %s
                    """,
                    (*params, limit, offset),
                )

                rows = cur.fetchall()

                # Return ca listă de dict-uri simple (FastAPI le serializează ok)
                result: List[Dict[str, Any]] = []
                for r in rows:
                    result.append(
                        {
                            "id": r[0],
                            "league_id": r[1],
                            "provider_fixture_id": r[2],
                            "season_id": r[3],
                            "home_team_id": r[4],
                            "away_team_id": r[5],
                            "kickoff_at": r[6],
                            "round": r[7],
                            "status": r[8],
                            "created_at": r[9],
                        }
                    )

                return result

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass
