#!/bin/bash
#SBATCH --job-name=merge_ansd_train_noise
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_train_noise_%j.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_train_noise_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --hint=nomultithread

# Create logs directory if it doesn't exist
mkdir -p /pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs

# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nodesktop -r "merge_timit_neurograms_ansd_train_with_noise; exit"
