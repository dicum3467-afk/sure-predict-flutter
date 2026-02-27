from app.db import get_conn


def init_db():
    """
    Inițializează/migrează schema DB pentru Sure Predict.
    Tabele:
      - leagues
      - fixtures

    IMPORTANT:
    - fixtures_sync.py inserează/actualizează coloanele:
      league_id, season, api_fixture_id, fixture_date, status, status_short,
      home_team_id, home_team, away_team_id, away_team,
      home_goals, away_goals, run_type, raw
    Așa că schema trebuie să le conțină 1:1.
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            # --------------------
            # LEAGUES
            # --------------------
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS leagues (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    api_league_id INTEGER UNIQUE,
                    name TEXT,
                    country TEXT,
                    logo TEXT
                );
                """
            )

            # --------------------
            # FIXTURES (create if missing)
            # --------------------
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS fixtures (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

                    -- API-Football fixture id (folosit la upsert)
                    api_fixture_id BIGINT UNIQUE NOT NULL,

                    league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,

                    season INTEGER,
                    fixture_date TIMESTAMPTZ,

                    status TEXT,
                    status_short TEXT,

                    home_team_id BIGINT,
                    home_team TEXT,
                    away_team_id BIGINT,
                    away_team TEXT,

                    home_goals INTEGER,
                    away_goals INTEGER,

                    run_type TEXT,
                    raw JSONB
                );
                """
            )

            # --------------------
            # MIGRATIONS (safe adds)
            # --------------------
            # dacă tabela exista dinainte, adaugă coloane lipsă
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS api_fixture_id BIGINT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS league_id UUID;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS season INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS fixture_date TIMESTAMPTZ;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS status TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS status_short TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_team_id BIGINT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_team TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_team_id BIGINT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_team TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_goals INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_goals INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS run_type TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS raw JSONB;")

            # FK dacă lipsește (nu dă eroare dacă există deja)
            cur.execute(
                """
                DO $$
                BEGIN
                  IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'fixtures_league_id_fkey'
                  ) THEN
                    ALTER TABLE fixtures
                      ADD CONSTRAINT fixtures_league_id_fkey
                      FOREIGN KEY (league_id) REFERENCES leagues(id)
                      ON DELETE SET NULL;
                  END IF;
                END$$;
                """
            )

            # UNIQUE pe api_fixture_id (pentru ON CONFLICT)
            cur.execute(
                """
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
                END$$;
                """
            )

            # --------------------
            # COMPAT: dacă ai coloane vechi, le mapăm pe cele noi
            # - raw_json -> raw
            # - goals_home -> home_goals
            # - goals_away -> away_goals
            # --------------------
            cur.execute(
                """
                DO $$
                BEGIN
                  IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='raw_json'
                  ) AND NOT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='raw'
                  ) THEN
                    ALTER TABLE fixtures RENAME COLUMN raw_json TO raw;
                  END IF;
                END$$;
                """
            )

            cur.execute(
                """
                DO $$
                BEGIN
                  IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='goals_home'
                  ) AND NOT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='home_goals'
                  ) THEN
                    ALTER TABLE fixtures RENAME COLUMN goals_home TO home_goals;
                  END IF;
                END$$;
                """
            )

            cur.execute(
                """
                DO $$
                BEGIN
                  IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='goals_away'
                  ) AND NOT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name='fixtures' AND column_name='away_goals'
                  ) THEN
                    ALTER TABLE fixtures RENAME COLUMN goals_away TO away_goals;
                  END IF;
                END$$;
                """
            )

        conn.commit()

    return {"status": "ok", "message": "database initialized"}
