from __future__ import annotations

from typing import Any, Dict, List
from fastapi import APIRouter
from app.db import get_conn

router = APIRouter(tags=["team-stats"])


@router.get("/team-stats")
def list_team_stats(limit: int = 100) -> Dict[str, Any]:
    sql = """
        SELECT
            ts.id,
            ts.team_id,
            t.name as team_name,
            ts.league_id,
            l.name as league_name,
            ts.season_id,
            ts.matches_played,
            ts.wins,
            ts.draws,
            ts.losses,
            ts.goals_for,
            ts.goals_against,
            ts.btts_hits,
            ts.over25_hits,
            ts.clean_sheets,
            ts.failed_to_score,
            ts.form_last5_points,
            ts.form_last5_wins,
            ts.form_last5_draws,
            ts.form_last5_losses,
            ts.form_last5_goals_for,
            ts.form_last5_goals_against
        FROM team_stats ts
        JOIN teams t ON t.id = ts.team_id
        JOIN leagues l ON l.id = ts.league_id
        ORDER BY ts.matches_played DESC, t.name ASC
        LIMIT %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (limit,))
            rows = cur.fetchall()

    items: List[Dict[str, Any]] = []
    for r in rows:
        items.append({
            "id": str(r[0]),
            "team_id": str(r[1]),
            "team_name": r[2],
            "league_id": str(r[3]),
            "league_name": r[4],
            "season_id": str(r[5]),
            "matches_played": r[6],
            "wins": r[7],
            "draws": r[8],
            "losses": r[9],
            "goals_for": r[10],
            "goals_against": r[11],
            "btts_hits": r[12],
            "over25_hits": r[13],
            "clean_sheets": r[14],
            "failed_to_score": r[15],
            "form_last5_points": r[16],
            "form_last5_wins": r[17],
            "form_last5_draws": r[18],
            "form_last5_losses": r[19],
            "form_last5_goals_for": r[20],
            "form_last5_goals_against": r[21],
        })

    return {"count": len(items), "items": items}
