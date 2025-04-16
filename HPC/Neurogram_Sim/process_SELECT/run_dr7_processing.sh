#!/bin/bash

# Base SLURM parameters
SCRIPT_CONTENT='#!/bin/bash
#SBATCH --job-name=process_dr7
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/slurm_%A_%a.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/slurm_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -L matlab@licserv:1

# Load MATLAB
module load matlab

# Run the MATLAB script
matlab -nodisplay -nosplash -nodesktop -r "process_dr7_parallel; exit"
'

# Count speakers and submit job
N_SPEAKERS=$(find /pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT/TRAIN/DR7/ -maxdepth 1 -mindepth 1 -type d | wc -l)
echo "Found $N_SPEAKERS speaker directories"

TMP_SCRIPT=$(mktemp)
echo "$SCRIPT_CONTENT" > $TMP_SCRIPT
chmod +x $TMP_SCRIPT

sbatch --array=1-$N_SPEAKERS $TMP_SCRIPT
rm $TMP_SCRIPT
