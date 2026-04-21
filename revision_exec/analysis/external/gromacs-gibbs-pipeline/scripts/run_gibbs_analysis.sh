#!/bin/bash

# GROMACS Gibbs Free Energy Analysis Pipeline
# Automated script for running the complete analysis workflow
# Usage: ./run_gibbs_analysis.sh [alpha|beta]

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if system type is provided
if [ $# -eq 0 ]; then
    print_error "Please specify system type: alpha or beta"
    echo "Usage: $0 [alpha|beta]"
    exit 1
fi

SYSTEM=$1
if [[ "$SYSTEM" != "alpha" && "$SYSTEM" != "beta" ]]; then
    print_error "Invalid system type. Use 'alpha' or 'beta'"
    exit 1
fi

print_status "Starting Gibbs Free Energy Analysis for $SYSTEM system"

# Set working directory - adjust path based on your data location
WORK_DIR="../data/CPPF+$SYSTEM"
if [ ! -d "$WORK_DIR" ]; then
    print_warning "Data directory $WORK_DIR not found"
    print_status "Please ensure your GROMACS data files are in the correct location"
    print_status "Expected files: md_0_1_processed.xtc, md_0_1.tpr, md_topol.pdb"
    exit 1
fi

cd "$WORK_DIR"

# Check for required input files
REQUIRED_FILES=("md_0_1_processed.xtc" "md_0_1.tpr" "md_topol.pdb")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file $file not found in $WORK_DIR"
        exit 1
    fi
done

print_success "All required input files found"

# Step 1: Trajectory alignment
print_status "Step 1: Aligning trajectory..."
echo "4" | gmx trjconv -f md_0_1_processed.xtc -s md_0_1.tpr -fit rot+trans -o md_fit.xtc
print_success "Trajectory alignment completed"

# Step 2: Covariance matrix calculation
print_status "Step 2: Calculating covariance matrix..."
echo -e "4\n4" | gmx covar -s md_0_1.tpr -f md_fit.xtc -o eigenval.xvg -v eigenvec.trr -xpma covar.xpm
print_success "Covariance matrix calculation completed"

# Step 3: Principal component projection
print_status "Step 3: Projecting principal components..."
echo "4" | gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 1 -last 1 -proj pc1.xvg
echo "4" | gmx anaeig -v eigenvec.trr -s md_0_1.tpr -f md_fit.xtc -first 2 -last 2 -proj pc2.xvg
print_success "Principal component projection completed"

# Step 4: Combine PC1 and PC2
print_status "Step 4: Combining PC1 and PC2..."
paste pc1.xvg pc2.xvg | awk '{print $1, $2, $4}' > gsham_input.xvg
print_success "PC1 and PC2 combination completed"

# Step 5: Free energy surface generation
print_status "Step 5: Generating free energy surface..."
gmx sham -f gsham_input.xvg -ls FES.xpm
print_success "Free energy surface generation completed"

# Step 6: Convert XPM to TXT
print_status "Step 6: Converting XPM to TXT format..."
python ../../scripts/xpm2txt.py -f FES.xpm -o free_energy_landscape.txt
print_success "XPM to TXT conversion completed"

# Step 7: Generate visualization
print_status "Step 7: Generating visualization..."
python ../../scripts/plot_gibbs_landscape.py \
    --input free_energy_landscape.txt \
    --output "../../examples/gibbs_landscape_${SYSTEM}.svg" \
    --title "Gibbs Free Energy Landscape ($SYSTEM system)"

print_success "Visualization completed"

# Summary
print_success "Gibbs Free Energy Analysis completed successfully for $SYSTEM system!"
print_status "Output files:"
echo "  - free_energy_landscape.txt (energy data)"
echo "  - ../../examples/gibbs_landscape_${SYSTEM}.svg (visualization)"
echo "  - FES.xpm (GROMACS format)"
echo "  - pc1.xvg, pc2.xvg (principal components)"
echo "  - eigenval.xvg, eigenvec.trr (PCA results)"

cd - > /dev/null
