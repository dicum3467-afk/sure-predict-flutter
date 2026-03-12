from __future__ import annotations

from app.db import get_conn
from app.services.football_api import get_fixtures
from app.utils.dates import days_from_today
from app.utils.job_logger import log_job


def _fetch_active_leagues():
    sql = """
        select provider_league_id
        from leagues
        where coalesce(is_active, true) = true
        and provider_league_id is not null
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            return [r[0] for r in cur.fetchall()]


def run(season: int = 2026):
    job_name = "sync_results"

    try:
        leagues = _fetch_active_leagues()
        from_date = days_from_today(-7)
        to_date = days_from_today(1)

        updated = 0

        with get_conn() as conn:
            with conn.cursor() as cur:
                for provider_league_id in leagues:
                    payload = get_fixtures(
                        str(provider_league_id),
                        season,
                        from_date,
                        to_date,
                    )

                    rows = payload.get("response", []) or []

                    for item in rows:
                        fixture = item.get("fixture", {}) or {}
                        goals = item.get("goals", {}) or {}

                        provider_fixture_id = fixture.get("id")
                        status = (fixture.get("status", {}) or {}).get("short", "NS")
                        home_goals = goals.get("home")
                        away_goals = goals.get("away")

                        if not provider_fixture_id:
                            continue

                        cur.execute(
                            """
                            update fixtures
                            set
                                status = %s,
                                home_goals = %s,
                                away_goals = %s
                            where provider_fixture_id = %s
                            """,
                            (
                                status,
                                home_goals,
                                away_goals,
                                str(provider_fixture_id),
                            ),
                        )
                        updated += 1

            conn.commit()

        log_job(job_name, "success", f"Updated {updated} fixture results")

    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
