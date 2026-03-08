from app.services.football_api import get_fixtures
from app.utils.job_logger import log_job
from app.utils.dates import days_from_today
from app.db import get_conn


def fetch_active_leagues():
    sql = """
        select id, provider_league_id
        from leagues
        where is_active = true
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            return cur.fetchall()


def run(season: int = 2026):
    job_name = "sync_results"
    try:
        leagues = fetch_active_leagues()
        from_date = days_from_today(-7)
        to_date = days_from_today(1)

        update_sql = """
            update fixtures
            set
                status = %s,
                home_goals = %s,
                away_goals = %s
            where provider_fixture_id = %s
        """

        count = 0

        with get_conn() as conn:
            with conn.cursor() as cur:
                for _, provider_league_id in leagues:
                    payload = get_fixtures(provider_league_id, season, from_date, to_date)
                    rows = payload.get("response", [])

                    for item in rows:
                        fixture = item.get("fixture", {})
                        goals = item.get("goals", {})

                        cur.execute(
                            update_sql,
                            (
                                fixture.get("status", {}).get("short", "NS"),
                                goals.get("home"),
                                goals.get("away"),
                                str(fixture.get("id")),
                            ),
                        )
                        count += 1

            conn.commit()

        log_job(job_name, "success", f"Updated {count} fixture results")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
