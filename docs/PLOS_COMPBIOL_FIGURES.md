# PLOS Computational Biology — figure export conventions

This project targets **PLOS Computational Biology** (and similar) requirements: **vector (PDF/EPS/SVG)** or **high-resolution raster (TIFF)** at **≥300 dpi** for line art and composite figures.

## Default in revision scripts

- **Format**: TIFF (`tif`), **compression**: **LZW** (lossless, widely accepted).
- **Resolution**: **300 dpi** (overridable with `--dpi` on plotting CLIs).
- **Implementation**: `revision_exec/analysis_revision/revision_figure_export.py` calls `Figure.savefig(..., format='tif', pil_kwargs={'compression': 'tiff_lzw'})` for TIFF; other formats use matplotlib defaults with `bbox_inches='tight'`.

## Gibbs / free-energy landscape plots

`gromacs-gibbs-pipeline/scripts/plot_gibbs_landscape.py` (and the copy under `revision_exec/analysis/external/...`) supports `--format tif` / `tiff` in addition to `png`, `pdf`, `eps`, `svg`. Auto-detect from the output filename also works (e.g. `landscape.tif`).

## Checklist before submission

1. **Raster**: use `.tif` at **300 dpi** unless the figure is pure vector.
2. **Colour**: ensure colour-blind-safe palettes where applicable (scripts use project defaults).
3. **Fonts**: embed where the journal requires it (PDF/EPS); TIFF rasters text as pixels at given dpi.
4. **File size**: LZW keeps TIFF sizes reasonable; avoid committing multi‑MB figures to git unless needed—attach to submission package instead.

## EPS

If the journal insists on EPS only for certain figure types, pass `--fig-format eps` to the revision plotting scripts or `--format eps` to `plot_gibbs_landscape.py`.
