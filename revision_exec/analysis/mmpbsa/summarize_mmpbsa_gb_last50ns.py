#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path
from statistics import mean, stdev


@dataclass(frozen=True)
class DeltaStats:
    avg: float
    sd: float


DELTA_KEYS = ("ΔVDWAALS", "ΔEEL", "ΔEGB", "ΔESURF", "ΔTOTAL")


def _parse_float(s: str) -> float:
    s = s.strip()
    if s.lower() == "nan":
        return float("nan")
    return float(s)


def parse_final_results(path: Path) -> dict[str, DeltaStats]:
    """Parse gmx_MMPBSA FINAL_RESULTS file and return delta avg + SD (SD column, not SD(Prop.))."""
    txt = path.read_text(errors="replace").splitlines()
    in_delta = False
    out: dict[str, DeltaStats] = {}

    for line in txt:
        if line.startswith("Delta (Complex - Receptor - Ligand):"):
            in_delta = True
            continue
        if not in_delta:
            continue
        if not line.strip():
            continue
        if line.startswith("Δ"):
            parts = line.split()
            if len(parts) < 4:
                continue
            key = parts[0]
            if key not in DELTA_KEYS:
                # Skip terms like "Δ1-4 VDW" whose key is split across tokens.
                continue
            avg = _parse_float(parts[1])
            sd = _parse_float(parts[3])
            out[key] = DeltaStats(avg=avg, sd=sd)

    missing = [k for k in DELTA_KEYS if k not in out]
    if missing:
        raise ValueError(f"Missing delta terms {missing} in {path}")
    return out


def safe_stdev(xs: list[float]) -> float:
    xs2 = [x for x in xs if not math.isnan(x)]
    if len(xs2) < 2:
        return float("nan")
    return float(stdev(xs2))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rep1", required=True, type=Path)
    ap.add_argument("--rep2", required=True, type=Path)
    ap.add_argument("--rep3", required=True, type=Path)
    ap.add_argument("--out-csv", required=True, type=Path)
    ap.add_argument("--n-frames", type=int, default=51)
    args = ap.parse_args()

    reps = {
        "rep1": parse_final_results(args.rep1),
        "rep2": parse_final_results(args.rep2),
        "rep3": parse_final_results(args.rep3),
    }

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "replicate",
                "n_frames",
                "delta_vdw_avg_kcal_mol",
                "delta_vdw_sd_kcal_mol",
                "delta_eel_avg_kcal_mol",
                "delta_eel_sd_kcal_mol",
                "delta_egb_avg_kcal_mol",
                "delta_egb_sd_kcal_mol",
                "delta_esurf_avg_kcal_mol",
                "delta_esurf_sd_kcal_mol",
                "delta_total_avg_kcal_mol",
                "delta_total_sd_kcal_mol",
            ]
        )

        for rep, d in reps.items():
            w.writerow(
                [
                    rep,
                    args.n_frames,
                    d["ΔVDWAALS"].avg,
                    d["ΔVDWAALS"].sd,
                    d["ΔEEL"].avg,
                    d["ΔEEL"].sd,
                    d["ΔEGB"].avg,
                    d["ΔEGB"].sd,
                    d["ΔESURF"].avg,
                    d["ΔESURF"].sd,
                    d["ΔTOTAL"].avg,
                    d["ΔTOTAL"].sd,
                ]
            )

        tot_avgs = [reps[r]["ΔTOTAL"].avg for r in ("rep1", "rep2", "rep3")]
        w.writerow([])
        w.writerow(["aggregate_across_reps", "", "mean_of_rep_avgs", "sd_of_rep_avgs"])
        w.writerow(["ΔTOTAL", "", float(mean(tot_avgs)), safe_stdev(tot_avgs)])


if __name__ == "__main__":
    main()

