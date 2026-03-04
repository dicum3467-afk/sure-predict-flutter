from __future__ import annotations
import os
from typing import Optional

from rq import Queue

REDIS_URL = os.getenv("REDIS_URL", "").strip()

redis_conn = None
queue: Optional[Queue] = None

if REDIS_URL:
    import redis  # type: ignore

    redis_conn = redis.Redis.from_url(REDIS_URL, decode_responses=True)
    queue = Queue(name=os.getenv("RQ_QUEUE", "default"), connection=redis_conn, default_timeout=900)  # 15 min
