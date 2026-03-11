from app.db import get_conn


def log_job(job_name: str, status: str, details: str = ""):
    sql = """
        insert into job_runs (job_name, status, details)
        values (%s, %s, %s)
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (job_name, status, details))

        conn.commit()
