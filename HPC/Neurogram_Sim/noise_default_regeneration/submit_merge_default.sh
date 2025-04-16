#!/bin/bash
#SBATCH --job-name=merge_default
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_default_%j.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_default_%j.err
#SBATCH --time=6:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

# Create log directory
mkdir -p /pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs

# Load MATLAB
module load matlab

# Run the merging script
matlab -nodisplay -nodesktop -r "merge_default_neurograms; exit"
