# backend/app/db_init.py
# Inițializează / migrează schema Postgres pentru Sure Predict
#
# Folosește app.db.get_conn() (psycopg v3). Codul suportă row_factory=dict_row sau tuple.
#
# ATENȚIE:
# - Dacă ai avut un fixtures.league_id vechi ca INTEGER (nu UUID), nu se poate converti direct.
#   În acest caz, scriptul va recrea tabela fixtures (drop + create) ca să fie compatibilă.
#   Dacă vrei să eviți drop, setează FORCE_RECREATE_FIXTURES=0 și vei primi eroare cu mesaj clar.

from __future__ import annotations

import os
import time
from typing import Optional, Tuple, Any

from app.db import get_conn


# --------------------------
# helpers (dict_row safe)
# --------------------------

def _scalar(row: Any, key: str | None = None, idx: int = 0):
    """Returnează o valoare din row (dict sau tuple)."""
    if row is None:
        return None
    if isinstance(row, dict):
        if key is not None:
            return row.get(key)
        return next(iter(row.values()), None)
    return row[idx]


def _table_exists(cur, table: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.tables
          WHERE table_schema='public' AND table_name=%s
        ) AS exists
        """,
        (table,),
    )
    return bool(_scalar(cur.fetchone(), key="exists"))


def _column_exists(cur, table: str, column: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS(
          SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name=%s AND column_name=%s
        ) AS exists
        """,
        (table, column),
    )
    return bool(_scalar(cur.fetchone(), key="exists"))


def _col_type(cur, table: str, column: str) -> Optional[Tuple[str, str]]:
    """
    Returnează (data_type, udt_name) sau None dacă nu există.
    Exemple:
      - UUID: ("uuid", "uuid")
      - integer: ("integer", "int4")
      - text: ("text", "text")
      - timestamptz: ("timestamp with time zone", "timestamptz")
    """
    cur.execute(
        """
        SELECT data_type, udt_name
        FROM information_schema.columns
        WHERE table_schema='public' AND table_name=%s AND column_name=%s
        """,
        (table, column),
    )
    row = cur.fetchone()
    if row is None:
        return None
    if isinstance(row, dict):
        return (row.get("data_type"), row.get("udt_name"))
    return row  # tuple


def _add_column_if_missing(cur, table: str, col: str, ddl_type: str):
    if not _column_exists(cur, table, col):
        cur.execute(f'ALTER TABLE "{table}" ADD COLUMN "{col}" {ddl_type};')


def _drop_constraint_if_exists(cur, table: str, constraint_name: str):
    cur.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = %s
          ) THEN
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', %s, %s);
          END IF;
        END $$;
        """,
        (constraint_name, table, constraint_name),
    )


def _ensure_pgcrypto(cur):
    # gen_random_uuid() este în extensia pgcrypto
    cur.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')


# --------------------------
# schema create
# --------------------------

def _create_leagues(cur):
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


def _create_fixtures(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS fixtures (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

          league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
          season INTEGER,

          api_fixture_id BIGINT UNIQUE,

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
          raw JSONB
        );
        """
    )


def _ensure_indexes(cur):
    # utile pentru query-uri
    cur.execute('CREATE INDEX IF NOT EXISTS idx_fixtures_league_season ON fixtures(league_id, season);')
    cur.execute('CREATE INDEX IF NOT EXISTS idx_fixtures_date ON fixtures(fixture_date);')


# --------------------------
# migrations / compatibility
# --------------------------

def _fixtures_needs_recreate(cur) -> bool:
    """
    Returnează True dacă fixtures există dar are tipuri incompatibile (ex: league_id int).
    """
    if not _table_exists(cur, "fixtures"):
        return False

    # league_id trebuie să fie uuid
    t = _col_type(cur, "fixtures", "league_id")
    if t is not None:
        data_type, udt = t
        # pentru uuid: data_type poate fi 'uuid' sau udt_name 'uuid'
        if (udt or "").lower() != "uuid":
            return True

    # api_fixture_id trebuie să existe (altfel aveai eroarea UndefinedColumn)
    if not _column_exists(cur, "fixtures", "api_fixture_id"):
        return True

    return False


def _recreate_fixtures(cur):
    # Drop and recreate fixtures table
    # (în proiectul tău e early-stage; dacă ai date importante, fă backup înainte)
    cur.execute("DROP TABLE IF EXISTS fixtures CASCADE;")
    _create_fixtures(cur)
    _ensure_indexes(cur)


def _migrate_fixtures_in_place(cur):
    """
    Migrare safe (add columns) fără recreate.
    Atenție: nu poate converti league_id int -> uuid.
    """
    # adaugă coloanele noi, dacă lipsesc
    _add_column_if_missing(cur, "fixtures", "season", "INTEGER")
    _add_column_if_missing(cur, "fixtures", "api_fixture_id", "BIGINT")
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

    # asigură UNIQUE pe api_fixture_id (dacă lipsește)
    # (nu știm numele exact al constraint-ului vechi, deci folosim CREATE UNIQUE INDEX)
    cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_fixtures_api_fixture_id ON fixtures(api_fixture_id);")

    _ensure_indexes(cur)


# --------------------------
# public entry point
# --------------------------

def init_db() -> dict:
    """
    Creează schema + face migrarea astfel încât sync/fixtures să funcționeze.
    Returnează dict pentru endpoint /admin/db/init.
    """
    force_recreate = os.getenv("FORCE_RECREATE_FIXTURES", "1").strip() not in ("0", "false", "False")

    with get_conn() as conn:
        with conn.cursor() as cur:
            _ensure_pgcrypto(cur)

            # base tables
            _create_leagues(cur)

            if not _table_exists(cur, "fixtures"):
                _create_fixtures(cur)
                _ensure_indexes(cur)
                conn.commit()
                return {"status": "ok", "message": "db initialized (fresh schema)"}

            # fixtures exists -> ensure compatible
            if _fixtures_needs_recreate(cur):
                if not force_recreate:
                    t = _col_type(cur, "fixtures", "league_id")
                    raise RuntimeError(
                        "Schema incompatibilă la fixtures (ex: league_id nu e UUID / api_fixture_id lipsește). "
                        "Setează FORCE_RECREATE_FIXTURES=1 (default) ca să recreeze tabela fixtures."
                        f" league_id type={t}"
                    )
                _recreate_fixtures(cur)
                conn.commit()
                return {"status": "ok", "message": "db initialized (fixtures recreated for compatibility)"}

            # altfel: migrate in place (add missing columns/indexes)
            _migrate_fixtures_in_place(cur)
            conn.commit()
            return {"status": "ok", "message": "db initialized (migrated in place)"}
