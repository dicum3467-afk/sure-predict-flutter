from app.db import get_conn


BASE_ELO = 1500.0
K_FACTOR = 20.0


def rebuild_team_elo():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("delete from team_elo")
            cur.execute("""
                insert into team_elo (team_id, elo_rating, updated_at)
                select id, %s, now()
                from teams
            """, (BASE_ELO,))

            cur.execute("""
                select
                    home_team_id,
                    away_team_id,
                    home_goals,
                    away_goals
                from fixtures
                where home_goals is not null
                  and away_goals is not null
                order by kickoff_at asc
            """)
            matches = cur.fetchall()

            for home_team_id, away_team_id, home_goals, away_goals in matches:
                cur.execute("select elo_rating from team_elo where team_id = %s", (home_team_id,))
                home_elo = float(cur.fetchone()[0])

                cur.execute("select elo_rating from team_elo where team_id = %s", (away_team_id,))
                away_elo = float(cur.fetchone()[0])

                expected_home = 1 / (1 + 10 ** ((away_elo - home_elo) / 400))
                expected_away = 1 / (1 + 10 ** ((home_elo - away_elo) / 400))

                if home_goals > away_goals:
                    actual_home, actual_away = 1.0, 0.0
                elif home_goals < away_goals:
                    actual_home, actual_away = 0.0, 1.0
                else:
                    actual_home, actual_away = 0.5, 0.5

                new_home = home_elo + K_FACTOR * (actual_home - expected_home)
                new_away = away_elo + K_FACTOR * (actual_away - expected_away)

                cur.execute(
                    "update team_elo set elo_rating = %s, updated_at = now() where team_id = %s",
                    (new_home, home_team_id),
                )
                cur.execute(
                    "update team_elo set elo_rating = %s, updated_at = now() where team_id = %s",
                    (new_away, away_team_id),
                )

        conn.commit()
