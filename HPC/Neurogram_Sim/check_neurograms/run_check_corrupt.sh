#!/bin/bash
#SBATCH --job-name=check_corrupt
#SBATCH --output=logs/check_corrupt_%j.out
#SBATCH --error=logs/check_corrupt_%j.err
#SBATCH --time=4:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nodesktop -r "check_corrupt_files; exit"
