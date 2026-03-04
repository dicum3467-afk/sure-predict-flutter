from __future__ import annotations
import hashlib
import json
import os
from typing import Any, Optional

REDIS_URL = os.getenv("REDIS_URL", "").strip()

redis_client = None
redis_ok = False

if REDIS_URL:
    try:
        import redis  # type: ignore

        redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2)
        redis_client.ping()
        redis_ok = True
    except Exception:
        redis_client = None
        redis_ok = False


def _hash(s: str) -> str:
    return hashlib.sha1(s.encode("utf-8")).hexdigest()


def build_cache_key(prefix: str, payload: dict) -> str:
    # chei scurte + stabile
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return f"{prefix}:{_hash(raw)}"


def cache_get(key: str) -> Optional[Any]:
    if not redis_client:
        return None
    v = redis_client.get(key)
    if not v:
        return None
    try:
        return json.loads(v)
    except Exception:
        return None


def cache_set(key: str, value: Any, ttl_seconds: int = 60) -> None:
    if not redis_client:
        return
    redis_client.setex(key, ttl_seconds, json.dumps(value, separators=(",", ":")))
