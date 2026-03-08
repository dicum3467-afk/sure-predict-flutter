from app.db import get_conn


def rebuild_team_stats():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("delete from team_stats")

            cur.execute("""
                insert into team_stats (
                    team_id,
                    league_id,
                    season_id,
                    matches_played,
                    wins,
                    draws,
                    losses,
                    goals_for,
                    goals_against,
                    home_matches,
                    home_wins,
                    home_draws,
                    home_losses,
                    home_goals_for,
                    home_goals_against,
                    away_matches,
                    away_wins,
                    away_draws,
                    away_losses,
                    away_goals_for,
                    away_goals_against,
                    btts_hits,
                    over25_hits,
                    clean_sheets,
                    failed_to_score,
                    form_last5_points,
                    form_last5_wins,
                    form_last5_draws,
                    form_last5_losses,
                    form_last5_goals_for,
                    form_last5_goals_against,
                    updated_at
                )
                select
                    t.team_id,
                    t.league_id,
                    t.season_id,
                    count(*) as matches_played,
                    sum(case when t.points = 3 then 1 else 0 end) as wins,
                    sum(case when t.points = 1 then 1 else 0 end) as draws,
                    sum(case when t.points = 0 then 1 else 0 end) as losses,
                    sum(t.gf) as goals_for,
                    sum(t.ga) as goals_against,
                    sum(case when t.is_home then 1 else 0 end) as home_matches,
                    sum(case when t.is_home and t.points = 3 then 1 else 0 end) as home_wins,
                    sum(case when t.is_home and t.points = 1 then 1 else 0 end) as home_draws,
                    sum(case when t.is_home and t.points = 0 then 1 else 0 end) as home_losses,
                    sum(case when t.is_home then t.gf else 0 end) as home_goals_for,
                    sum(case when t.is_home then t.ga else 0 end) as home_goals_against,
                    sum(case when not t.is_home then 1 else 0 end) as away_matches,
                    sum(case when not t.is_home and t.points = 3 then 1 else 0 end) as away_wins,
                    sum(case when not t.is_home and t.points = 1 then 1 else 0 end) as away_draws,
                    sum(case when not t.is_home and t.points = 0 then 1 else 0 end) as away_losses,
                    sum(case when not t.is_home then t.gf else 0 end) as away_goals_for,
                    sum(case when not t.is_home then t.ga else 0 end) as away_goals_against,
                    sum(case when t.gf > 0 and t.ga > 0 then 1 else 0 end) as btts_hits,
                    sum(case when t.gf + t.ga > 2 then 1 else 0 end) as over25_hits,
                    sum(case when t.ga = 0 then 1 else 0 end) as clean_sheets,
                    sum(case when t.gf = 0 then 1 else 0 end) as failed_to_score,
                    0, 0, 0, 0, 0, 0,
                    now()
                from (
                    select
                        f.home_team_id as team_id,
                        f.league_id,
                        f.season_id,
                        true as is_home,
                        f.home_goals as gf,
                        f.away_goals as ga,
                        case
                            when f.home_goals > f.away_goals then 3
                            when f.home_goals = f.away_goals then 1
                            else 0
                        end as points
                    from fixtures f
                    where f.home_goals is not null and f.away_goals is not null

                    union all

                    select
                        f.away_team_id as team_id,
                        f.league_id,
                        f.season_id,
                        false as is_home,
                        f.away_goals as gf,
                        f.home_goals as ga,
                        case
                            when f.away_goals > f.home_goals then 3
                            when f.away_goals = f.home_goals then 1
                            else 0
                        end as points
                    from fixtures f
                    where f.home_goals is not null and f.away_goals is not null
                ) t
                group by t.team_id, t.league_id, t.season_id
            """)

        conn.commit()
