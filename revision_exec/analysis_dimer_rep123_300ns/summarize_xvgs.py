#!/usr/bin/env python3
"""Parse GROMACS xvg outputs and compute summary stats + extension-style diagnostics."""
from __future__ import annotations

import math
import re
from pathlib import Path

BASE = Path(__file__).resolve().parent


def read_xy(xvg: Path) -> tuple[list[float], list[float]]:
    xs: list[float] = []
    ys: list[float] = []
    with xvg.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(("#", "@")):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            try:
                xs.append(float(parts[0]))
                ys.append(float(parts[1]))
            except ValueError:
                continue
    return xs, ys


def stats(y: list[float]) -> tuple[float, float]:
    if not y:
        return float("nan"), float("nan")
    m = sum(y) / len(y)
    v = sum((x - m) ** 2 for x in y) / max(len(y) - 1, 1)
    return m, math.sqrt(v)


def window_mask(xs: list[float], t0: float, t1: float) -> list[bool]:
    return [t0 <= x <= t1 for x in xs]


def subset(xs: list[float], ys: list[float], mask: list[bool]) -> list[float]:
    return [y for x, y, m in zip(xs, ys, mask) if m]


def rolling_mean(ys: list[float], win: int, step: int = 1) -> list[float]:
    if win <= 0 or len(ys) < win:
        return []
    out: list[float] = []
    for i in range(0, len(ys) - win + 1, step):
        chunk = ys[i : i + win]
        out.append(sum(chunk) / len(chunk))
    return out


def rmsf_top10(xvg: Path) -> str:
    xs, ys = read_xy(xvg)
    pairs = sorted(zip(xs, ys), key=lambda p: -p[1])[:10]
    return ", ".join(f"{int(r)}:{v:.3f}" for r, v in pairs)


def block_contact_shift(xs: list[float], ys: list[float]) -> tuple[list[tuple[str, float]], float | None]:
    """50 ns blocks; return block means and pct change last vs previous block."""
    blocks = [
        ("0-50", 0, 50),
        ("50-100", 50, 100),
        ("100-150", 100, 150),
        ("150-200", 150, 200),
        ("200-250", 200, 250),
        ("250-300", 250, 300),
    ]
    means: list[tuple[str, float]] = []
    for name, a, b in blocks:
        m = subset(xs, ys, window_mask(xs, a, b))
        means.append((name, stats(m)[0] if m else float("nan")))
    last = means[-1][1]
    prev = means[-2][1]
    if prev and not math.isnan(prev) and prev != 0:
        pct = 100.0 * abs(last - prev) / abs(prev)
    else:
        pct = None
    return means, pct


def plateau_rolling(bb_x: list[float], bb_y: list[float], win_ns: float = 20.0) -> dict:
    """Rolling mean of backbone RMSD; dt assumed 0.01 ns (10 ps)."""
    dt = 0.01
    win = max(1, int(round(win_ns / dt)))
    rm = rolling_mean(bb_y, win, step=max(1, win // 10))
    if len(rm) < 2:
        return {"win_frames": win, "rolling_std_all": float("nan"), "rolling_std_last100ns": float("nan")}
    rstd_all = stats(rm)[1]
    # Approximate index for last 100 ns of rolling series (aligned to end of traj)
    n_tail = max(1, int(round(100.0 / win_ns)))
    tail = rm[-n_tail:]
    rstd_tail = stats(tail)[1] if tail else float("nan")
    return {
        "win_frames": win,
        "rolling_mean_last": rm[-1] if rm else float("nan"),
        "rolling_std_all": rstd_all,
        "rolling_std_tail100ns": rstd_tail,
    }


def summarize_rep(rep: str) -> str:
    d = BASE / rep
    lines: list[str] = []
    xvgs = {
        "rmsd_backbone": d / "rmsd_backbone.xvg",
        "rmsd_ligand": d / "rmsd_ligand.xvg",
        "rg_protein": d / "rg_protein.xvg",
        "sasa_protein": d / "sasa_protein.xvg",
        "mindist": d / "mindist_protein_ligand.xvg",
        "contacts": d / "contacts_protein_ligand.xvg",
    }
    lines.append(f"## {rep}")
    for key, path in xvgs.items():
        if not path.exists():
            lines.append(f"- **{key}**: MISSING `{path.name}`")
            continue
        xs, ys = read_xy(path)
        if not ys:
            lines.append(f"- **{key}**: empty")
            continue
        mu, sd = stats(ys)
        m50 = subset(xs, ys, window_mask(xs, 250, 300))
        mu50, sd50 = stats(m50) if m50 else (float("nan"), float("nan"))
        unit = "nm" if "sasa" not in key else "nm^2"
        if key == "contacts":
            unit = "count"
        lines.append(
            f"- **{key}**: full mean={mu:.4f} std={sd:.4f}; "
            f"last point={ys[-1]:.4f}; last 50 ns mean={mu50:.4f} std={sd50:.4f} ({unit})"
        )

    rmsf_path = d / "rmsf_ca.xvg"
    if rmsf_path.exists():
        lines.append(f"- **RMSF Cα top-10 (nm)**: {rmsf_top10(rmsf_path)}")

    bb_x, bb_y = read_xy(d / "rmsd_backbone.xvg")
    cx, cy = read_xy(d / "contacts_protein_ligand.xvg")
    if bb_x and bb_y:
        plat = plateau_rolling(bb_x, bb_y, 20.0)
        lines.append(
            f"- **Backbone RMSD rolling 20 ns**: last rolling mean={plat['rolling_mean_last']:.4f} nm; "
            f"σ(rolling mean) all={plat['rolling_std_all']:.4f}; σ tail≈last 100 ns={plat['rolling_std_tail100ns']:.4f}"
        )
    if cx and cy:
        bmeans, pct = block_contact_shift(cx, cy)
        btxt = "; ".join(f"{n}:{v:.1f}" for n, v in bmeans)
        lines.append(f"- **Contacts by 50 ns block (mean)**: {btxt}")
        if pct is not None:
            lines.append(f"- **|Δmean| contacts (200–250 → 250–300 ns)**: {pct:.1f}% of previous block mean")

    return "\n".join(lines)


def main() -> None:
    chunks = [summarize_rep(r) for r in ("rep1", "rep2", "rep3")]
    print("\n\n".join(chunks))


if __name__ == "__main__":
    main()
