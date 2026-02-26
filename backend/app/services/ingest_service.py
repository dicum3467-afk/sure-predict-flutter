import os
import httpx
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from app.db import SessionLocal
from app.models import Fixture  # dacă modelul tău se numește altfel îmi spui

API_KEY = os.getenv("API_FOOTBALL_KEY")
BASE_URL = "https://v3.football.api-sports.io"


async def ingest_upcoming(days: int = 7):
    """
    Importă meciuri din următoarele X zile
    """
    headers = {
        "x-apisports-key": API_KEY,
    }

    date_from = datetime.utcnow().date()
    date_to = date_from + timedelta(days=days)

    url = (
        f"{BASE_URL}/fixtures"
        f"?from={date_from}"
        f"&to={date_to}"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()

    db: Session = SessionLocal()

    try:
        for item in data.get("response", []):
            fix = item["fixture"]
            teams = item["teams"]
            league = item["league"]

            exists = (
                db.query(Fixture)
                .filter(Fixture.provider_fixture_id == str(fix["id"]))
                .first()
            )

            if exists:
                continue

            new_row = Fixture(
                provider_fixture_id=str(fix["id"]),
                home=teams["home"]["name"],
                away=teams["away"]["name"],
                kickoff=fix["date"],
                status="scheduled",
                league_name=league["name"],
            )

            db.add(new_row)

        db.commit()

    finally:
        db.close()
