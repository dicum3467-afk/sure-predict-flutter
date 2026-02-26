from sqlalchemy import Column, Integer, String, BigInteger, DateTime, JSON, UniqueConstraint
from sqlalchemy.sql import func

from app.db import Base


class Fixture(Base):
    __tablename__ = "fixtures"

    id = Column(Integer, primary_key=True, index=True)

    # id-ul oficial din API-Football
    fixture_id = Column(Integer, nullable=False, index=True)

    league_id = Column(Integer, nullable=False, index=True)
    season = Column(Integer, nullable=False, index=True)

    # data utc (string ISO din API) o păstrăm ca string simplu (merge ok)
    utc_date = Column(String, nullable=True)

    # unix timestamp
    timestamp = Column(BigInteger, nullable=True)

    # NS / FT / 1H / HT / 2H etc
    status_short = Column(String, nullable=True, index=True)

    home_team = Column(String, nullable=True)
    away_team = Column(String, nullable=True)

    # tot json-ul brut din API-Football
    payload = Column(JSON, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("fixture_id", name="uq_fixtures_fixture_id"),
    )
