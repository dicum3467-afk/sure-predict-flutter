from sqlalchemy import Column, Integer, String, Boolean, DateTime, JSON, UniqueConstraint
from sqlalchemy.sql import func

from app.db import Base


class Fixture(Base):
    __tablename__ = "fixtures"

    id = Column(Integer, primary_key=True, index=True)

    # ID-ul meciului din API-Football
    fixture_id = Column(Integer, nullable=False, index=True)

    league_id = Column(Integer, nullable=True, index=True)
    season = Column(Integer, nullable=True, index=True)

    # "2024-08-16T19:00:00+00:00" -> păstrăm ca string în raw, dar și datetime separat dacă vrei
    date_utc = Column(DateTime(timezone=True), nullable=True)

    status_short = Column(String(10), nullable=True, index=True)  # NS/FT/1H/HT etc

    home_team_id = Column(Integer, nullable=True, index=True)
    away_team_id = Column(Integer, nullable=True, index=True)

    home_team_name = Column(String(120), nullable=True)
    away_team_name = Column(String(120), nullable=True)

    home_goals = Column(Integer, nullable=True)
    away_goals = Column(Integer, nullable=True)

    # Păstrăm payload complet ca JSON (super util pentru debug / extra câmpuri)
    raw = Column(JSON, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("fixture_id", name="uq_fixtures_fixture_id"),
    )
