from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, Query
from app.db import get_conn

router = APIRouter(tags=["fixtures"])


def _normalize_status_filter(status: Optional[str]) -> Optional[str]:
    if not status:
        return None
    s = status.strip().lower()
    # accept both API-like and DB-like
    m = {
        "ns": "scheduled",
        "tbd": "scheduled",
        "ft": "finished",
        "aet": "finished",
        "pen": "finished",
        "live": "live",
    }
    return m.get(s, s)


@router.get("/fixtures/by-league")
def list_fixtures_by_league(
    provider_league_id: int = Query(..., description="ID liga API-Football (ex: 39, 61, 78)"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    date_to: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
    status: Optional[str] = Query(None, description="scheduled/finished/live/postponed etc"),
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    order: str = Query("asc", pattern="^(asc|desc)$"),
) -> Dict[str, Any]:
    """
    Return fixtures for a provider league id, paginated.
    If date_from/date_to not provided -> default upcoming only (kickoff_at >= NOW()).
    """
    try:
        conn = get_conn()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="Database not configured (missing DATABASE_URL).")

    status_norm = _normalize_status_filter(status)
    offset = (page - 1) * per_page

    where = ["l.provider_league_id = %s"]
    params: List[Any] = [provider_league_id]

    # default upcoming only
    if not date_from and not date_to:
        where.append("f.kickoff_at >= NOW()")

    if date_from:
        where.append("f.kickoff_at >= (%s::date)")
        params.append(date_from)

    if date_to:
        # include the whole day date_to
        where.append("f.kickoff_at < (%s::date + interval '1 day')")
        params.append(date_to)

    if status_norm:
        where.append("f.status = %s")
        params.append(status_norm)

    where_sql = " WHERE " + " AND ".join(where)

    try:
        with conn:
            with conn.cursor() as cur:
                # total count
                cur.execute(
                    f"""
                    SELECT COUNT(*)
                    FROM fixtures f
                    JOIN leagues l ON l.id = f.league_id
                    {where_sql}
                    """,
                    params,
                )
                total = int(cur.fetchone()[0] or 0)

                # page rows
                cur.execute(
                    f"""
                    SELECT
                        f.id,
                        f.league_id,
                        l.provider_league_id,
                        f.provider_fixture_id,
                        f.home_team,
                        f.away_team,
                        f.kickoff_at,
                        f.status,
                        f.home_goals,
                        f.away_goals,
                        f.season,
                        f.round,
                        f.run_type
                    FROM fixtures f
                    JOIN leagues l ON l.id = f.league_id
                    {where_sql}
                    ORDER BY f.kickoff_at {order.upper()}
                    LIMIT %s OFFSET %s
                    """,
                    (*params, per_page, offset),
                )
                rows = cur.fetchall()

        items = []
        for r in rows:
            items.append(
                {
                    "id": str(r[0]),
                    "league_id": str(r[1]),
                    "provider_league_id": r[2],
                    "provider_fixture_id": r[3],
                    "home_team": r[4],
                    "away_team": r[5],
                    "kickoff_at": r[6].isoformat() if hasattr(r[6], "isoformat") else r[6],
                    "status": r[7],
                    "home_goals": r[8],
                    "away_goals": r[9],
                    "season": r[10],
                    "round": r[11],
                    "run_type": r[12],
                }
            )

        return {
            "page": page,
            "per_page": per_page,
            "total": total,
            "items": items,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass
