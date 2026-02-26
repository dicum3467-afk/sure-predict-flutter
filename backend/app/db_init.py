from app.db import get_conn


def init_db():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS fixtures (
        id BIGINT PRIMARY KEY,
        league_id INT,
        season INT,
        home_team TEXT,
        away_team TEXT,
        match_date TIMESTAMP,
        status TEXT
    );
    """)

    conn.commit()
    cur.close()
    conn.close()
