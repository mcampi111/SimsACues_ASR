#!/bin/bash
#SBATCH --job-name=ansd_neurogram_test_processing
#SBATCH --output=logs/ansd_neurogram_test_%A_%a.out
#SBATCH --error=logs/ansd_neurogram_test_%A_%a.err
#SBATCH --array=0-19  # Adjust based on number of tasks needed
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --partition=common
#SBATCH --cpus-per-task=4

# Create logs directory if it doesn't exist
mkdir -p logs

# Load modules
module load Python/3.11.5
source ~/asr_env/bin/activate

# Print information
echo "Starting ANSD TEST neurogram processing at $(date)"

# Run the processing script
python process_ansd_neurograms_TEST.py

echo "TEST Neurogram processing completed at $(date)"
