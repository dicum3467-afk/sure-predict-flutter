from __future__ import annotations

from app.db import get_conn
from app.services.football_api import get_fixtures
from app.utils.dates import today_str, days_from_today
from app.utils.job_logger import log_job


def _fetch_active_leagues():
    sql = """
        select id, provider_league_id, name
        from leagues
        where coalesce(is_active, true) = true
        and provider_league_id is not null
        order by name
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            return cur.fetchall()


def _find_team_id_by_provider(cur, provider_team_id: str):
    cur.execute(
        """
        select id
        from teams
        where provider_team_id = %s
        limit 1
        """,
        (provider_team_id,),
    )
    row = cur.fetchone()
    return row[0] if row else None


def _find_or_create_season(cur, league_id, season_year: int):
    cur.execute(
        """
        select id
        from seasons
        where league_id = %s
          and year_start = %s
        limit 1
        """,
        (league_id, season_year),
    )
    row = cur.fetchone()
    if row:
        return row[0]

    cur.execute(
        """
        insert into seasons (
            league_id,
            name,
            year_start,
            year_end
        )
        values (%s, %s, %s, %s)
        returning id
        """,
        (
            league_id,
            f"Season {season_year}/{season_year + 1}",
            season_year,
            season_year + 1,
        ),
    )
    new_row = cur.fetchone()
    return new_row[0]


def run(season: int = 2026, days_ahead: int = 14):
    job_name = "sync_fixtures"

    try:
        leagues = _fetch_active_leagues()
        from_date = today_str()
        to_date = days_from_today(days_ahead)

        fixture_sql = """
            insert into fixtures (
                provider_fixture_id,
                league_id,
                home_team_id,
                away_team_id,
                kickoff_at,
                status,
                season_id,
                round,
                home_goals,
                away_goals
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (provider_fixture_id)
            do update set
                league_id = excluded.league_id,
                home_team_id = excluded.home_team_id,
                away_team_id = excluded.away_team_id,
                kickoff_at = excluded.kickoff_at,
                status = excluded.status,
                season_id = excluded.season_id,
                round = excluded.round,
                home_goals = excluded.home_goals,
                away_goals = excluded.away_goals
        """

        imported = 0
        skipped = 0

        with get_conn() as conn:
            with conn.cursor() as cur:
                for league_id, provider_league_id, league_name in leagues:
                    payload = get_fixtures(
                        str(provider_league_id),
                        season,
                        from_date,
                        to_date,
                    )

                    rows = payload.get("response", []) or []

                    season_id = _find_or_create_season(cur, league_id, season)

                    for item in rows:
                        fixture = item.get("fixture", {}) or {}
                        league = item.get("league", {}) or {}
                        teams = item.get("teams", {}) or {}
                        goals = item.get("goals", {}) or {}

                        home = teams.get("home", {}) or {}
                        away = teams.get("away", {}) or {}

                        provider_home_id = home.get("id")
                        provider_away_id = away.get("id")
                        provider_fixture_id = fixture.get("id")

                        if not provider_home_id or not provider_away_id or not provider_fixture_id:
                            skipped += 1
                            continue

                        home_team_id = _find_team_id_by_provider(cur, str(provider_home_id))
                        away_team_id = _find_team_id_by_provider(cur, str(provider_away_id))

                        if not home_team_id or not away_team_id:
                            skipped += 1
                            continue

                        kickoff_at = fixture.get("date")
                        status = (fixture.get("status", {}) or {}).get("short", "NS")
                        round_name = league.get("round")

                        cur.execute(
                            fixture_sql,
                            (
                                str(provider_fixture_id),
                                league_id,
                                home_team_id,
                                away_team_id,
                                kickoff_at,
                                status,
                                season_id,
                                round_name,
                                goals.get("home"),
                                goals.get("away"),
                            ),
                        )
                        imported += 1

            conn.commit()

        log_job(
            job_name,
            "success",
            f"Imported/updated {imported} fixtures, skipped {skipped}",
        )

    except Exception as e:
        log_job(job_name, "failed", str(e))
        raise


if __name__ == "__main__":
    run()
