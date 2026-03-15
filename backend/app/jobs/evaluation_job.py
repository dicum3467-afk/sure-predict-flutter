from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict


def run_evaluation_and_calibration_job(
    days_back: int = 120,
    min_samples: int = 120,
    league_id: int | None = None,
) -> Dict[str, Any]:

    return {
        "ok": True,
        "status": "disabled_temporarily",
        "message": "evaluation job disabled for now",
        "days_back": days_back,
        "min_samples": min_samples,
        "league_id": league_id,
        "finished_at": datetime.now(timezone.utc).isoformat(),
    }
