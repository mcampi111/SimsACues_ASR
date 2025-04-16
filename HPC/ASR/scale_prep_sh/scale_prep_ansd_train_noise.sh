#!/bin/bash
#SBATCH --job-name=scale_prep_ansd_train_noise
#SBATCH --output=logs/scale_prep_ansd_train_noise_%j.out
#SBATCH --error=logs/scale_prep_ansd_train_noise_%j.err
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
    import os
    print("All required packages imported successfully")
except ImportError as e:
    print(f"Error importing packages: {e}")
    exit(1)

try:
    # Set directories
    timit_mat_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_mat'
    output_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro_ANSD'
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Scale neurogram with noise
    input_file = os.path.join(timit_mat_dir, 'TIMIT_neurogram_ansd_train_with_noise.mat')
    print(f"Loading {input_file}...")
    
    with h5py.File(input_file, 'r') as f:
        # Try to find the correct dataset
        if 'TIMIT_neurogram_ansd_train_with_noise' in f:
            data = f['TIMIT_neurogram_ansd_train_with_noise'][:]
        else:
            # If not found, look for other datasets
            datasets = [k for k in f.keys() if k != '#refs#' and k != 'neurogram_mapping' and k != 'center_frequencies']
            if datasets:
                data = f[datasets[0]][:]
                print(f"Using dataset: {datasets[0]}")
            else:
                raise ValueError(f"No suitable dataset found in {input_file}")
    
    print("Initial data shape:", data.shape)
    
    # Transpose the data and ensure it's contiguous
    data = np.transpose(data)
    data = np.ascontiguousarray(data)
    print("After transpose shape:", data.shape)
    
    # Scale the data
    L = sklearn.preprocessing.scale(data)
    
    # Save the scaled data
    output_file = os.path.join(output_dir, 'TIMIT_neurogram_ansd_train_with_noise_scaled.npy')
    np.save(output_file, L)
    print(f"Saved scaled neurogram to {output_file}, shape: {L.shape}")
except Exception as e:
    print(f"Error during processing: {e}")
    exit(1)
EOF
