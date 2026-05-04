"""Publication-friendly figure export (PLOS Comp Biol: TIFF/EPS, 300 dpi, LZW)."""
from __future__ import annotations

from pathlib import Path

from matplotlib.figure import Figure


def save_figure(fig: Figure, path: Path, *, dpi: int = 300, fig_format: str = "tif") -> None:
    """Write *fig* to *path*; default TIFF with LZW at *dpi* (matplotlib ``format='tif'``)."""
    path = Path(path)
    fmt = fig_format.lower().strip(".")
    if fmt == "tiff":
        fmt = "tif"
    path.parent.mkdir(parents=True, exist_ok=True)
    if fmt in ("tif",):
        fig.savefig(
            path,
            format="tif",
            dpi=dpi,
            bbox_inches="tight",
            pil_kwargs={"compression": "tiff_lzw"},
        )
    elif fmt in ("png", "svg", "pdf", "eps"):
        fig.savefig(path, format=fmt, dpi=dpi, bbox_inches="tight")
    else:
        raise ValueError(f"unsupported fig_format: {fig_format}")
