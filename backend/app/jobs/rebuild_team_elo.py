from app.services.elo_service import rebuild_team_elo
from app.utils.job_logger import log_job


def run():
    job_name = "rebuild_team_elo"
    try:
        rebuild_team_elo()
        log_job(job_name, "success", "team_elo rebuilt")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
