#!/bin/bash
#SBATCH --job-name=validate_neurograms
#SBATCH --output=logs/validate_neurograms_%j.out
#SBATCH --error=logs/validate_neurograms_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --partition=common
#SBATCH --cpus-per-task=4

# Create logs directory if it doesn't exist
mkdir -p logs

# Load modules 
module load Python/3.11.5
source ~/asr_env/bin/activate

# Print information
echo "Starting neurogram validation at $(date)"

# Run the validation script
python validate_neurograms.py

echo "Neurogram validation completed at $(date)"
