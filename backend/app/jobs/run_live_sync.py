from __future__ import annotations

from app.utils.job_logger import log_job


def run() -> None:
    try:
        from app.routes.fixtures_sync import run_fixtures_sync
        from app.routes.teams_sync import run_teams_sync
        from app.routes.leagues_sync import run_leagues_sync

        try:
            from app.routes.odds import run_odds_sync
        except Exception:
            run_odds_sync = None

        try:
            from app.routes.team_stats import rebuild_team_stats
        except Exception:
            rebuild_team_stats = None

        try:
            from app.routes.evaluation import rebuild_team_elo
        except Exception:
            rebuild_team_elo = None

        run_leagues_sync()
        run_teams_sync()
        run_fixtures_sync()

        if run_odds_sync:
            run_odds_sync()

        if rebuild_team_stats:
            rebuild_team_stats()

        if rebuild_team_elo:
            rebuild_team_elo()

        log_job("run_live_sync", "success", "15-minute sync completed")

    except Exception as e:
        log_job("run_live_sync", "failed", str(e))
        raise


if __name__ == "__main__":
    run()
