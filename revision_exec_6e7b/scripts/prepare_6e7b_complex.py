#!/usr/bin/env python3
"""
Prepare 6E7B CPPF-tubulin complex for MD from Protenix CIF prediction.

Steps:
  1. Parse Protenix CIF sample_0 → extract protein (chains A,B) + CPPF (chain G / l01)
  2. Parse 6E7B.pdb template
  3. Kabsch alignment (CA atoms) of predicted protein onto template
  4. Write merged PDB: protein_A + protein_B + CPPF (renamed to CPP, chain C)

Follows the same protocol as the main-text 5IJ0 preparation
(revision_exec/scripts/prepare_complex_from_pose1.py).
Cofactors (GTP, G2P, MG) are intentionally excluded — they were not
included in the 5IJ0 production topology either.

Usage:
  python prepare_6e7b_complex.py \
    --cif  ../input/protenix_predictions/predictions/protenix_prediction_6E7B_250526_sample_0.cif \
    --template ../input/6E7B.pdb \
    --out ../prep/complex_start.pdb
"""
import argparse
import math
import re


AA3 = {
    "ALA","ARG","ASN","ASP","CYS","GLU","GLN","GLY","HIS","ILE","LEU","LYS",
    "MET","PHE","PRO","SER","THR","TRP","TYR","VAL","HID","HIE","HIP","CYX",
}


# ── CIF parser ──────────────────────────────────────────────────────────────

def parse_cif_atoms(path):
    """Parse mmCIF _atom_site records into list of atom dicts."""
    atoms = []
    in_atom_block = False
    col_names = []

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")

            if line.startswith("_atom_site."):
                in_atom_block = True
                col_name = line.split(".")[1].strip()
                col_names.append(col_name)
                continue

            if in_atom_block and (line.startswith("ATOM") or line.startswith("HETATM")):
                tokens = line.split()
                if len(tokens) < len(col_names):
                    continue
                row = {col_names[i]: tokens[i] for i in range(len(col_names))}
                atoms.append(row)
                continue

            if in_atom_block and not line.startswith("ATOM") and not line.startswith("HETATM") and not line.startswith("_"):
                if line.strip() == "#" or line.strip() == "" or line.startswith("loop_") or line.startswith("data_"):
                    in_atom_block = False

    return atoms


def cif_atoms_to_pdb_style(cif_atoms):
    """Convert CIF atom records to PDB-style dicts (matching prepare_complex_from_pose1.py)."""
    pdb_atoms = []
    for a in cif_atoms:
        atom = {
            "rec": a.get("group_PDB", "ATOM").ljust(6),
            "serial": int(a.get("id", 0)),
            "name": a.get("auth_atom_id", a.get("label_atom_id", "")).ljust(4),
            "alt": " ",
            "resn": a.get("auth_comp_id", a.get("label_comp_id", "")),
            "chain": a.get("auth_asym_id", a.get("label_asym_id", "")),
            "resi": int(a.get("auth_seq_id", a.get("label_seq_id", 0))),
            "icode": " ",
            "x": float(a.get("Cartn_x", 0)),
            "y": float(a.get("Cartn_y", 0)),
            "z": float(a.get("Cartn_z", 0)),
            "occ": a.get("occupancy", "1.00").rjust(6),
            "bf": str(round(float(a.get("B_iso_or_equiv", 0)), 2)).rjust(6),
            "seg": "    ",
            "elem": a.get("type_symbol", "").rjust(2),
            "chg": "  ",
        }
        pdb_atoms.append(atom)
    return pdb_atoms


# ── PDB parser (same as 5IJ0 script) ───────────────────────────────────────

def parse_pdb_atoms(path):
    atoms = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue
            atom = {
                "rec": line[:6],
                "serial": int(line[6:11]),
                "name": line[12:16],
                "alt": line[16:17],
                "resn": line[17:20].strip(),
                "chain": line[21:22],
                "resi": int(line[22:26]),
                "icode": line[26:27],
                "x": float(line[30:38]),
                "y": float(line[38:46]),
                "z": float(line[46:54]),
                "occ": line[54:60],
                "bf": line[60:66],
                "seg": line[72:76] if len(line) > 75 else "    ",
                "elem": line[76:78] if len(line) > 77 else "  ",
                "chg": line[78:80] if len(line) > 79 else "  ",
            }
            atoms.append(atom)
    return atoms


# ── Kabsch alignment (same as 5IJ0 script) ─────────────────────────────────

def key_ca(a):
    return (a["chain"], a["resi"], a["icode"], a["resn"])


def centroid(points):
    n = len(points)
    return [sum(p[i] for p in points) / n for i in range(3)]


def mat_mul_vec(m, v):
    return [
        m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]*v[2],
        m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]*v[2],
        m[2][0]*v[0] + m[2][1]*v[1] + m[2][2]*v[2],
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


def rmsd(P, Q):
    n = len(P)
    return math.sqrt(sum((P[i][j]-Q[i][j])**2 for i in range(n) for j in range(3)) / n)


def format_atom(i, a):
    name = a["name"]
    # PDB format: 4-char name field, left-justified if starts with digit
    if len(name.strip()) < 4:
        name = f" {name.strip():<3}"
    return (
        f"{a['rec']:<6}{i:5d} {name}{a['alt']}{a['resn']:>3} {a['chain']}"
        f"{a['resi']:4d}{a['icode']}   {a['x']:8.3f}{a['y']:8.3f}{a['z']:8.3f}"
        f"{a['occ']:>6}{a['bf']:>6}      {a['seg']:<4}{a['elem']:>2}{a['chg']:>2}\n"
    )


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Prepare 6E7B complex from Protenix CIF")
    ap.add_argument("--cif", required=True, help="Protenix CIF prediction (sample_0)")
    ap.add_argument("--template", required=True, help="6E7B.pdb template")
    ap.add_argument("--out", required=True, help="Output merged complex PDB")
    args = ap.parse_args()

    # 1. Parse inputs
    print(f"Parsing CIF: {args.cif}")
    cif_raw = parse_cif_atoms(args.cif)
    p_atoms = cif_atoms_to_pdb_style(cif_raw)
    print(f"  → {len(p_atoms)} atoms from Protenix prediction")

    print(f"Parsing template: {args.template}")
    t_atoms = parse_pdb_atoms(args.template)
    print(f"  → {len(t_atoms)} atoms from 6E7B template")

    # 2. Identify components in Protenix prediction
    protein_pred = [a for a in p_atoms if a["resn"] in AA3 and a["chain"] in ("A", "B")]
    ligand_pred = [a for a in p_atoms if a["resn"] == "l01"]
    cofactor_pred = [a for a in p_atoms if a["resn"] in ("GTP", "G2P", "MG")]

    print(f"\nProtenix components:")
    print(f"  Protein: {len(protein_pred)} atoms (chains A,B)")
    print(f"  CPPF (l01): {len(ligand_pred)} atoms")
    print(f"  Cofactors: {len(cofactor_pred)} atoms (excluded from output)")

    # 3. Kabsch alignment on CA atoms
    t_ca = {key_ca(a): a for a in t_atoms
            if a["name"].strip() == "CA" and a["resn"] in AA3 and a["chain"] in ("A", "B")}
    p_ca = {key_ca(a): a for a in p_atoms
            if a["name"].strip() == "CA" and a["resn"] in AA3 and a["chain"] in ("A", "B")}

    common = sorted(set(t_ca.keys()) & set(p_ca.keys()))
    print(f"\nAlignment: {len(common)} common CA atoms")
    if len(common) < 50:
        raise SystemExit(f"Too few common CA anchors: {len(common)}. Check chain/residue mapping.")

    P = [[p_ca[k]["x"], p_ca[k]["y"], p_ca[k]["z"]] for k in common]
    Q = [[t_ca[k]["x"], t_ca[k]["y"], t_ca[k]["z"]] for k in common]
    cP = centroid(P)
    cQ = centroid(Q)
    P0 = [[p[0]-cP[0], p[1]-cP[1], p[2]-cP[2]] for p in P]
    Q0 = [[q[0]-cQ[0], q[1]-cQ[1], q[2]-cQ[2]] for q in Q]
    R = kabsch(P0, Q0)

    # Compute RMSD after alignment
    P_aligned = []
    for p in P:
        v = [p[0]-cP[0], p[1]-cP[1], p[2]-cP[2]]
        rv = mat_mul_vec(R, v)
        P_aligned.append([rv[0]+cQ[0], rv[1]+cQ[1], rv[2]+cQ[2]])
    print(f"  CA RMSD after alignment: {rmsd(P_aligned, Q):.3f} Å")

    # 4. Transform all pose atoms (protein + ligand only)
    def transform(atom):
        b = dict(atom)
        v = [b["x"]-cP[0], b["y"]-cP[1], b["z"]-cP[2]]
        rv = mat_mul_vec(R, v)
        b["x"] = rv[0] + cQ[0]
        b["y"] = rv[1] + cQ[1]
        b["z"] = rv[2] + cQ[2]
        return b

    protein_A = [transform(a) for a in p_atoms if a["resn"] in AA3 and a["chain"] == "A"]
    protein_B = [transform(a) for a in p_atoms if a["resn"] in AA3 and a["chain"] == "B"]

    ligand = [transform(a) for a in ligand_pred]
    for a in ligand:
        a["resn"] = "CPP"     # Match 5IJ0 convention
        a["chain"] = "C"

    # 5. Write output (protein A + protein B + CPPF, NO cofactors)
    out_atoms = protein_A + protein_B + ligand
    with open(args.out, "w", encoding="utf-8") as f:
        for i, a in enumerate(out_atoms, start=1):
            f.write(format_atom(i, a))
        f.write("END\n")

    print(f"\nOutput: {args.out}")
    print(f"  Protein A: {len(protein_A)} atoms")
    print(f"  Protein B: {len(protein_B)} atoms")
    print(f"  CPPF:      {len(ligand)} atoms")
    print(f"  Total:     {len(out_atoms)} atoms")
    print(f"\n  (Cofactors GTP/G2P/MG excluded — consistent with 5IJ0 protocol)")


if __name__ == "__main__":
    main()
