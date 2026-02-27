# backend/app/db_init.py

from __future__ import annotations

from app.db import get_conn


def _get_col_type(cur, table: str, column: str) -> str | None:
    cur.execute(
        """
        SELECT data_type, udt_name
        FROM information_schema.columns
        WHERE table_schema='public' AND table_name=%s AND column_name=%s
        """,
        (table, column),
    )
    row = cur.fetchone()
    if not row:
        return None
    data_type, udt_name = row
    # pentru uuid, in info_schema apare data_type='uuid', udt_name='uuid'
    return (data_type or udt_name or "").lower()


def _table_exists(cur, table: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.tables
          WHERE table_schema='public' AND table_name=%s
        )
        """,
        (table,),
    )
    return bool(cur.fetchone()[0])


def init_db() -> dict:
    """
    Initializează / migrează schema DB pentru:
      - leagues
      - fixtures

    IMPORTANT:
      Dacă găsește schema veche (leagues.id INTEGER), face DROP+CREATE
      ca să repare definitiv tipurile (UUID).
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            # 1) Extensie pentru UUID default
            cur.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")

            # 2) Detectare schema veche (id integer) -> DROP + CREATE
            if _table_exists(cur, "leagues"):
                leagues_id_type = _get_col_type(cur, "leagues", "id")
                # dacă e integer/bigint -> e schema veche
                if leagues_id_type in ("integer", "bigint"):
                    # fixtures depinde de leagues
                    cur.execute("DROP TABLE IF EXISTS fixtures CASCADE;")
                    cur.execute("DROP TABLE IF EXISTS leagues CASCADE;")

            # 3) CREATE TABLE leagues (corect)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS leagues (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    api_league_id INTEGER UNIQUE NOT NULL,
                    name TEXT,
                    country TEXT,
                    logo TEXT,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                """
            )

            # Migrare leagues (dacă a existat dar fără default)
            cur.execute(
                """
                ALTER TABLE leagues
                ALTER COLUMN id SET DEFAULT gen_random_uuid();
                """
            )

            # 4) CREATE TABLE fixtures (corect - potrivit cu fixtures_sync.py)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS fixtures (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

                    league_id UUID NULL REFERENCES leagues(id) ON DELETE SET NULL,
                    season INTEGER,

                    api_fixture_id INTEGER UNIQUE,
                    fixture_date TIMESTAMPTZ,

                    status TEXT,
                    status_short TEXT,

                    home_team_id INTEGER,
                    home_team TEXT,
                    away_team_id INTEGER,
                    away_team TEXT,

                    home_goals INTEGER,
                    away_goals INTEGER,

                    run_type TEXT,
                    raw JSONB,

                    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                """
            )

            # 5) MIGRATIONS fixtures (pentru DB-uri deja create)
            # - coloane lipsă
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS league_id UUID;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS season INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS api_fixture_id INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS fixture_date TIMESTAMPTZ;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS status TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS status_short TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_team_id INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_team TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_team_id INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_team TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS home_goals INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS away_goals INTEGER;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS run_type TEXT;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS raw JSONB;")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();")
            cur.execute("ALTER TABLE fixtures ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();")

            # - default la id (FIX pentru eroarea ta NotNullViolation)
            cur.execute("ALTER TABLE fixtures ALTER COLUMN id SET DEFAULT gen_random_uuid();")

            # - unique pe api_fixture_id (dacă lipsește)
            cur.execute(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint
                        WHERE conname = 'fixtures_api_fixture_id_key'
                    ) THEN
                        ALTER TABLE fixtures
                        ADD CONSTRAINT fixtures_api_fixture_id_key UNIQUE (api_fixture_id);
                    END IF;
                END$$;
                """
            )

            # - foreign key league_id (dacă lipsește)
            #   (în cazul în care fixtures era vechi și nu avea FK)
            cur.execute(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint
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

            # index util
            cur.execute("CREATE INDEX IF NOT EXISTS idx_fixtures_league_season ON fixtures(league_id, season);")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_fixtures_date ON fixtures(fixture_date);")

        conn.commit()

    return {"status": "ok", "message": "db initialized"}
