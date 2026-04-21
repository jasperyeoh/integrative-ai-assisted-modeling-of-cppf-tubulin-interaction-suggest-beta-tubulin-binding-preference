#!/usr/bin/env python3
import argparse
import math


AA3 = {
    "ALA","ARG","ASN","ASP","CYS","GLU","GLN","GLY","HIS","ILE","LEU","LYS",
    "MET","PHE","PRO","SER","THR","TRP","TYR","VAL","HID","HIE","HIP","CYX",
}


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
                "seg": line[72:76],
                "elem": line[76:78],
                "chg": line[78:80],
            }
            atoms.append(atom)
    return atoms


def key_ca(a):
    return (a["chain"], a["resi"], a["icode"], a["resn"])


def centroid(points):
    n = len(points)
    return [sum(p[i] for p in points) / n for i in range(3)]


def mat_mul_vec(m, v):
    return [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]


def kabsch(P, Q):
    # Returns rotation R such that R*P ~ Q
    # P,Q: Nx3 centered points
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


def format_atom(i, a):
    return (
        f"{a['rec']:<6}{i:5d} {a['name']:<4}{a['alt']}{a['resn']:>3} {a['chain']}"
        f"{a['resi']:4d}{a['icode']}   {a['x']:8.3f}{a['y']:8.3f}{a['z']:8.3f}"
        f"{a['occ']:>6}{a['bf']:>6}      {a['seg']:<4}{a['elem']:>2}{a['chg']:>2}\n"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True)
    ap.add_argument("--pose", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    t_atoms = parse_pdb_atoms(args.template)
    p_atoms = parse_pdb_atoms(args.pose)

    t_ca = {key_ca(a): a for a in t_atoms if a["name"].strip() == "CA" and a["resn"] in AA3 and a["chain"] in ("A", "B")}
    p_ca = {key_ca(a): a for a in p_atoms if a["name"].strip() == "CA" and a["resn"] in AA3 and a["chain"] in ("A", "B")}

    common = sorted(set(t_ca.keys()) & set(p_ca.keys()))
    if len(common) < 50:
        raise SystemExit(f"Too few common CA anchors: {len(common)}. Check chain/residue mapping.")

    P = [[p_ca[k]["x"], p_ca[k]["y"], p_ca[k]["z"]] for k in common]
    Q = [[t_ca[k]["x"], t_ca[k]["y"], t_ca[k]["z"]] for k in common]
    cP = centroid(P)
    cQ = centroid(Q)
    P0 = [[p[0] - cP[0], p[1] - cP[1], p[2] - cP[2]] for p in P]
    Q0 = [[q[0] - cQ[0], q[1] - cQ[1], q[2] - cQ[2]] for q in Q]
    R = kabsch(P0, Q0)

    # Transform all pose atoms
    transformed_pose = []
    for a in p_atoms:
        v = [a["x"] - cP[0], a["y"] - cP[1], a["z"] - cP[2]]
        rv = mat_mul_vec(R, v)
        b = dict(a)
        b["x"] = rv[0] + cQ[0]
        b["y"] = rv[1] + cQ[1]
        b["z"] = rv[2] + cQ[2]
        transformed_pose.append(b)

    # Protein from transformed pose (A/B), ligand from transformed non-protein residues
    protein_A = [a for a in transformed_pose if a["resn"] in AA3 and a["chain"] == "A"]
    protein_B = [a for a in transformed_pose if a["resn"] in AA3 and a["chain"] == "B"]
    ligand = [a for a in transformed_pose if a["resn"] not in AA3 and a["resn"] not in ("HOH", "WAT")]
    # Normalize ligand residue name to match topology convention.
    for a in ligand:
        a["resn"] = "CPP"
        a["chain"] = "C"

    # Cofactors from template, grouped by chain for contiguous chain blocks.
    cof_A = [a for a in t_atoms if a["resn"] in ("GTP", "MG") and a["chain"] == "A"]
    cof_B = [a for a in t_atoms if a["resn"] == "GDP" and a["chain"] == "B"]

    out_atoms = protein_A + cof_A + protein_B + cof_B + ligand
    with open(args.out, "w", encoding="utf-8") as f:
        for i, a in enumerate(out_atoms, start=1):
            f.write(format_atom(i, a))
        f.write("END\n")

    print(f"Wrote merged complex: {args.out}")
    print(
        f"Protein atoms: {len(protein_A) + len(protein_B)}  "
        f"Ligand atoms: {len(ligand)}  Cofactor atoms: {len(cof_A) + len(cof_B)}"
    )


if __name__ == "__main__":
    main()
