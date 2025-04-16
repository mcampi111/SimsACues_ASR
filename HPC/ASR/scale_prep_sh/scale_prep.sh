#!/bin/bash
#SBATCH --job-name=scale_prep_ansd
#SBATCH --output=logs/scale_prep_ansd_%j.out
#SBATCH --error=logs/scale_prep_ansd_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1

# Create logs directory if it doesn't exist
mkdir -p logs

# Load specific Python version
module load Python/3.11.5

/opt/gensoft/exe/Python/3.11.5/scripts/python3 <<EOF
try:
    import h5py
    import numpy as np
    import sklearn
    import sklearn.preprocessing
    import scipy.io
    print("All required packages imported successfully")
except ImportError as e:
    print(f"Error importing packages: {e}")
    exit(1)

try:
    # Scale neurogram
    print("Loading TIMIT_neurogram_ansd_train.mat...")
    f = h5py.File('TIMIT_neurogram_ansd_train.mat', 'r')
    data = f.get('TIMIT_neurogram_ansd')  # Correct key name
    print("Initial data shape:", data.shape)
    
    data = np.transpose(data)
    data = np.ascontiguousarray(data)
    print("After transpose shape:", data.shape)
    
    L = sklearn.preprocessing.scale(data)
    np.save('TIMIT_neurogram_ansd_train_scaled', L)
    print("Saved scaled neurogram, shape:", L.shape)
except Exception as e:
    print(f"Error during processing: {e}")
    exit(1)
EOF
