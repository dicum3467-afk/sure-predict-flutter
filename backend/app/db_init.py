from app.db import Base, engine

# importă modelele ca să fie înregistrate în Base.metadata
from app.models import Fixture  # noqa: F401


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
