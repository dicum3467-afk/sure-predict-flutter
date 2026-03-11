from app.services.stats_service import rebuild_team_stats
from app.utils.job_logger import log_job


def run():

    job = "rebuild_team_stats"

    try:
        rebuild_team_stats()
        log_job(job, "success", "team_stats rebuilt")

    except Exception as e:
        log_job(job, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
