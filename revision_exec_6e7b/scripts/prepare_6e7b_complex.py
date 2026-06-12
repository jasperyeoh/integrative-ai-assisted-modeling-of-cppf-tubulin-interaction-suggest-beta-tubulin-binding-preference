#!/usr/bin/env python3
"""Align Protenix 6E7B sample_0 to 6E7B.pdb; export protein + CPPF (no cofactors)."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

AA3 = {
    "ALA", "ARG", "ASN", "ASP", "CYS", "GLU", "GLN", "GLY", "HIS", "ILE", "LEU", "LYS",
    "MET", "PHE", "PRO", "SER", "THR", "TRP", "TYR", "VAL", "HID", "HIE", "HIP", "CYX",
}
LIGAND_RESNAMES = {"l01", "CPP", "UNL", "MOL"}
SKIP_RESNAMES = {"GTP", "GDP", "G2P", "MG", "HOH", "WAT"}
# Protenix chain A/B map to opposite chains in 6E7B.pdb (verified via atom serials).
PROTENIX_TO_TEMPLATE_CHAIN = {"A": "B", "B": "A"}
TEMPLATE_TO_OUTPUT_CHAIN = {"A": "A", "B": "B"}


def parse_cif_atoms(cif_path: Path) -> list[dict]:
    lines = cif_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    in_loop = False
    headers: list[str] = []
    atoms: list[dict] = []
    for line in lines:
        if line.startswith("loop_"):
            in_loop = False
            headers = []
            continue
        if line.startswith("_atom_site."):
            in_loop = True
            headers.append(line.split(".", 1)[1].strip())
            continue
        if not in_loop or not headers or line.startswith("#") or line.startswith("_"):
            if headers and (line.startswith("loop_") or line.startswith("data_")):
                in_loop = False
                headers = []
            continue
        if line.startswith(("ATOM", "HETATM")):
            parts = line.split()
            if len(parts) < len(headers):
                continue
            rec = dict(zip(headers, parts[: len(headers)], strict=False))
            rec["group_PDB"] = parts[0]
            atoms.append(rec)
    return atoms


def cif_record_to_pdb_atom(rec: dict, serial: int) -> str:
    group = rec.get("group_PDB", "ATOM")
    name = rec.get("auth_atom_id") or rec.get("label_atom_id", "")
    if len(name) < 4 and name and name[0].isdigit():
        name = f" {name}"
    elif len(name) < 4:
        name = f" {name:<3}"[:4]
    resn = (rec.get("auth_comp_id") or rec.get("label_comp_id", "UNK"))[:3]
    chain = (rec.get("auth_asym_id") or rec.get("label_asym_id") or "A")[:1]
    try:
        resi = int(float(rec.get("auth_seq_id") or rec.get("label_seq_id") or "1"))
    except ValueError:
        resi = 1
    x = float(rec.get("Cartn_x", 0))
    y = float(rec.get("Cartn_y", 0))
    z = float(rec.get("Cartn_z", 0))
    elem = (rec.get("type_symbol") or name.strip()[:1] or "C")[:2].strip().rjust(2)
    return (
        f"{group:<6}{serial:5d} {name:<4} {resn:>3} {chain}{resi:4d}   "
        f"{x:8.3f}{y:8.3f}{z:8.3f}  1.00  0.00           {elem:>2}\n"
    )


def parse_pdb_atoms(path: Path) -> list[dict]:
    atoms = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            if not line.startswith(("ATOM", "HETATM")):
                continue
            atoms.append(
                {
                    "line": line,
                    "name": line[12:16].strip(),
                    "resn": line[17:20].strip(),
                    "chain": line[21:22],
                    "resi": int(line[22:26]),
                    "x": float(line[30:38]),
                    "y": float(line[38:46]),
                    "z": float(line[46:54]),
                }
            )
    return atoms


def key_ca(a: dict) -> tuple:
    return (a["chain"], a["resi"], a["resn"])


def centroid(points: list[list[float]]) -> list[float]:
    n = len(points)
    return [sum(p[i] for p in points) / n for i in range(3)]


def mat_mul_vec(m, v):
    return [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]


def kabsch(P, Q):
    import numpy as np

    Pm = np.array(P, dtype=float)
    Qm = np.array(Q, dtype=float)
    H = Pm.T @ Qm
    U, S, Vt = np.linalg.svd(H)
    R = Vt.T @ U.T
    if np.linalg.det(R) < 0:
        Vt[2, :] *= -1
        R = Vt.T @ U.T
    return R.tolist()


def ca_rmsd(P, Q) -> float:
    import numpy as np

    d = np.array(P, dtype=float) - np.array(Q, dtype=float)
    return float(np.sqrt((d * d).sum(axis=1).mean()))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cif", required=True, type=Path)
    ap.add_argument("--template", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    cif_atoms = parse_cif_atoms(args.cif)
    t_atoms = parse_pdb_atoms(args.template)

    pose_protein = [
        a for a in cif_atoms
        if a.get("group_PDB") == "ATOM"
        and (a.get("auth_comp_id") or a.get("label_comp_id", "")) in AA3
        and (a.get("auth_asym_id") or "A") in ("A", "B")
    ]
    pose_ligand = [
        a for a in cif_atoms
        if (a.get("auth_comp_id") or a.get("label_comp_id", "")) in LIGAND_RESNAMES
    ]

    def pose_ca_dict(records):
        out = {}
        for r in records:
            if (r.get("label_atom_id") or r.get("auth_atom_id") or "").strip() != "CA":
                continue
            resn = r.get("auth_comp_id") or r.get("label_comp_id", "")
            if resn not in AA3:
                continue
            p_chain = (r.get("auth_asym_id") or r.get("label_asym_id") or "A")[:1]
            if p_chain not in PROTENIX_TO_TEMPLATE_CHAIN:
                continue
            t_chain = PROTENIX_TO_TEMPLATE_CHAIN[p_chain]
            resi = int(float(r.get("auth_seq_id") or r.get("label_seq_id") or "0"))
            key = (t_chain, resi, resn)
            out[key] = [float(r["Cartn_x"]), float(r["Cartn_y"]), float(r["Cartn_z"])]
        return out

    p_ca = pose_ca_dict(pose_protein)
    t_ca = {key_ca(a): [a["x"], a["y"], a["z"]] for a in t_atoms if a["name"] == "CA" and a["resn"] in AA3}
    common = sorted(set(p_ca) & set(t_ca))
    if len(common) < 50:
        sys.exit(f"Too few common CA anchors: {len(common)}")

    # Per-chain rigid transforms (handles dimer chains independently).
    chain_transforms: dict[str, tuple[list[float], list[list[float]]]] = {}
    for t_chain in ("A", "B"):
        keys = [k for k in common if k[0] == t_chain]
        if len(keys) < 25:
            sys.exit(f"Too few CA anchors on chain {t_chain}: {len(keys)}")
        P = [p_ca[k] for k in keys]
        Q = [t_ca[k] for k in keys]
        cP = centroid(P)
        cQ = centroid(Q)
        P0 = [[p[0] - cP[0], p[1] - cP[1], p[2] - cP[2]] for p in P]
        Q0 = [[q[0] - cQ[0], q[1] - cQ[1], q[2] - cQ[2]] for q in Q]
        R = kabsch(P0, Q0)
        chain_transforms[t_chain] = (cP, R, cQ)

    def transform_xyz(x: float, y: float, z: float, p_chain: str) -> tuple[float, float, float]:
        t_chain = PROTENIX_TO_TEMPLATE_CHAIN[p_chain]
        cP, R, cQ = chain_transforms[t_chain]
        v = [x - cP[0], y - cP[1], z - cP[2]]
        rv = mat_mul_vec(R, v)
        return rv[0] + cQ[0], rv[1] + cQ[1], rv[2] + cQ[2]

    transformed = []
    for r in cif_atoms:
        comp = r.get("auth_comp_id") or r.get("label_comp_id", "")
        chain = (r.get("auth_asym_id") or r.get("label_asym_id") or "A")[:1]
        if comp in SKIP_RESNAMES:
            continue
        if r.get("group_PDB") == "ATOM" and comp in AA3 and chain in PROTENIX_TO_TEMPLATE_CHAIN:
            pass
        elif comp in LIGAND_RESNAMES:
            # Ligand follows beta chain (Protenix B -> template A).
            chain = "B"
        else:
            continue
        x, y, z = transform_xyz(float(r["Cartn_x"]), float(r["Cartn_y"]), float(r["Cartn_z"]), chain)
        nr = dict(r)
        nr["Cartn_x"] = f"{x:.3f}"
        nr["Cartn_y"] = f"{y:.3f}"
        nr["Cartn_z"] = f"{z:.3f}"
        if comp in LIGAND_RESNAMES:
            nr["auth_comp_id"] = "l01"
            nr["label_comp_id"] = "l01"
            nr["auth_asym_id"] = "C"
            nr["label_asym_id"] = "C"
        elif r.get("group_PDB") == "ATOM":
            t_chain = PROTENIX_TO_TEMPLATE_CHAIN[chain]
            out_chain = TEMPLATE_TO_OUTPUT_CHAIN[t_chain]
            nr["auth_asym_id"] = out_chain
            nr["label_asym_id"] = out_chain
        transformed.append(nr)

    P_after = []
    Q_after = []
    for k in common:
        out_chain, resi, resn = k
        for r in transformed:
            if (r.get("label_atom_id") or "").strip() != "CA":
                continue
            if (r.get("auth_asym_id") or "A")[:1] != out_chain:
                continue
            if r.get("auth_comp_id") != resn:
                continue
            if int(float(r.get("auth_seq_id") or "0")) != resi:
                continue
            P_after.append([float(r["Cartn_x"]), float(r["Cartn_y"]), float(r["Cartn_z"])])
            Q_after.append(t_ca[k])
            break
    rmsd = ca_rmsd(P_after, Q_after)
    print(f"CA RMSD after alignment: {rmsd:.3f} Å")

    protein = [r for r in transformed if r.get("group_PDB") == "ATOM"]
    ligand = [r for r in transformed if (r.get("auth_comp_id") or "") == "l01"]
    out_records = protein + ligand

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        for i, rec in enumerate(out_records, start=1):
            f.write(cif_record_to_pdb_atom(rec, i))
        f.write("END\n")
    print(f"Wrote {args.out} ({len(protein)} protein + {len(ligand)} ligand atoms, no cofactors)")


if __name__ == "__main__":
    main()
