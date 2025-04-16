#!/bin/bash
#SBATCH --job-name=ansd_gen
#SBATCH --output=logs/ansd_gen_%j.out
#SBATCH --error=logs/ansd_gen_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1

# Load correct modules
module purge
module load Python/3.11.5

# Print some info
echo "Starting job at: $(date)"
echo "Running on node: $(hostname)"

# Create logs directory if it doesn't exist
mkdir -p logs

# Run the Python script
python3 ANSD_neurogram_generation.py

echo "Job finished at: $(date)"
