from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, List

from app.db import get_conn

app = FastAPI(title="Sure Predict Backend", version="0.1.0")

# CORS (poți restrânge ulterior)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
    from public.fixtures f
    join public.prediction_runs pr on pr.fixture_id = f.id
    join public.prediction_markets pm on pm.prediction_run_id = pr.id
    where f.provider_fixture_id = %s
      and pr.run_type = %s
    order by pr.computed_at desc
    limit 1;
    """

    try:
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(sql, (provider_fixture_id, run_type))
                row = cur.fetchone()
        finally:
            conn.close()
    except Exception as e:
        # vezi exact eroarea în Render logs
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    if not row:
        raise HTTPException(status_code=404, detail="Prediction not found")

    return row


@app.get("/leagues")
def get_leagues(active: bool = True):
    sql = """
    select id, provider_league_id, name, country, tier, is_active
    from public.leagues
    where (%s = false) or (is_active = true)
    order by country nulls last, name;
    """

    try:
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(sql, (active,))
                rows = cur.fetchall()
        finally:
            conn.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    return rows


@app.get("/fixtures")
def list_fixtures(
    league_ids: Optional[List[str]] = Query(default=None, description="Repeat param: ?league_ids=uuid&league_ids=uuid"),
    status: Optional[str] = None,
    date_from: Optional[str] = None,  # "2026-02-18"
    date_to: Optional[str] = None,    # "2026-02-25"
    run_type: str = "initial",
    limit: int = 50,
    offset: int = 0,
):
    """
    Listează meciuri + ultimele predicții (pentru run_type dat).
    """
    sql = """
    select
        f.id,
        f.provider_fixture_id,
        f.league_id,
        f.kickoff_at,
        f.status,
        ht.name as home,
        at.name as away,
        pr.run_type,
        pr.computed_at,
        pm.p_home, pm.p_draw, pm.p_away,
        pm.p_gg, pm.p_over25, pm.p_under25
    from public.fixtures f
    join public.teams ht on ht.id = f.home_team_id
    join public.teams at on at.id = f.away_team_id

    left join lateral (
        select pr2.*
        from public.prediction_runs pr2
        where pr2.fixture_id = f.id
          and pr2.run_type = %s
        order by pr2.computed_at desc
        limit 1
    ) pr on true

    left join public.prediction_markets pm
        on pm.prediction_run_id = pr.id

    where 1=1
      and (%s::uuid[] is null or f.league_id = any(%s::uuid[]))
      and (%s is null or f.status = %s)
      and (%s::date is null or f.kickoff_at::date >= %s::date)
      and (%s::date is null or f.kickoff_at::date <= %s::date)

    order by f.kickoff_at asc
    limit %s offset %s;
    """

    # Dacă league_ids nu vine, trimitem NULL (ca să treacă condiția)
    leagues_param = league_ids if league_ids else None

    params = (
        run_type,
        leagues_param, leagues_param,
        status, status,
        date_from, date_from,
        date_to, date_to,
        limit, offset,
    )

    try:
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()
        finally:
            conn.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    return rows
