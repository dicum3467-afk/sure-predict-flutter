from app.db import get_conn


DDL = """
-- Pentru UUID-uri
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Leagues (mapezi league API-Football -> UUID intern)
CREATE TABLE IF NOT EXISTS leagues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  api_league_id INT NOT NULL UNIQUE,
  name TEXT,
  country TEXT,
  logo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fixtures
CREATE TABLE IF NOT EXISTS fixtures (
  id BIGSERIAL PRIMARY KEY,
  league_id UUID NOT NULL REFERENCES leagues(id) ON DELETE CASCADE,

  season INT,
  api_fixture_id INT NOT NULL UNIQUE,

  fixture_date TIMESTAMPTZ,
  status TEXT,
  status_short TEXT,

  home_team_id INT,
  home_team TEXT,
  away_team_id INT,
  away_team TEXT,

  home_goals INT,
  away_goals INT,

  run_type TEXT NOT NULL DEFAULT 'manual',
  raw JSONB,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fixtures_league_date ON fixtures(league_id, fixture_date);
CREATE INDEX IF NOT EXISTS idx_fixtures_date ON fixtures(fixture_date);

-- Updated_at auto
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_fixtures_updated_at'
  ) THEN
    CREATE TRIGGER trg_fixtures_updated_at
    BEFORE UPDATE ON fixtures
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
"""


def init_db() -> dict:
    """
    Rulează DDL (idempotent) și returnează status.
    """
    conn = get_conn()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(DDL)
        return {"ok": True, "message": "DB initialized (tables ensured)."}
    finally:
        conn.close()
