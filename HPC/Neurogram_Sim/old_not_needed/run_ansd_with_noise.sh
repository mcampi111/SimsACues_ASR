#!/bin/bash
# run_ansd_with_noise.sh
#
# This script submits multiple SLURM job arrays to generate ANSD neurograms
# with different SNR settings for the test data

# Base directory 
BASE_DIR="/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim"
cd $BASE_DIR

# Make sure logs directory exists
mkdir -p logs/ansd_noise_generation

# Make sure output directory exists
OUTPUT_DIR="$BASE_DIR/SELECT_Neurograms_ANSD_WithNoise"
mkdir -p $OUTPUT_DIR

# Number of parallel jobs per array
NUM_JOBS=10

# Process training data with random SNRs from -5 to 15 dB
echo "Submitting job for ANSD training data (random SNR -5 to 15 dB)..."
TRAIN_JOB_ID=$(sbatch --parsable --job-name=ansd_train --array=1-$NUM_JOBS \
  --output=logs/ansd_noise_generation/train_slurm_%A_%a.out \
  --error=logs/ansd_noise_generation/train_slurm_%A_%a.err \
  --cpus-per-task=1 --mem=8G --time=24:00:00 \
  --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_ansd_neurograms_with_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
echo "ANSD Training job submitted with ID: $TRAIN_JOB_ID"

# Process test data with different fixed SNR values
for SNR in -5 0 5 10 15; do
    echo "Submitting job for ANSD test data with fixed SNR = $SNR dB..."
    TEST_JOB_ID=$(sbatch --parsable --job-name=ansd_snr${SNR} --array=1-$NUM_JOBS \
      --output=logs/ansd_noise_generation/test_snr${SNR}_slurm_%A_%a.out \
      --error=logs/ansd_noise_generation/test_snr${SNR}_slurm_%A_%a.err \
      --cpus-per-task=1 --mem=8G --time=24:00:00 \
      --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_ansd_neurograms_with_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS, 'fixed:$SNR'); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
    echo "ANSD Test job (SNR = $SNR dB) submitted with ID: $TEST_JOB_ID"
done

# Process test data with default setting
echo "Submitting job for ANSD test data with default noise setting..."
DEFAULT_JOB_ID=$(sbatch --parsable --job-name=ansd_default --array=1-$NUM_JOBS \
  --output=logs/ansd_noise_generation/test_default_slurm_%A_%a.out \
  --error=logs/ansd_noise_generation/test_default_slurm_%A_%a.err \
  --cpus-per-task=1 --mem=8G --time=24:00:00 \
  --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_ansd_neurograms_with_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS, 'fixed:5'); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
echo "ANSD Test job (default) submitted with ID: $DEFAULT_JOB_ID"

echo "All jobs submitted. Use 'squeue -u $USER' to check status."

# Provide info about output location
echo ""
echo "ANSD Neurograms with noise will be generated in: $OUTPUT_DIR"
echo "  - Training data: $OUTPUT_DIR/TRAIN"
echo "  - Test data: $OUTPUT_DIR/TEST"
