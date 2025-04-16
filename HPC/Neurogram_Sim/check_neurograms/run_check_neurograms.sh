#!/bin/bash
#SBATCH --job-name=check_neurograms
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/check_neurograms_%j.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/check_neurograms_%j.err
#SBATCH --time=1:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread

# Create logs directory if it doesn't exist
mkdir -p /pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs

# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nodesktop -r "check_neurogram_files; exit"
