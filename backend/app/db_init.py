from app.db import get_conn


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            # =========================
            # LEAGUES
            # =========================
            cur.execute("""
                CREATE TABLE IF NOT EXISTS leagues (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
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
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    api_fixture_id INTEGER UNIQUE,
                    league_id UUID REFERENCES leagues(id),
                    home_team TEXT,
                    away_team TEXT,
                    fixture_date TIMESTAMP,
                    status_short TEXT,
                    goals_home INTEGER,
                    goals_away INTEGER,
                    raw_json JSONB
                );
            """)

            # =========================
            # 🔥 MIGRATION FIX (IMPORTANT)
            # adaugă coloane dacă lipsesc
            # =========================
            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS fixture_date TIMESTAMP;
            """)

            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS status_short TEXT;
            """)

            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS goals_home INTEGER;
            """)

            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS goals_away INTEGER;
            """)

            cur.execute("""
                ALTER TABLE fixtures
                ADD COLUMN IF NOT EXISTS raw_json JSONB;
            """)

        conn.commit()
