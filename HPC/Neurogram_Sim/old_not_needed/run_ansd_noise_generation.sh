#!/bin/bash
#SBATCH --job-name=ansd_noise
#SBATCH --output=logs/ansd_noise_%A_%a.out
#SBATCH --error=logs/ansd_noise_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --mem=16G
#SBATCH --array=1-10
#SBATCH --partition=common
#SBATCH --cpus-per-task=2

# Create logs directory if it doesn't exist
mkdir -p logs

# Load modules (adjust as needed)
module load MATLAB/2023a

# Print job information
echo "Running ANSD noise generation job array ${SLURM_ARRAY_TASK_ID} of ${SLURM_ARRAY_TASK_COUNT}"
echo "Started at: $(date)"

# Run MATLAB script with task ID and total number of tasks
matlab -nodisplay -r "generate_ansd_neurograms_with_noise(${SLURM_ARRAY_TASK_ID}, ${SLURM_ARRAY_TASK_COUNT}); exit"

echo "Completed at: $(date)"
