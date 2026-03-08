from app.services.stats_service import rebuild_team_stats
from app.utils.job_logger import log_job


def run():
    job_name = "rebuild_team_stats"
    try:
        rebuild_team_stats()
        log_job(job_name, "success", "team_stats rebuilt")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
