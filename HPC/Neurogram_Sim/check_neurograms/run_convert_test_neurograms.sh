#!/bin/bash
#SBATCH --job-name=convert_test_neurograms
#SBATCH --output=logs/convert_test_neurograms_%j.out
#SBATCH --error=logs/convert_test_neurograms_%j.err
#SBATCH --time=6:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=1

# Create logs directory if it doesn't exist
mkdir -p logs

# Load MATLAB
module load matlab

# Run the conversion script
matlab -nodisplay -nodesktop -r "cd('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/check_neurograms'); convert_test_neurograms; exit"

echo "Conversion job completed!"
