from app.db import get_conn


def init_db():
    """
    Creează și migrează schema DB pentru Sure Predict.
    SAFE: poate fi rulat de mai multe ori.
    """

    with get_conn() as conn:
        with conn.cursor() as cur:

            # =========================================================
            # 🏆 LEAGUES
            # =========================================================
            cur.execute("""
                CREATE TABLE IF NOT EXISTS leagues (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    api_league_id INTEGER UNIQUE,
                    name TEXT,
                    country TEXT,
                    logo TEXT
                );
            """)

            # =========================================================
            # ⚽ FIXTURES (schema corectă finală)
            # =========================================================
            cur.execute("""
                CREATE TABLE IF NOT EXISTS fixtures (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    api_fixture_id INTEGER UNIQUE,
                    league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
                    season INTEGER,
                    fixture_date TIMESTAMP,
                    status TEXT,
                    status_short TEXT,

                    home_team_id INTEGER,
                    home_team TEXT,
                    away_team_id INTEGER,
                    away_team TEXT,

                    home_goals INTEGER,
                    away_goals INTEGER,

                    run_type TEXT,
                    raw JSONB
                );
            """)

            # =========================================================
            # 🔧 MIGRATIONS — dacă tabela exista deja
            # =========================================================

            # --- api_fixture_id (CRITIC)
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS api_fixture_id INTEGER;
            """)

            cur.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS fixtures_api_fixture_id_idx
                ON fixtures(api_fixture_id);
            """)

            # --- league_id
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS league_id UUID;
            """)

            # FK safe
            cur.execute("""
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM information_schema.table_constraints
                        WHERE constraint_name = 'fixtures_league_fk'
                    ) THEN
                        ALTER TABLE fixtures
                        ADD CONSTRAINT fixtures_league_fk
                        FOREIGN KEY (league_id)
                        REFERENCES leagues(id)
                        ON DELETE SET NULL;
                    END IF;
                END$$;
            """)

            # --- season
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS season INTEGER;
            """)

            # --- status_short
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS status_short TEXT;
            """)

            # --- team ids
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS home_team_id INTEGER;
            """)

            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS away_team_id INTEGER;
            """)

            # --- run_type
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS run_type TEXT;
            """)

            # --- raw json
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS raw JSONB;
            """)

            conn.commit()

    return {"ok": True}
