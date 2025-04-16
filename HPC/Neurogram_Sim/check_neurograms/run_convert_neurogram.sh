#!/bin/bash
#SBATCH --job-name=convert_neurograms
#SBATCH --output=convert_neurograms_%j.out
#SBATCH --error=convert_neurograms_%j.err
#SBATCH --time=4:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=1

# Load MATLAB
module load matlab

# Run the conversion script
matlab -nodisplay -nodesktop -r "convert_neurogram_format; exit"
