from __future__ import annotations

from app.db import get_conn


def log_job(job_name: str, status: str, message: str = "") -> None:
    sql = """
    insert into job_runs (job_name, status, message)
    values (%s, %s, %s)
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (job_name, status, message))
        conn.commit()
