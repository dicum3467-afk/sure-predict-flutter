from app.services.football_api import get_leagues
from app.utils.job_logger import log_job
from app.db import get_conn


def run():
    job_name = "sync_leagues"
    try:
        payload = get_leagues()

        rows = payload.get("response", [])

        sql = """
            insert into leagues (
                provider_league_id,
                name,
                country,
                is_active
            )
            values (%s, %s, %s, %s)
            on conflict (provider_league_id)
            do update set
                name = excluded.name,
                country = excluded.country,
                is_active = excluded.is_active
        """

        count = 0
        with get_conn() as conn:
            with conn.cursor() as cur:
                for item in rows:
                    league = item.get("league", {})
                    country = item.get("country", {})
                    cur.execute(
                        sql,
                        (
                            str(league.get("id")),
                            league.get("name"),
                            country.get("name"),
                            True,
                        ),
                    )
                    count += 1
            conn.commit()

        log_job(job_name, "success", f"Imported {count} leagues")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
