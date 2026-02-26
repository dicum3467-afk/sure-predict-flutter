from app.db import get_conn

DDL = """
CREATE TABLE IF NOT EXISTS leagues (
  league_id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT,
  country TEXT,
  logo TEXT,
  flag TEXT,
  last_season INTEGER
);

CREATE TABLE IF NOT EXISTS teams (
  team_id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT,
  country TEXT,
  founded INTEGER,
  national BOOLEAN,
  logo TEXT
);

-- Legătura team <-> league pe sezon
CREATE TABLE IF NOT EXISTS league_teams (
  league_id INTEGER NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
  season INTEGER NOT NULL,
  team_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
  PRIMARY KEY (league_id, season, team_id)
);

-- (opțional) index util
CREATE INDEX IF NOT EXISTS idx_league_teams_league_season
  ON league_teams(league_id, season);
"""

def init_db() -> None:
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(DDL)
    finally:
        conn.close()
