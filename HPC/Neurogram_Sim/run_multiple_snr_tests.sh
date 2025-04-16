#!/bin/bash
# run_multiple_snr_tests.sh
#
# This script submits multiple SLURM job arrays to generate neurograms
# with different SNR settings for the test data

# Base directory - updated to correct path
BASE_DIR="/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim"
cd $BASE_DIR

# Make sure logs directory exists
mkdir -p logs/wham_noise_generation

# Make sure scratch directory exists
SCRATCH_DIR="/pasteur/helix/scratch/mcampi/neurograms_wham"
mkdir -p $SCRATCH_DIR

# Number of parallel jobs per array
NUM_JOBS=20

# Process training data with random SNRs from -5 to 15 dB
echo "Submitting job for training data (random SNR -5 to 15 dB)..."
TRAIN_JOB_ID=$(sbatch --parsable --job-name=train_wham --array=1-$NUM_JOBS \
  --output=logs/wham_noise_generation/train_slurm_%A_%a.out \
  --error=logs/wham_noise_generation/train_slurm_%A_%a.err \
  --cpus-per-task=1 --mem=8G --time=24:00:00 \
  --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_neurograms_with_wham_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
echo "Training job submitted with ID: $TRAIN_JOB_ID"

# Wait for training job to complete before starting test jobs
echo "To ensure the training job must finish first, add: --dependency=afterok:$TRAIN_JOB_ID"
echo "to the sbatch commands below. (Currently not enforced for flexibility)"
echo

# Process test data with different fixed SNR values
for SNR in -5 0 5 10 15; do
    echo "Submitting job for test data with fixed SNR = $SNR dB..."
    TEST_JOB_ID=$(sbatch --parsable --job-name=test_snr${SNR} --array=1-$NUM_JOBS \
      --output=logs/wham_noise_generation/test_snr${SNR}_slurm_%A_%a.out \
      --error=logs/wham_noise_generation/test_snr${SNR}_slurm_%A_%a.err \
      --cpus-per-task=1 --mem=8G --time=24:00:00 \
      --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_neurograms_with_wham_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS, 'fixed:$SNR'); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
    echo "Test job (SNR = $SNR dB) submitted with ID: $TEST_JOB_ID"
done

# Process test data with random SNR (for reference)
echo "Submitting job for test data with random SNR (-5 to 15 dB)..."
RANDOM_JOB_ID=$(sbatch --parsable --job-name=test_random --array=1-$NUM_JOBS \
  --output=logs/wham_noise_generation/test_random_slurm_%A_%a.out \
  --error=logs/wham_noise_generation/test_random_slurm_%A_%a.err \
  --cpus-per-task=1 --mem=8G --time=24:00:00 \
  --wrap="module load matlab/R2023b; matlab -nodisplay -r \"try; generate_neurograms_with_wham_noise(\$SLURM_ARRAY_TASK_ID, $NUM_JOBS, 'random'); catch e; disp(getReport(e)); exit(1); end; exit(0);\"")
echo "Test job (random SNR) submitted with ID: $RANDOM_JOB_ID"

echo "All jobs submitted. Use 'squeue -u $USER' to check status."

# Provide info about output location
echo ""
echo "Neurograms will be generated in: $SCRATCH_DIR"
echo "  - Training data: $SCRATCH_DIR/TRAIN"
echo "  - Test data: $SCRATCH_DIR/TEST"
