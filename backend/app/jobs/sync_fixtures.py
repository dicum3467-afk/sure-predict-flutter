from app.services.football_api import get_fixtures
from app.utils.job_logger import log_job
from app.utils.dates import today_str, days_from_today
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


def find_team_id_by_provider(cur, provider_team_id: str):
    cur.execute(
        "select id from teams where provider_team_id = %s limit 1",
        (provider_team_id,),
    )
    row = cur.fetchone()
    return row[0] if row else None


def find_season_id(cur, league_id):
    cur.execute(
        """
        select id
        from seasons
        where league_id = %s
        order by created_at desc
        limit 1
        """,
        (league_id,),
    )
    row = cur.fetchone()
    return row[0] if row else None


def run(season: int = 2026):
    job_name = "sync_fixtures"
    try:
        leagues = fetch_active_leagues()
        from_date = today_str()
        to_date = days_from_today(14)

        fixture_sql = """
            insert into fixtures (
                provider_fixture_id,
                league_id,
                home_team_id,
                away_team_id,
                kickoff_at,
                status,
                season_id,
                round
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (provider_fixture_id)
            do update set
                kickoff_at = excluded.kickoff_at,
                status = excluded.status,
                round = excluded.round,
                home_team_id = excluded.home_team_id,
                away_team_id = excluded.away_team_id,
                league_id = excluded.league_id,
                season_id = excluded.season_id
        """

        count = 0

        with get_conn() as conn:
            with conn.cursor() as cur:
                for league_id, provider_league_id in leagues:
                    payload = get_fixtures(provider_league_id, season, from_date, to_date)
                    rows = payload.get("response", [])

                    season_id = find_season_id(cur, league_id)

                    for item in rows:
                        fixture = item.get("fixture", {})
                        league = item.get("league", {})
                        teams = item.get("teams", {})

                        home = teams.get("home", {})
                        away = teams.get("away", {})

                        home_team_id = find_team_id_by_provider(cur, str(home.get("id")))
                        away_team_id = find_team_id_by_provider(cur, str(away.get("id")))

                        if not home_team_id or not away_team_id or not season_id:
                            continue

                        cur.execute(
                            fixture_sql,
                            (
                                str(fixture.get("id")),
                                league_id,
                                home_team_id,
                                away_team_id,
                                fixture.get("date"),
                                fixture.get("status", {}).get("short", "NS"),
                                season_id,
                                league.get("round"),
                            ),
                        )
                        count += 1

            conn.commit()

        log_job(job_name, "success", f"Imported/updated {count} fixtures")
    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
