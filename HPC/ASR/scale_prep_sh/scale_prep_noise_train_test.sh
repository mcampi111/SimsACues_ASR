#!/bin/bash
#SBATCH --job-name=scale_prep_noise_test
#SBATCH --output=logs/scale_prep_noise_test_%j.out
#SBATCH --error=logs/scale_prep_noise_test_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1

# Create logs directory if it doesn't exist
mkdir -p logs

# Load specific Python version
module load Python/3.11.5

/opt/gensoft/exe/Python/3.11.5/scripts/python3 <<EOF
import os
import h5py
import numpy as np
import sklearn.preprocessing

# List of noisy test files to process
noise_files = [
    'TIMIT_neurogram_test_with_noise_default.mat',
    'TIMIT_neurogram_test_with_noise_snr_0.mat',
    'TIMIT_neurogram_test_with_noise_snr_5.mat',
    'TIMIT_neurogram_test_with_noise_snr_10.mat',
    'TIMIT_neurogram_test_with_noise_snr_15.mat',
    'TIMIT_neurogram_test_with_noise_snr_neg5.mat',
    'TIMIT_neurogram_with_noise.mat'
]

# Set directories
timit_mat_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_mat'
output_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro'

# Process each noisy test file
for filename in noise_files:
    try:
        # Extract base name without extension
        base_name = os.path.splitext(filename)[0]
        
        # Full path to the input file
        input_path = os.path.join(timit_mat_dir, filename)
        print(f"Processing {input_path}...")
        
        # Extract condition name for the output file
        condition = filename.replace('TIMIT_neurogram_', '').replace('.mat', '')
        
        # Open the file and read the main dataset
        with h5py.File(input_path, 'r') as f:
            # The main dataset has the same name as the file basename
            dataset_name = base_name
            
            # Check if the dataset exists
            if dataset_name in f:
                print(f"Found dataset: {dataset_name}")
                data = f[dataset_name][:]
                print(f"Data shape: {data.shape}")
            else:
                # If not found, list available datasets
                datasets = [k for k in f.keys() if k != '#refs#' and k != 'neurogram_mapping' and k != 'center_frequencies']
                if datasets:
                    dataset_name = datasets[0]
                    print(f"Using alternative dataset: {dataset_name}")
                    data = f[dataset_name][:]
                    print(f"Data shape: {data.shape}")
                else:
                    raise ValueError(f"No suitable dataset found in {filename}")
        
        # Scale the data
        print("Scaling data...")
        L = sklearn.preprocessing.scale(data)
        print("Scaling completed")
        
        # Define output filename
        output_filename = f"TIMIT_neurogram_{condition}_scaled.npy"
        output_path = os.path.join(output_dir, output_filename)
        
        # Save the scaled data
        print(f"Saving to: {output_path}")
        np.save(output_path, L)
        print(f"File saved successfully. Shape: {L.shape}")
        
    except Exception as e:
        print(f"Error processing {filename}: {e}")
        continue

print("All processing completed.")
EOF
