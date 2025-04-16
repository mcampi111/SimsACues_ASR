#!/bin/bash
#SBATCH --job-name=ot_analysis
#SBATCH --output=logs/ot_analysis_%j.out
#SBATCH --error=logs/ot_analysis_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=128G
#SBATCH --partition=common
#SBATCH --cpus-per-task=32

# Create logs directory if it doesn't exist
mkdir -p logs

# Print some information about the job
echo "Job started at $(date)"
echo "Running on node: $(hostname)"
echo "Allocated CPUs: $SLURM_CPUS_PER_TASK"

# Load necessary modules
module load Python/3.11.5

# Activate the dedicated environment for OT analysis
source /pasteur/helix/scratch/mcampi/ot_env/bin/activate

# Create directory for results if it doesn't exist
mkdir -p /pasteur/helix/scratch/mcampi/OT/results/ANSD_OT_Results/

# Create a copy of the perturbation_types.json in the expected location if it doesn't exist
if [ ! -f "/pasteur/helix/scratch/mcampi/OT/perturbation_types.json" ]; then
    echo "Creating a copy of perturbation_types.json in the scratch directory"
    cp /pasteur/helix/scratch/mcampi/perturbation_types.json /pasteur/helix/scratch/mcampi/OT/
fi

# Copy the Python script to the working directory
cp formant_neurogram_computation.py /pasteur/helix/scratch/mcampi/OT/

# Change to the working directory
cd /pasteur/helix/scratch/mcampi/OT/

# Run the Python script
echo "Starting OT analysis..."
python formant_neurogram_computation.py

# Note: Results will stay in scratch directory as requested
echo "Analysis complete. Results are in /pasteur/helix/scratch/mcampi/OT/results/ANSD_OT_Results/"

# Deactivate the virtual environment
deactivate

echo "Job finished at $(date)"
