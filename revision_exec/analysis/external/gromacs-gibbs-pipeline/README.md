# GROMACS Gibbs Free Energy Analysis Pipeline

A comprehensive and reproducible workflow for generating high-quality 3D Gibbs Free Energy Surface plots from molecular dynamics (MD) simulation data using GROMACS and Python.

## 🎯 Overview

This pipeline provides a complete solution for analyzing MD trajectories and visualizing the free energy landscape through principal component analysis (PCA) and free energy surface (FES) generation. It's designed for both `alpha` and `beta` protein systems.

## ✨ Features

- **Automated trajectory alignment** using backbone atoms
- **Principal component analysis** for dimensionality reduction
- **Free energy surface generation** using GROMACS SHAM
- **High-quality visualization** with 3D surface and contour plots
- **Reproducible workflow** with clear documentation
- **Python-based plotting** with customizable parameters

## 📋 Requirements

### Software Dependencies
- GROMACS (tested with 2020+ versions)
- Python 3.7+
- Required Python packages (see `requirements.txt`)

### Input Files
- `md_0_1_processed.xtc` – GROMACS trajectory file
- `md_0_1.tpr` – GROMACS run input file
- `md_topol.pdb` – Topology file for alignment

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/gromacs-md-gibbs-energy-pipeline.git
   cd gromacs-md-gibbs-energy-pipeline
   ```

2. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the analysis pipeline**
   ```bash
   # For beta system
   bash scripts/run_gibbs_analysis.sh beta
   
   # For alpha system  
   bash scripts/run_gibbs_analysis.sh alpha
   ```

4. **Generate visualizations**
   ```bash
   python scripts/plot_gibbs_landscape.py --input free_energy_landscape.txt --output gibbs_landscape.svg
   ```

## 📁 Project Structure

```
gromacs-gibbs-pipeline/
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── scripts/                          # Analysis scripts
│   ├── run_gibbs_analysis.sh         # Main analysis pipeline
│   ├── plot_gibbs_landscape.py       # Visualization script
│   └── xpm2txt.py                    # XPM to TXT converter
├── docs/                             # Documentation
│   ├── pipeline_guide.md             # Detailed pipeline guide
│   └── examples/                     # Usage examples
├── data/                             # Sample data and results
└── examples/                         # Example outputs
```

## 🔧 Detailed Usage

### Step-by-Step Manual Execution

1. **Trajectory Alignment**
   ```bash
   gmx trjconv -f md_0_1_processed.xtc -s md_0_1.tpr -fit rot+trans -o md_fit.xtc
   # Select group for fit: 4 (Backbone)
   ```

2. **Covariance Matrix Calculation**
   ```bash
   gmx covar -s md_0_1.tpr -f md_fit.xtc -o eigenval.xvg -v eigenvec.trr -xpma covar.xpm
   # LS-fit group: 4 (Backbone)
   # Covariance group: 4 (Backbone)
   ```

3. **Principal Component Projection**
   ```bash
   gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 1 -last 1 -proj pc1.xvg
   gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 2 -last 2 -proj pc2.xvg
   # Select group: 4 (Backbone)
   ```

4. **Combine PC1 and PC2**
   ```bash
   paste pc1.xvg pc2.xvg | awk '{print $1, $2, $4}' > gsham_input.xvg
   ```

5. **Free Energy Surface Generation**
   ```bash
   gmx sham -f gsham_input.xvg -ls FES.xpm
   ```

6. **Convert to Text Format**
   ```bash
   python scripts/xpm2txt.py -f FES.xpm -o free_energy_landscape.txt
   ```

### Visualization Options

The plotting script supports multiple output formats and customization options:

```bash
# Basic usage
python scripts/plot_gibbs_landscape.py --input free_energy_landscape.txt

# Custom output and parameters
python scripts/plot_gibbs_landscape.py \
    --input free_energy_landscape.txt \
    --output custom_landscape.png \
    --format png \
    --smoothing 2.0 \
    --grid-size 150
```

## 📊 Output Files

| Filename | Description |
|----------|-------------|
| `md_fit.xtc` | Aligned trajectory |
| `eigenvec.trr`, `eigenval.xvg` | PCA results |
| `pc1.xvg`, `pc2.xvg` | Principal components |
| `gsham_input.xvg` | PC1 + PC2 merged |
| `FES.xpm` | Free energy surface (GROMACS) |
| `free_energy_landscape.txt` | Plain text energy surface |
| `gibbs_landscape.svg` | Final visualization |

## 🧪 Example Results

The pipeline generates publication-ready figures showing:
- 3D Gibbs free energy surface with global minimum marked
- 2D contour plot with energy levels
- High-resolution SVG output suitable for publications

## 🔬 Scientific Background

This pipeline implements the following methodology:
1. **Trajectory alignment** ensures consistent reference frame
2. **Principal component analysis** identifies dominant conformational motions
3. **Free energy surface calculation** using the SHAM method
4. **Visualization** provides intuitive understanding of energy landscape

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📚 References

- GROMACS documentation: https://manual.gromacs.org/
- Principal component analysis in MD: Amadei et al., Proteins 1993
- Free energy surface methods: Branduardi et al., J. Chem. Phys. 2007

## 📞 Support

For questions or issues, please open an issue on GitHub or contact the maintainers.
