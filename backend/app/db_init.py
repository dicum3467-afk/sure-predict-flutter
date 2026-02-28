# backend/app/db_init.py

from __future__ import annotations

from app.db import get_conn


def _col_type(cur, table: str, column: str):
    cur.execute(
        """
        SELECT data_type, udt_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s AND column_name = %s
        """,
        (table, column),
    )
    return cur.fetchone()  # (data_type, udt_name) or None


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


def _ensure_extensions(cur):
    # gen_random_uuid()
    cur.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')


def _create_leagues(cur):
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

    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_leagues_api_league_id
        ON leagues(api_league_id);
        """
    )


def _create_fixtures(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS fixtures (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

          api_fixture_id INTEGER UNIQUE NOT NULL,

          league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
          season INTEGER,

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

    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_fixtures_league_season_date
        ON fixtures(league_id, season, fixture_date);
        """
    )
    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_fixtures_api_fixture_id
        ON fixtures(api_fixture_id);
        """
    )


def _add_column_if_missing(cur, table: str, col: str, ddl_type: str):
    cur.execute(
        """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name=%s AND column_name=%s
        )
        """,
        (table, col),
    )
    exists = bool(cur.fetchone()[0])
    if not exists:
        cur.execute(f'ALTER TABLE "{table}" ADD COLUMN "{col}" {ddl_type};')


def _ensure_fixtures_columns(cur):
    # adaugă coloane lipsă (migrare “safe”)
    _add_column_if_missing(cur, "fixtures", "api_fixture_id", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "league_id", "UUID")
    _add_column_if_missing(cur, "fixtures", "season", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "fixture_date", "TIMESTAMPTZ")
    _add_column_if_missing(cur, "fixtures", "status", "TEXT")
    _add_column_if_missing(cur, "fixtures", "status_short", "TEXT")
    _add_column_if_missing(cur, "fixtures", "home_team_id", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "home_team", "TEXT")
    _add_column_if_missing(cur, "fixtures", "away_team_id", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "away_team", "TEXT")
    _add_column_if_missing(cur, "fixtures", "home_goals", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "away_goals", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "run_type", "TEXT")
    _add_column_if_missing(cur, "fixtures", "raw", "JSONB")
    _add_column_if_missing(cur, "fixtures", "created_at", "TIMESTAMPTZ NOT NULL DEFAULT now()")
    _add_column_if_missing(cur, "fixtures", "updated_at", "TIMESTAMPTZ NOT NULL DEFAULT now()")

    # unique constraint pe api_fixture_id (dacă nu există)
    cur.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'fixtures_api_fixture_id_key'
          ) THEN
            BEGIN
              ALTER TABLE fixtures
              ADD CONSTRAINT fixtures_api_fixture_id_key UNIQUE (api_fixture_id);
            EXCEPTION WHEN duplicate_table OR duplicate_object THEN
              -- ignore
            END;
          END IF;
        END$$;
        """
    )

    # FK league_id -> leagues(id) (dacă nu există)
    cur.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'fixtures_league_id_fkey'
          ) THEN
            BEGIN
              ALTER TABLE fixtures
              ADD CONSTRAINT fixtures_league_id_fkey
              FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE SET NULL;
            EXCEPTION WHEN duplicate_table OR duplicate_object THEN
              -- ignore
            END;
          END IF;
        END$$;
        """
    )


def _schema_compatible_or_recreate(cur):
    """
    Dacă ai deja fixtures vechi cu tipuri incompatibile (de ex league_id INTEGER),
    e aproape imposibil de “ALTER TYPE” corect fără pierdere/complicații.
    Cel mai safe: DROP fixtures și recreezi (datele vin din sync).
    """
    if not _table_exists(cur, "fixtures"):
        return

    # league_id trebuie să fie uuid (udt_name = uuid)
    league_id = _col_type(cur, "fixtures", "league_id")
    if league_id is not None:
        data_type, udt_name = league_id
        if udt_name != "uuid":
            # drop & recreate fixtures (nu atinge leagues)
            cur.execute("DROP TABLE IF EXISTS fixtures CASCADE;")
            _create_fixtures(cur)
            return

    # api_fixture_id trebuie să existe
    api_fix = _col_type(cur, "fixtures", "api_fixture_id")
    if api_fix is None:
        # dacă e veche schema, mai simplu drop & recreate
        cur.execute("DROP TABLE IF EXISTS fixtures CASCADE;")
        _create_fixtures(cur)
        return


def init_db() -> dict:
    """
    Rulează la /admin/db/init
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            _ensure_extensions(cur)

            # tabele core
            _create_leagues(cur)
            _create_fixtures(cur)

            # dacă fixtures e incompatibil -> recreează
            _schema_compatible_or_recreate(cur)

            # migrare coloane lipsă + constraints
            _ensure_fixtures_columns(cur)

        conn.commit()

    return {"status": "ok", "message": "db initialized"}
