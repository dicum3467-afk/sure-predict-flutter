from app.services.football_api import get_teams
from app.utils.job_logger import log_job
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
    job_name = "sync_teams"
    try:
        leagues = fetch_active_leagues()
        count = 0

        team_sql = """
            insert into teams (
                provider_team_id,
                name,
                short_name,
                logo
            )
            values (%s, %s, %s, %s)
            on conflict (provider_team_id)
            do update set
                name = excluded.name,
                short_name = excluded.short_name,
                logo = excluded.logo
        """

        with get_conn() as conn:
            with conn.cursor() as cur:
                for _, provider_league_id in leagues:
                    payload = get_teams(provider_league_id, season)
                    rows = payload.get("response", [])

                    for item in rows:
                        team = item.get("team", {})
                        cur.execute(
                            team_sql,
                            (
                                str(team.get("id")),
                                team.get("name"),
                                team.get("code"),
                                team.get("logo"),
                            ),
                        )
                        count += 1
            conn.commit()

        log_job(job_name, "success", f"Imported/updated {count} teams")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
