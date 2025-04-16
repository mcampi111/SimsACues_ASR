#!/bin/bash
#SBATCH --job-name=default_gen
#SBATCH --output=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/default_gen_%A_%a.out
#SBATCH --error=/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs/default_gen_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=2
#SBATCH --array=1-20%10  # Run 20 parallel jobs, max 10 at once

# Create log directory
mkdir -p /pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/logs

# Load MATLAB
module load matlab

# Run MATLAB script with current task ID and total tasks
matlab -nodisplay -nodesktop -r "generate_default_noise_neurogram($SLURM_ARRAY_TASK_ID, $SLURM_ARRAY_TASK_COUNT); exit"
