# Optional Fig.~2 hydrophobic surface rendering (reviewer R2.6)

Fig.~2 in the manuscript shows **predicted poses** with semi-transparent surfaces and labeled distances. If you need **hydrophobicity coloring** (or electrostatic potential) for the binding cavity, run PyMOL **locally** on the same PDB models used for the figure (exported Protenix/RoseTTAFold complexes aligned to 5IJ0).

## 1. Load structure

```text
# Example: replace with your predicted complex PDB path
load /path/to/cppf_tubulin_complex.pdb, cmp
hide everything
show cartoon, cmp
color marine, cmp
```

Restrict to the pocket neighbourhood if the structure is large:

```text
select pocket, byres (cmp within 5 of organic)
disable cmp
enable pocket
zoom pocket
```

## 2. Semi-transparent surface (baseline, matches narrative “surface” views)

```text
show surface, pocket
set surface_color, white
set transparency, 0.35, pocket
```

## 3. Hydrophobicity coloring (built-in “hydrophobicity” palette)

PyMOL can color surfaces by residue hydrophobicity (Kyte–Doolittle–type mapping):

```text
hide cartoon, pocket
show surface, pocket
spectrum count, hydrophobicity, pocket
set surface_quality, 1
```

Adjust palette:

```text
spectrum max, hydrophobicity, pocket, cyan_white_red
```

## 4. Show ligand for publication overlay

```text
select lig, organic
show sticks, lig
color carbon, yellow, lig
distance dist01, lig, pocket  # optional distance labels
```

## 5. Export

Use **Ray** trace at sufficient DPI for the journal (often 300 dpi TIFF).

```text
png fig2_panel_beta_hydro_surface.png, width=2400, height=1800, dpi=300, ray=1
```

## Notes

- **Electrostatics** (APBS plugin, etc.) is an alternative but adds workflow dependencies; hydrophobicity mapping above answers “hydrophobic vs polar cavity” without extra solvers.
- Keep coloring **consistent** across panels A–E if you replace the composite figure.
- Store final composites next to existing assets as `figs/Fig2.png` / `Fig2.tif` if you update the main figure.
