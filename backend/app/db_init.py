from app.db import get_conn


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:

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
            # FIXTURES (STRUCTURA NOUĂ CORECTĂ)
            # =========================
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

            # =========================
            # MIGRATION SAFE (nu mai adăugăm FK aici!)
            # =========================
            cur.execute("""
            ALTER TABLE fixtures
            ADD COLUMN IF NOT EXISTS season INTEGER;
            """)

            cur.execute("""
            ALTER TABLE fixtures
            ADD COLUMN IF NOT EXISTS run_type TEXT;
            """)

        conn.commit()
