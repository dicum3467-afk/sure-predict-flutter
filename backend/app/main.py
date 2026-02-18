from fastapi import FastAPI, HTTPException
frfrom app.routes.leagues import router as leagues_routerom app.db import get_conn

app = FastAPI(title="Sure Predict Backend", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/fixtures/{provider_fixture_id}/prediction")
def get_prediction(provider_fixture_id: str, run_type: str = "initial"):
    sql = """
    select
      f.provider_fixture_id,
      pr.run_type,
      pr.computed_at,
      pm.p_home, pm.p_draw, pm.p_away,
      pm.p_gg, pm.p_over25, pm.p_under25
    from prediction_runs pr
    join fixtures f on f.id = pr.fixture_id
    join prediction_markets pm on pm.prediction_run_id = pr.id
    where f.provider_fixture_id = %s
      and pr.run_type = %s
    limit 1;
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (provider_fixture_id, run_type))
            row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Prediction not found")

    return row
