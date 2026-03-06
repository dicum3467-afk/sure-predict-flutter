from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, List, Tuple, Any


def _sigmoid(z: float) -> float:
    # stable sigmoid
    if z >= 0:
        ez = math.exp(-z)
        return 1.0 / (1.0 + ez)
    ez = math.exp(z)
    return ez / (1.0 + ez)


def _clamp(p: float, eps: float = 1e-6) -> float:
    return max(eps, min(1.0 - eps, p))


@dataclass
class PlattBinary:
    # p_cal = sigmoid(a*logit(p)+b)
    a: float
    b: float

    def apply(self, p: float) -> float:
        p = _clamp(p)
        logit = math.log(p / (1.0 - p))
        return _clamp(_sigmoid(self.a * logit + self.b))


@dataclass
class PlattOVR:
    # one-vs-rest for multiclass using logits; normalize
    a: float
    b: float

    def apply_probs(self, probs: Dict[str, float]) -> Dict[str, float]:
        # apply same (a,b) to each class logit then renormalize
        scores = {}
        for k, p in probs.items():
            p = _clamp(p)
            logit = math.log(p / (1.0 - p))
            scores[k] = _sigmoid(self.a * logit + self.b)
        s = sum(scores.values())
        if s <= 0:
            return probs
        return {k: _clamp(v / s) for k, v in scores.items()}


def fit_platt_binary(
    preds: List[float],
    labels: List[int],
    *,
    lr: float = 0.05,
    steps: int = 700,
    l2: float = 1e-3,
) -> PlattBinary:
    """
    Fit p_cal = sigmoid(a*logit(p)+b) by minimizing logloss.
    preds: list of probabilities (0..1)
    labels: list of 0/1
    """
    assert len(preds) == len(labels) and len(preds) > 0

    a, b = 1.0, 0.0

    for _ in range(steps):
        ga = 0.0
        gb = 0.0
        for p, y in zip(preds, labels):
            p = _clamp(p)
            x = math.log(p / (1.0 - p))  # logit
            q = _sigmoid(a * x + b)
            # d/dw logloss
            ga += (q - y) * x
            gb += (q - y)
        # L2 regularization
        ga += l2 * a
        gb += l2 * b

        a -= lr * ga / len(preds)
        b -= lr * gb / len(preds)

    return PlattBinary(a=a, b=b)


def fit_platt_ovr(
    probs_list: List[Dict[str, float]],
    true_labels: List[str],
    *,
    lr: float = 0.04,
    steps: int = 800,
    l2: float = 1e-3,
) -> PlattOVR:
    """
    Simplified: fit one shared (a,b) applied to each class logit; normalize after.
    This is cheap and usually improves calibration.
    """
    assert len(probs_list) == len(true_labels) and len(probs_list) > 0

    a, b = 1.0, 0.0

    # list of keys from first sample
    keys = list(probs_list[0].keys())

    for _ in range(steps):
        ga = 0.0
        gb = 0.0
        for probs, y_true in zip(probs_list, true_labels):
            # compute per-class "soft" targets (1 for true, 0 rest)
            for k in keys:
                y = 1.0 if k == y_true else 0.0
                p = _clamp(float(probs.get(k, 1.0 / len(keys))))
                x = math.log(p / (1.0 - p))
                q = _sigmoid(a * x + b)
                ga += (q - y) * x
                gb += (q - y)

        ga += l2 * a
        gb += l2 * b
        denom = max(1, len(probs_list) * len(keys))
        a -= lr * ga / denom
        b -= lr * gb / denom

    return PlattOVR(a=a, b=b)


def serialize_calibration(binary: Dict[str, PlattBinary], ovr: PlattOVR | None) -> Dict[str, Any]:
    out = {"binary": {}, "ovr": None}
    for name, model in binary.items():
        out["binary"][name] = {"a": model.a, "b": model.b}
    if ovr is not None:
        out["ovr"] = {"a": ovr.a, "b": ovr.b}
    return out


def load_calibration(params: Dict[str, Any]) -> Tuple[Dict[str, PlattBinary], PlattOVR | None]:
    binary = {}
    b = (params or {}).get("binary") or {}
    for name, v in b.items():
        binary[name] = PlattBinary(a=float(v["a"]), b=float(v["b"]))
    o = (params or {}).get("ovr")
    ovr = None
    if o:
        ovr = PlattOVR(a=float(o["a"]), b=float(o["b"]))
    return binary, ovr
