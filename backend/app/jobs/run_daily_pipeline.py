from app.jobs.sync_fixtures import run as run_sync_fixtures
from app.jobs.sync_results import run as run_sync_results
from app.jobs.rebuild_team_stats import run as run_rebuild_team_stats
from app.jobs.rebuild_team_elo import run as run_rebuild_team_elo


def run():
    run_sync_fixtures()
    run_sync_results()
    run_rebuild_team_stats()
    run_rebuild_team_elo()


if __name__ == "__main__":
    run()
