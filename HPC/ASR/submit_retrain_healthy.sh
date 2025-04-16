#!/bin/bash
#SBATCH --job-name=retrain_healthy
#SBATCH --output=logs/retrain_healthy_%j.out
#SBATCH --error=logs/retrain_healthy_%j.err
#SBATCH --partition=gpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --gres=gpu:A40:2

# Create directories
mkdir -p logs
mkdir -p results/healthy/silence

# Load modules
echo "Loading modules..."
module purge
module load Python/3.11.5

# Activate virtual environment
echo "Activating virtual environment..."
source ~/asr_env/bin/activate

# Try to set up CUDA environment, but don't fail if it's not available
echo "Checking for GPU availability..."
if nvidia-smi &>/dev/null; then
    echo "GPUs detected, setting up CUDA environment..."
    module load cuda/11.8
    export CUDA_HOME=/opt/gensoft/exe/cuda/11.8
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$CUDA_HOME/extras/CUPTI/lib64:$CUDA_HOME/nvvm/libdevice:$LD_LIBRARY_PATH
    export XLA_FLAGS="--xla_gpu_cuda_data_dir=/opt/gensoft/exe/cuda/11.8"
    
    # Set TensorFlow specific configurations
    export TF_FORCE_GPU_ALLOW_GROWTH=true
    export TF_XLA_FLAGS="--tf_xla_enable_xla_devices"
    
    # Print GPU information
    nvidia-smi
else
    echo "No GPUs detected, running in CPU-only mode."
fi

# Always set this to reduce TF warnings
export TF_CPP_MIN_LOG_LEVEL='2'

# Run the ASR pipeline
echo "Starting retraining at $(date)"
python3 retrain_asr_complete.py

# Print completion time
echo "Retraining completed at $(date)"

# Deactivate virtual environment
deactivate
