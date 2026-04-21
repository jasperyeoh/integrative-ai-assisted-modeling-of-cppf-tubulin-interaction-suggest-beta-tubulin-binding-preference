#!/usr/bin/env python3
"""
Rigidly fit a ligand GRO (with H) onto a pose PDB (often heavy atoms only).

Use case:
- Pose coordinates come from Protenix (ligand residue name `CPP`, chain `C`)
- GAFF2 topology/GRO comes from ACPYPE (ligand has hydrogens)
- We want the ACPYPE ligand (with H) placed into the pose binding site
  using a best-fit transform on the common heavy atoms (matched by atom name).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class Atom:
    name: str
    xyz: np.ndarray  # shape (3,), in Angstrom for PDB and GRO-internal here


def parse_pose_pdb_atoms(pdb_path: Path, *, resname: str, chain: str) -> list[Atom]:
    atoms: list[Atom] = []
    with pdb_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue
            if len(line) < 54:
                continue
            line_resn = line[17:20].strip()
            line_chain = line[21:22].strip()
            if line_resn != resname or line_chain != chain:
                continue
            name = line[12:16].strip()
            x = float(line[30:38])
            y = float(line[38:46])
            z = float(line[46:54])
            atoms.append(Atom(name=name, xyz=np.array([x, y, z], dtype=float)))
    if not atoms:
        raise SystemExit(f"No atoms found for {resname} chain {chain} in {pdb_path}")
    return atoms


def parse_ligand_gro_atoms(gro_path: Path) -> tuple[str, list[str], np.ndarray, str]:
    """
    Returns: (title, atom_lines, xyz_A, box_line)
    - atom_lines: raw lines for atoms (will be rewritten with new coords)
    - xyz_A: coordinates in Angstrom, shape (N,3)
    """
    lines = gro_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if len(lines) < 3:
        raise SystemExit(f"Invalid GRO (too short): {gro_path}")
    title = lines[0]
    try:
        n = int(lines[1].strip())
    except ValueError as e:
        raise SystemExit(f"Invalid GRO atom count line: {gro_path}: {e}")
    atom_lines = lines[2 : 2 + n]
    if len(atom_lines) != n:
        raise SystemExit(f"Invalid GRO atom lines: expected {n}, got {len(atom_lines)}")
    box_line = lines[2 + n] if len(lines) > 2 + n else ""

    xyz_nm = []
    names = []
    for ln in atom_lines:
        # fixed width: resnr(5) resname(5) atomname(5) atomnr(5) x(8) y(8) z(8)
        name = ln[10:15].strip()
        x = float(ln[20:28])
        y = float(ln[28:36])
        z = float(ln[36:44])
        names.append(name)
        xyz_nm.append([x, y, z])
    xyz_nm = np.asarray(xyz_nm, dtype=float)
    xyz_A = xyz_nm * 10.0
    return title, atom_lines, np.asarray(names, dtype=object), xyz_A, box_line


def kabsch(P: np.ndarray, Q: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Find rotation R and translation t that best maps P -> Q (both Nx3),
    minimizing RMSD. Returns (R, t) such that: P @ R + t ≈ Q
    """
    Pc = P.mean(axis=0)
    Qc = Q.mean(axis=0)
    P0 = P - Pc
    Q0 = Q - Qc
    C = P0.T @ Q0
    V, S, Wt = np.linalg.svd(C)
    d = np.sign(np.linalg.det(V @ Wt))
    D = np.diag([1.0, 1.0, d])
    R = V @ D @ Wt
    t = Qc - Pc @ R
    return R, t


def rewrite_gro_atom_lines(atom_lines: list[str], xyz_A_new: np.ndarray) -> list[str]:
    xyz_nm = xyz_A_new / 10.0
    out = []
    for ln, (x, y, z) in zip(atom_lines, xyz_nm, strict=True):
        # preserve everything except xyz columns
        prefix = ln[:20]
        out.append(f"{prefix}{x:8.3f}{y:8.3f}{z:8.3f}{ln[44:]}")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pose-pdb", required=True, type=Path)
    ap.add_argument("--pose-resname", default="CPP")
    ap.add_argument("--pose-chain", default="C")
    ap.add_argument("--ligand-gro", required=True, type=Path)
    ap.add_argument("--out-gro", required=True, type=Path)
    ap.add_argument(
        "--fit-heavy-only",
        action="store_true",
        help="Fit using only non-H atoms from ligand GRO (recommended).",
    )
    args = ap.parse_args()

    pose_atoms = parse_pose_pdb_atoms(args.pose_pdb, resname=args.pose_resname, chain=args.pose_chain)
    title, ligand_atom_lines, ligand_names, ligand_xyz_A, _box_line = parse_ligand_gro_atoms(args.ligand_gro)

    pose_by_name = {a.name: a.xyz for a in pose_atoms}

    idx = []
    P = []
    Q = []
    for i, name in enumerate(ligand_names.tolist()):
        if args.fit_heavy_only and name.upper().startswith("H"):
            continue
        if name not in pose_by_name:
            continue
        idx.append(i)
        P.append(ligand_xyz_A[i])
        Q.append(pose_by_name[name])

    if len(P) < 6:
        missing = sorted(set(ligand_names.tolist()) - set(pose_by_name.keys()))
        raise SystemExit(
            "Not enough common atoms to fit.\n"
            f"- common atoms: {len(P)}\n"
            f"- ligand GRO atoms: {len(ligand_names)}\n"
            f"- pose PDB atoms: {len(pose_atoms)}\n"
            f"- missing names (ligand not in pose): {missing[:20]}{'...' if len(missing) > 20 else ''}\n"
        )

    P = np.asarray(P, dtype=float)
    Q = np.asarray(Q, dtype=float)
    R, t = kabsch(P, Q)

    ligand_xyz_A_new = ligand_xyz_A @ R + t
    atom_lines_new = rewrite_gro_atom_lines(ligand_atom_lines, ligand_xyz_A_new)

    args.out_gro.parent.mkdir(parents=True, exist_ok=True)
    out_lines = [title, f"{len(atom_lines_new):5d}", *atom_lines_new, "0.00000   0.00000   0.00000"]
    args.out_gro.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

