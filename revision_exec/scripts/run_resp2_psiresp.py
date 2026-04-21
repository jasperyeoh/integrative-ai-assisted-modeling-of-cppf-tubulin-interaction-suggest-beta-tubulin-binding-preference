#!/usr/bin/env python3
import argparse
from pathlib import Path

import psiresp


def write_charges(path: Path, values):
    with path.open("w", encoding="utf-8") as f:
        for v in values:
            f.write(f"{float(v):.8f}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--smiles", required=True)
    ap.add_argument("--base-mol2", required=True)
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--delta", type=float, default=0.5)
    ap.add_argument("--n-processes", type=int, default=8)
    args = ap.parse_args()

    workdir = Path(args.workdir).resolve()
    workdir.mkdir(parents=True, exist_ok=True)

    # Build molecule and a single conformer/orientation from SMILES.
    mol = psiresp.Molecule.from_smiles(args.smiles)
    mol.generate_conformers()
    mol.generate_orientations()

    # RESP2 workflow (vacuum + water PCM). Use HF/6-31G* to stay consistent with
    # the standard RESP-style setup used in many Amber workflows.
    vac_qm_opt = psiresp.QMGeometryOptimizationOptions(method="hf", basis="6-31g*")
    vac_qm_esp = psiresp.QMEnergyOptions(method="hf", basis="6-31g*")

    pcm = psiresp.qm.PCMOptions(medium_solver_type="CPCM", medium_solvent="water")
    solv_qm_opt = psiresp.QMGeometryOptimizationOptions(
        method="hf",
        basis="6-31g*",
        pcm_options=pcm,
    )
    solv_qm_esp = psiresp.QMEnergyOptions(
        method="hf",
        basis="6-31g*",
        pcm_options=pcm,
    )

    job = psiresp.RESP2(
        molecules=[mol],
        solvent_qm_optimization_options=solv_qm_opt,
        solvent_qm_esp_options=solv_qm_esp,
        working_directory=workdir / "psiresp_work",
        n_processes=args.n_processes,
    )
    # Override vacuum side options explicitly for reproducibility.
    job.vacuum.qm_optimization_options = vac_qm_opt
    job.vacuum.qm_esp_options = vac_qm_esp

    print("Running psiresp RESP2 workflow...")
    job.run()

    gas = list(job.vacuum.charges)
    water = list(job.solvated.charges)
    mixed = list(job.get_charges(delta=args.delta))

    write_charges(workdir / "charges_gas.txt", gas)
    write_charges(workdir / "charges_water.txt", water)
    write_charges(workdir / "charges_resp2_05.txt", mixed)

    print(f"Wrote {len(mixed)} charges to {workdir}")
    print("gas sum   :", f"{sum(gas):.8f}")
    print("water sum :", f"{sum(water):.8f}")
    print("mixed sum :", f"{sum(mixed):.8f}")


if __name__ == "__main__":
    main()
