# GROMACS Gibbs Free Energy Analysis Pipeline Guide

This document provides a detailed, step-by-step guide for the complete Gibbs Free Energy Surface analysis workflow using GROMACS and Python.

## 📋 Prerequisites

### Software Requirements
- **GROMACS** (version 2020 or later recommended)
- **Python 3.7+** with scientific computing libraries
- **Bash shell** (for automated scripts)

### Input Data Requirements
Your analysis requires three essential GROMACS files:
- `md_0_1_processed.xtc` – Processed trajectory file
- `md_0_1.tpr` – GROMACS run input file  
- `md_topol.pdb` – Topology file for alignment

## 🔧 Manual Step-by-Step Execution

### Step 1: Trajectory Alignment
Align the trajectory to remove global translation and rotation:

```bash
gmx trjconv -f md_0_1_processed.xtc -s md_0_1.tpr -fit rot+trans -o md_fit.xtc
# When prompted, select group 4 (Backbone) for fitting
```

**Purpose**: Ensures all frames are aligned to a common reference structure, removing global motions that would interfere with PCA analysis.

### Step 2: Covariance Matrix Calculation
Calculate the covariance matrix of atomic fluctuations:

```bash
gmx covar -s md_0_1.tpr -f md_fit.xtc -o eigenval.xvg -v eigenvec.trr -xpma covar.xpm
# When prompted:
# LS-fit group: 4 (Backbone)
# Covariance group: 4 (Backbone)
```

**Output files**:
- `eigenval.xvg` – Eigenvalues (variance explained by each PC)
- `eigenvec.trr` – Eigenvectors (principal component directions)
- `covar.xpm` – Covariance matrix visualization

### Step 3: Principal Component Projection
Project the trajectory onto the first two principal components:

```bash
# Project onto PC1
gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 1 -last 1 -proj pc1.xvg
# When prompted, select group 4 (Backbone)

# Project onto PC2  
gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 2 -last 2 -proj pc2.xvg
# When prompted, select group 4 (Backbone)
```

**Output files**:
- `pc1.xvg` – PC1 projections over time
- `pc2.xvg` – PC2 projections over time

### Step 4: Combine Principal Components
Merge PC1 and PC2 data for SHAM analysis:

```bash
paste pc1.xvg pc2.xvg | awk '{print $1, $2, $4}' > gsham_input.xvg
```

**Purpose**: Creates a 3-column file (time, PC1, PC2) required by the SHAM method.

### Step 5: Free Energy Surface Generation
Generate the free energy surface using the SHAM method:

```bash
gmx sham -f gsham_input.xvg -ls FES.xpm
```

**Output**: `FES.xpm` – Free energy surface in GROMACS XPM format

### Step 6: Convert to Text Format
Convert the XPM file to a plain text format for Python analysis:

```bash
python scripts/xpm2txt.py -f FES.xpm -o free_energy_landscape.txt
```

**Output**: `free_energy_landscape.txt` – 3-column text file (PC1, PC2, Free Energy)

## 🐍 Python Visualization

### Basic Usage
```python
python scripts/plot_gibbs_landscape.py --input free_energy_landscape.txt
```

### Advanced Options
```python
python scripts/plot_gibbs_landscape.py \
    --input free_energy_landscape.txt \
    --output custom_landscape.png \
    --format png \
    --smoothing 2.0 \
    --grid-size 150 \
    --title "Custom Title"
```

### Parameter Explanations

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--smoothing` | 1.5 | Gaussian smoothing sigma for noise reduction |
| `--grid-size` | 100 | Interpolation grid resolution |
| `--interpolation` | cubic | Interpolation method (linear/nearest/cubic) |
| `--format` | auto | Output format (svg/png/pdf/eps) |
| `--dpi` | 300 | Output resolution for raster formats |

## 🤖 Automated Execution

### Using the Shell Script
For automated execution of the entire pipeline:

```bash
# For beta system
bash scripts/run_gibbs_analysis.sh beta

# For alpha system
bash scripts/run_gibbs_analysis.sh alpha
```

**Prerequisites**: Ensure your data files are in `data/CPPF+[system]/` directory.

### Script Features
- **Error handling**: Stops on any failure
- **Progress reporting**: Colored output with status updates
- **File validation**: Checks for required input files
- **Automatic visualization**: Generates plots after analysis

## 📊 Understanding the Results

### Principal Component Analysis
- **PC1 and PC2**: Represent the two most significant conformational motions
- **Eigenvalues**: Indicate the variance explained by each component
- **Projections**: Show how the system moves along these directions over time

### Free Energy Surface
- **Energy units**: kJ/mol (relative to the global minimum)
- **Contour levels**: Represent energy barriers between conformations
- **Global minimum**: Most stable conformation in the sampled space

### Visualization Output
The script generates two complementary plots:
1. **3D Surface**: Shows the full energy landscape with depth
2. **2D Contour**: Provides a top-down view with energy levels

## 🔍 Troubleshooting

### Common Issues

**"Group not found" errors**:
- Ensure your topology file contains backbone atoms
- Check that group 4 corresponds to backbone in your system

**"No data points" in visualization**:
- Verify the XPM to TXT conversion completed successfully
- Check that the input file contains valid numerical data

**Poor visualization quality**:
- Increase `--grid-size` for higher resolution
- Adjust `--smoothing` to balance detail vs. noise reduction

**Memory issues with large trajectories**:
- Consider subsampling the trajectory before analysis
- Use `gmx trjconv` with `-skip` option to reduce frame count

### Performance Optimization

**For large systems**:
- Use `gmx covar` with `-nofit` if alignment is not critical
- Consider using `gmx anaeig` with `-skip` for faster projection

**For high-resolution surfaces**:
- Increase grid size gradually to find optimal balance
- Use cubic interpolation for smoother surfaces

## 📚 Scientific Background

### Principal Component Analysis in MD
PCA identifies the dominant modes of motion in molecular systems by:
1. Computing the covariance matrix of atomic fluctuations
2. Diagonalizing to find eigenvectors (principal components)
3. Ranking by eigenvalues (variance explained)

### Free Energy Surface Methods
The SHAM (Stochastic Histogram Analysis Method) approach:
1. Bins the PC1-PC2 space into a grid
2. Counts trajectory visits to each bin
3. Converts counts to free energies using: ΔG = -kBT ln(P)

### Visualization Principles
- **Color mapping**: Red-Yellow-Blue (RdYlBu_r) shows energy from high to low
- **Smoothing**: Gaussian filtering reduces noise while preserving features
- **Interpolation**: Cubic interpolation provides smooth surfaces from discrete data

## 🔗 References

1. Amadei, A., Linssen, A. B. M., & Berendsen, H. J. C. (1993). Essential dynamics of proteins. *Proteins: Structure, Function, and Bioinformatics*, 17(4), 412-425.

2. Branduardi, D., Gervasio, F. L., & Parrinello, M. (2007). From A to B in free energy space. *The Journal of Chemical Physics*, 126(5), 054103.

3. GROMACS Documentation: https://manual.gromacs.org/
