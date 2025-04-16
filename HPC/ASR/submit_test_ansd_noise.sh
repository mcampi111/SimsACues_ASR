#!/bin/bash
#SBATCH --job-name=test_an
#SBATCH --output=logs/test_ansd_noise_%j.out
#SBATCH --error=logs/test_ansd_noise_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --partition=common
#SBATCH --cpus-per-task=4

# Create logs directory if it doesn't exist
mkdir -p logs

# Load modules (adjust as needed based on your environment)
module load Python/3.11.5
source ~/asr_env/bin/activate

# Print information
echo "Starting ANSD noise model testing at $(date)"
nvidia-smi

# Run the testing script
python test_ansd_noise.py

echo "Testing completed at $(date)"
