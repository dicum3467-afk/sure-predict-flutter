from sqlalchemy import BigInteger, Integer, String, DateTime, JSON, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

class Fixture(Base):
    __tablename__ = "fixtures"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # ID-ul fixture-ului de la API-Football (unic)
    fixture_id: Mapped[int] = mapped_column(Integer, nullable=False)

    league_id: Mapped[int] = mapped_column(Integer, nullable=False)
    season: Mapped[int] = mapped_column(Integer, nullable=False)

    utc_date: Mapped[str | None] = mapped_column(String, nullable=True)  # ex: "2024-08-16T19:00:00+00:00"
    timestamp: Mapped[int | None] = mapped_column(BigInteger, nullable=True)

    status_short: Mapped[str | None] = mapped_column(String, nullable=True)  # NS/FT/1H etc
    home_team: Mapped[str | None] = mapped_column(String, nullable=True)
    away_team: Mapped[str | None] = mapped_column(String, nullable=True)

    payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)

    __table_args__ = (
        UniqueConstraint("fixture_id", name="uq_fixtures_fixture_id"),
    )
