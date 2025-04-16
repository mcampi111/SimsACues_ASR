#!/bin/bash
#SBATCH --job-name=scale_default
#SBATCH --output=logs/scale_default_%j.out
#SBATCH --error=logs/scale_default_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

mkdir -p logs

module load Python/3.11.5

/opt/gensoft/exe/Python/3.11.5/scripts/python3 <<PYCODE
import h5py
import numpy as np
import sklearn.preprocessing
import os

# Input and output paths
mat_file = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_mat/TIMIT_neurogram_test_with_noise_default.mat'
output_file = '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro/TIMIT_neurogram_test_with_noise_default_scaled.npy'

print(f"Processing {mat_file}...")

# Open the MAT file
with h5py.File(mat_file, 'r') as f:
    # Try to find the main dataset
    dataset_name = 'TIMIT_neurogram_test_with_noise_default'
    
    if dataset_name in f:
        data = f[dataset_name][:]
        print(f"Found dataset: {dataset_name}")
    else:
        # List available datasets
        datasets = list(f.keys())
        print(f"Available datasets: {datasets}")
        # Look for data array
        for dataset in datasets:
            if dataset not in ['#refs#', 'center_frequencies']:
                data = f[dataset][:]
                print(f"Using dataset: {dataset}")
                break

print(f"Data shape: {data.shape}")

# Make backup of existing file
if os.path.exists(output_file):
    backup_file = output_file + ".backup"
    print(f"Creating backup at {backup_file}")
    os.rename(output_file, backup_file)

# Scale the data
print("Scaling data...")
L = sklearn.preprocessing.scale(data)
print(f"Scaled data shape: {L.shape}")

# Save as NPY
print(f"Saving to: {output_file}")
np.save(output_file, L)
print("Done!")
PYCODE
