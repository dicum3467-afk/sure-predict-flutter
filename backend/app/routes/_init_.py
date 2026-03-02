# backend/app/routes/__init__.py
"""
Package pentru toate routerele FastAPI.

Folosește importuri explicite ca să fie clar ce există în proiect.
"""
from __future__ import annotations

from . import fixtures_sync  # noqa: F401
# când mai adaugi fișiere noi:
# from . import leagues  # noqa: F401
# from . import predictions  # noqa: F401
