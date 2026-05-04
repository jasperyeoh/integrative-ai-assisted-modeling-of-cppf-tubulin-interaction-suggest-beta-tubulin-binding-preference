"""Shared .xvg parsing for revision Step 3 plotting scripts (two leading numeric columns)."""
from __future__ import annotations

from pathlib import Path

import numpy as np


def read_xvg_xy(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """Parse first two numeric columns; skip blank, #, @, & lines."""
    t_list: list[float] = []
    y_list: list[float] = []
    with path.open() as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith(("#", "@", "&")):
                continue
            parts = s.split()
            if len(parts) < 2:
                continue
            try:
                t_list.append(float(parts[0]))
                y_list.append(float(parts[1]))
            except ValueError:
                continue
    if not t_list:
        raise ValueError(f"No numeric rows parsed from {path}")
    return np.asarray(t_list), np.asarray(y_list)


def window_mask(t: np.ndarray, t0: float, t1: float) -> np.ndarray:
    return (t >= t0) & (t <= t1) & np.isfinite(t)


def window_stats(t: np.ndarray, y: np.ndarray, t0: float, t1: float) -> dict[str, float]:
    m = window_mask(t, t0, t1) & np.isfinite(y)
    yy = y[m]
    if yy.size == 0:
        return {
            "n": 0.0,
            "mean": float("nan"),
            "std": float("nan"),
            "p25": float("nan"),
            "p50": float("nan"),
            "p75": float("nan"),
        }
    return {
        "n": float(yy.size),
        "mean": float(np.mean(yy)),
        "std": float(np.std(yy, ddof=1)) if yy.size > 1 else 0.0,
        "p25": float(np.percentile(yy, 25)),
        "p50": float(np.percentile(yy, 50)),
        "p75": float(np.percentile(yy, 75)),
    }


def mean_std_vector(y: np.ndarray) -> tuple[float, float]:
    """Scalar mean/std over a 1D array (e.g. RMSF vs residue)."""
    yy = y[np.isfinite(y)]
    if yy.size == 0:
        return float("nan"), float("nan")
    if yy.size == 1:
        return float(yy[0]), 0.0
    return float(np.mean(yy)), float(np.std(yy, ddof=1))
