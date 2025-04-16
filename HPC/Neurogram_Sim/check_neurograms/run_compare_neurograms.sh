#!/bin/bash
#SBATCH --job-name=compare_neurograms
#SBATCH --output=compare_neurograms_%j.out
#SBATCH --error=compare_neurograms_%j.err
#SBATCH --time=1:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1

# Load MATLAB
module load matlab

# Run the comparison script
matlab -nodisplay -nodesktop -r "compare_merged_neurograms; exit"
