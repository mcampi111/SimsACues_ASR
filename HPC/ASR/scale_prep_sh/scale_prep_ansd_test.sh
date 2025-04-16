#!/bin/bash
#SBATCH --job-name=scale_prep_ansd_test
#SBATCH --output=logs/scale_prep_ansd_test_%j.out
#SBATCH --error=logs/scale_prep_ansd_test_%j.err
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

# List of ANSD test files to process with corrected filenames
ansd_files = [
    'TIMIT_neurogram_ansd_test_with_noise_default.mat',
    'TIMIT_neurogram_ansd_test_with_noise_snr0.0.mat',
    'TIMIT_neurogram_ansd_test_with_noise_snr5.0.mat',
    'TIMIT_neurogram_ansd_test_with_noise_snr10.0.mat',
    'TIMIT_neurogram_ansd_test_with_noise_snr15.0.mat',
    'TIMIT_neurogram_ansd_test_with_noise_snr-5.0.mat'
]

# Mapping from input filenames to expected output filenames (without the extension)
filename_mapping = {
    'TIMIT_neurogram_ansd_test_with_noise_default.mat': 'TIMIT_neurogram_ansd_test_with_noise_default',
    'TIMIT_neurogram_ansd_test_with_noise_snr0.0.mat': 'TIMIT_neurogram_ansd_test_with_noise_snr_0',
    'TIMIT_neurogram_ansd_test_with_noise_snr5.0.mat': 'TIMIT_neurogram_ansd_test_with_noise_snr_5',
    'TIMIT_neurogram_ansd_test_with_noise_snr10.0.mat': 'TIMIT_neurogram_ansd_test_with_noise_snr_10',
    'TIMIT_neurogram_ansd_test_with_noise_snr15.0.mat': 'TIMIT_neurogram_ansd_test_with_noise_snr_15',
    'TIMIT_neurogram_ansd_test_with_noise_snr-5.0.mat': 'TIMIT_neurogram_ansd_test_with_noise_snr_neg5'
}

# Set directories
timit_mat_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_mat'
output_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro_ANSD'

# Process each ANSD test file
for filename in ansd_files:
    try:
        # Get the exact output name for this file
        output_base_name = filename_mapping[filename]
        
        # Full path to the input file
        input_path = os.path.join(timit_mat_dir, filename)
        print(f"Processing {input_path}...")
        
        # Extract base name without extension for dataset lookup
        base_name = os.path.splitext(filename)[0]
        
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
        
        # Transpose the data to have time as rows and features as columns
        # Original shape is (features, time) = (150, 872494)
        # New shape will be (time, features) = (872494, 150)
        print("Transposing data to have time as rows and features as columns...")
        data = data.T
        print(f"Transposed data shape: {data.shape}")
        
        # Scale the data
        print("Scaling data...")
        L = sklearn.preprocessing.scale(data)
        print("Scaling completed")
        
        # Define output filename using the exact output name mapping
        output_filename = f"{output_base_name}_scaled.npy"
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
