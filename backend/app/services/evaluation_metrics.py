from __future__ import annotations

import math
from typing import Dict, List, Tuple


def _clamp(p: float, eps: float = 1e-6) -> float:
    return max(eps, min(1.0 - eps, p))


def brier_binary(preds: List[float], labels: List[int]) -> float:
    if not preds:
        return 0.0
    s = 0.0
    for p, y in zip(preds, labels):
        p = _clamp(float(p))
        s += (p - float(y)) ** 2
    return s / len(preds)


def logloss_binary(preds: List[float], labels: List[int]) -> float:
    if not preds:
        return 0.0
    s = 0.0
    for p, y in zip(preds, labels):
        p = _clamp(float(p))
        y = int(y)
        s += -(y * math.log(p) + (1 - y) * math.log(1.0 - p))
    return s / len(preds)


def accuracy_from_probs(probs_list: List[Dict[str, float]], true_labels: List[str]) -> float:
    if not probs_list:
        return 0.0
    ok = 0
    for probs, y in zip(probs_list, true_labels):
        pred = max(probs.keys(), key=lambda k: probs[k])
        ok += 1 if pred == y else 0
    return ok / len(probs_list)


def brier_multiclass(probs_list: List[Dict[str, float]], true_labels: List[str]) -> float:
    """
    Multiclass Brier: mean over samples of sum_k (p_k - y_k)^2
    """
    if not probs_list:
        return 0.0
    s = 0.0
    keys = list(probs_list[0].keys())
    for probs, y in zip(probs_list, true_labels):
        for k in keys:
            p = _clamp(float(probs.get(k, 0.0)))
            t = 1.0 if k == y else 0.0
            s += (p - t) ** 2
    return s / len(probs_list)


def logloss_multiclass(probs_list: List[Dict[str, float]], true_labels: List[str]) -> float:
    if not probs_list:
        return 0.0
    s = 0.0
    for probs, y in zip(probs_list, true_labels):
        p = _clamp(float(probs.get(y, 1e-6)))
        s += -math.log(p)
    return s / len(probs_list)
