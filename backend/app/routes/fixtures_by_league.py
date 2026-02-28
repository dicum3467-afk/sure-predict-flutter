from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

router = APIRouter(tags=["fixtures"])


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    # Acceptă ORI UUID (din tabela leagues), ORI provider_league_id (API-Football)
    league_id: Optional[str] = Query(None, description="UUID din tabela leagues (ex: 971b...)"),
    provider_league_id: Optional[int] = Query(None, description="API-Football league id (ex: 78)"),

    date_from: Optional[str] = Query(None, description="YYYY-MM-DD"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD"),
    status: Optional[str] = Query(None, description="NS/FT/1H/HT/2H etc"),
    run_type: Optional[str] = Query(None, description="initial/daily/manual etc (optional)"),

    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> List[Dict[str, Any]]:
    if league_id is None and provider_league_id is None:
        raise HTTPException(status_code=422, detail="Provide either league_id (UUID) or provider_league_id (int).")

    # IMPORTANT: dacă get_conn este contextmanager, trebuie folosit cu `with`
    try:
        with get_conn() as conn:
            where = []
            params = []

            # Filtrare pe liga:
            # - dacă avem UUID => fixtures.league_id = uuid
            # - dacă avem provider_league_id => join cu leagues și filtrăm pe leagues.provider_league_id
            join_sql = ""
            if league_id is not None:
                where.append("f.league_id = %s")
                params.append(league_id)
            else:
                join_sql = "JOIN leagues l ON l.id = f.league_id"
                where.append("l.provider_league_id = %s")
                params.append(provider_league_id)

            # Date range pe kickoff_at (coloana ta din Supabase)
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

            sql = f"""
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
                {join_sql}
                {where_sql}
                ORDER BY f.kickoff_at ASC
                LIMIT %s OFFSET %s
            """

            with conn.cursor() as cur:
                cur.execute(sql, (*params, limit, offset))
                rows = cur.fetchall()

            return [
                {
                    "id": str(r[0]),
                    "league_id": str(r[1]),
                    "provider_fixture_id": r[2],
                    "home_team": r[3],
                    "away_team": r[4],
                    "kickoff_at": r[5].isoformat() if hasattr(r[5], "isoformat") else r[5],
                    "status": r[6],
                    "home_goals": r[7],
                    "away_goals": r[8],
                    "run_type": r[9],
                }
                for r in rows
            ]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
