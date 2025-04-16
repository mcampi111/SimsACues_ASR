#!/bin/bash
#SBATCH --job-name=merge_neurograms_ansd_test
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_test_%j.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_test_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nodesktop -r "merge_timit_neurograms_ansd_test; exit"
