from fastapi import FastAPI, HTTPException
from app.routes.leagues import router as leagues_router
from app.db import get_conn

app = FastAPI(
    title="Sure Predict Backend",
    version="0.1.0"
)

# Include routers
app.include_router(leagues_router)


# Health check
@app.get("/health")
def health():
    return {"status": "ok"}


# Get prediction by provider_fixture_id
@app.get("/fixtures/{provider_fixture_id}/prediction")
async def get_prediction(provider_fixture_id: str, run_type: str = "initial"):

    sql = """
        select
            f.provider_fixture_id,
            pr.run_type,
            pr.computed_at,
            pm.p_home,
            pm.p_draw,
            pm.p_away,
            pm.p_gg,
            pm.p_over25,
            pm.p_under25
        from public.prediction_runs pr
        join public.fixtures f on f.id = pr.fixture_id
        join public.prediction_markets pm on pm.prediction_run_id = pr.id
        where f.provider_fixture_id = $1
          and pr.run_type = $2
        order by pr.computed_at desc
        limit 1;
    """

    conn = await get_conn()
    row = await conn.fetchrow(sql, provider_fixture_id, run_type)

    if not row:
        raise HTTPException(status_code=404, detail="Prediction not found")

    return dict(row)
