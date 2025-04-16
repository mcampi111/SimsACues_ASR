#!/bin/bash
#SBATCH --job-name=merge_neurograms_ansd_train
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_train_%j.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/merge_ansd_train_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --hint=nomultithread



# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nodesktop -r "merge_timit_neurograms_ansd_train; exit"
