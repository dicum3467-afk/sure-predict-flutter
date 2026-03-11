from app.db import get_conn


BASE_ELO = 1500
K = 20


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
            order by kickoff_at
            """)

            matches = cur.fetchall()

            for home_id, away_id, hg, ag in matches:

                cur.execute(
                    "select elo_rating from team_elo where team_id=%s",
                    (home_id,)
                )
                home_elo = float(cur.fetchone()[0])

                cur.execute(
                    "select elo_rating from team_elo where team_id=%s",
                    (away_id,)
                )
                away_elo = float(cur.fetchone()[0])

                expected_home = 1 / (1 + 10 ** ((away_elo - home_elo) / 400))
                expected_away = 1 / (1 + 10 ** ((home_elo - away_elo) / 400))

                if hg > ag:
                    score_home, score_away = 1, 0
                elif hg < ag:
                    score_home, score_away = 0, 1
                else:
                    score_home, score_away = 0.5, 0.5

                new_home = home_elo + K * (score_home - expected_home)
                new_away = away_elo + K * (score_away - expected_away)

                cur.execute(
                    "update team_elo set elo_rating=%s where team_id=%s",
                    (new_home, home_id),
                )

                cur.execute(
                    "update team_elo set elo_rating=%s where team_id=%s",
                    (new_away, away_id),
                )

        conn.commit()
