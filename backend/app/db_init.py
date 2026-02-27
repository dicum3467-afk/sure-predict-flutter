from app.db import get_conn


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:

            # Needed for gen_random_uuid()
            cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")

            # =========================
            # LEAGUES
            # =========================
            cur.execute("""
            CREATE TABLE IF NOT EXISTS leagues (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                api_league_id INTEGER UNIQUE,
                name TEXT,
                country TEXT,
                logo TEXT
            );
            """)

            # =========================
            # FIXTURES (create if missing)
            # =========================
            cur.execute("""
            CREATE TABLE IF NOT EXISTS fixtures (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid()
            );
            """)

            # =========================
            # MIGRATIONS for FIXTURES
            # Add missing columns safely
            # =========================
            cur.execute("""
            ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS api_fixture_id INTEGER,
                ADD COLUMN IF NOT EXISTS league_id UUID,
                ADD COLUMN IF NOT EXISTS season INTEGER,
                ADD COLUMN IF NOT EXISTS fixture_date TIMESTAMP,
                ADD COLUMN IF NOT EXISTS status TEXT,
                ADD COLUMN IF NOT EXISTS status_short TEXT,
                ADD COLUMN IF NOT EXISTS home_team_id INTEGER,
                ADD COLUMN IF NOT EXISTS home_team TEXT,
                ADD COLUMN IF NOT EXISTS away_team_id INTEGER,
                ADD COLUMN IF NOT EXISTS away_team TEXT,
                ADD COLUMN IF NOT EXISTS home_goals INTEGER,
                ADD COLUMN IF NOT EXISTS away_goals INTEGER,
                ADD COLUMN IF NOT EXISTS run_type TEXT,
                ADD COLUMN IF NOT EXISTS raw JSONB;
            """)

            # If league_id existed as INTEGER in older schema, fix it (dev/test safe)
            # We detect the column type; if it's not uuid, we drop & recreate it as uuid.
            cur.execute("""
            DO $$
            DECLARE
                t TEXT;
            BEGIN
                SELECT udt_name INTO t
                FROM information_schema.columns
                WHERE table_name='fixtures' AND column_name='league_id';

                IF t IS NOT NULL AND t <> 'uuid' THEN
                    -- drop constraints that might block the change
                    BEGIN
                        ALTER TABLE fixtures DROP CONSTRAINT IF EXISTS fixtures_league_fk;
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;

                    ALTER TABLE fixtures DROP COLUMN league_id;
                    ALTER TABLE fixtures ADD COLUMN league_id UUID;
                END IF;
            END $$;
            """)

            # Ensure FK exists (if leagues table exists)
            cur.execute("""
            DO $$
            BEGIN
                -- add FK only if not already there
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'fixtures_league_fk'
                ) THEN
                    ALTER TABLE fixtures
                    ADD CONSTRAINT fixtures_league_fk
                    FOREIGN KEY (league_id) REFERENCES leagues(id)
                    ON DELETE SET NULL;
                END IF;
            END $$;
            """)

            # Ensure UNIQUE(api_fixture_id) exists
            cur.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'fixtures_api_fixture_id_key'
                ) THEN
                    ALTER TABLE fixtures
                    ADD CONSTRAINT fixtures_api_fixture_id_key UNIQUE (api_fixture_id);
                END IF;
            END $$;
            """)

        conn.commit()

    return {"status": "ok", "message": "db initialized + migrations applied"}
