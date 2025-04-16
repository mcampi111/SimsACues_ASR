#!/bin/bash
#SBATCH --job-name=setup_tf
#SBATCH --output=logs/setup_tf_%j.out
#SBATCH --error=logs/setup_tf_%j.err
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --qos=gpu
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=01:00:00

# Create logs directory
mkdir -p logs

# Clean environment
module purge

# Set CUDA environment variables
export CUDA_HOME=/opt/gensoft/exe/cuda/11.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$CUDA_HOME/extras/CUPTI/lib64:$LD_LIBRARY_PATH
export XLA_FLAGS=--xla_gpu_cuda_data_dir=$CUDA_HOME

# Load modules in correct order
module load cuda/11.8
module load Python/3.11.5

# Activate virtual environment
source ~/asr_env/bin/activate

# Completely remove TensorFlow and reinstall with specific cuda version
pip uninstall -y tensorflow tensorflow-gpu
pip install nvidia-cudnn-cu11==8.6.0.163
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(python3 -c "import os; import nvidia.cudnn; print(os.path.dirname(nvidia.cudnn.__file__))")
pip install tensorflow==2.14.0

# Print CUDA-related environment
echo "Environment Information:"
echo "======================="
echo "CUDA_HOME: $CUDA_HOME"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PATH: $PATH"
echo "CUDA Version:"
nvcc --version
echo -e "\nCUDA Libraries:"
ldconfig -p | grep cuda
echo -e "\nTensorFlow CUDA Configuration:"
python3 -c "
import tensorflow as tf
print('Build Information:')
print(tf.sysconfig.get_build_info())
print('\nCUDA Device Properties:')
if tf.config.list_physical_devices('GPU'):
    for device in tf.config.list_physical_devices('GPU'):
        print(tf.config.experimental.get_device_details(device))
print('\nNum GPUs Available:', len(tf.config.list_physical_devices('GPU')))
print('GPU Devices:', tf.config.list_physical_devices('GPU'))
"
