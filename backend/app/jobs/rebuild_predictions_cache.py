from __future__ import annotations

from app.utils.job_logger import log_job


def run() -> None:
    try:
        from app.routes.predictions import list_predictions, list_predictions_today, list_top_predictions

        list_predictions(limit=100)
        list_predictions_today()
        list_top_predictions(limit=20)

        log_job("rebuild_predictions_cache", "success", "prediction cache refreshed")

    except Exception as e:
        log_job("rebuild_predictions_cache", "failed", str(e))
        raise


if __name__ == "__main__":
    run()
