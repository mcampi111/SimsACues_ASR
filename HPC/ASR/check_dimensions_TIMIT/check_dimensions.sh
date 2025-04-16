#!/bin/bash
#SBATCH --job-name=check_all_dims
#SBATCH --output=dimension_check_all_%j.out
#SBATCH --error=dimension_check_all_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=24G
#SBATCH --cpus-per-task=1

# Load Python module
module load Python/3.11.5

# Run Python code to check dimensions of all files
/opt/gensoft/exe/Python/3.11.5/scripts/python3 <<EOF
import numpy as np
import os
import glob
import gc
import time

def check_directory(directory):
    print(f"\n=== Checking dimensions in {directory} ===")
    # Get all .npy files in the directory
    files = glob.glob(os.path.join(directory, "*.npy"))
    
    if not files:
        print(f"No .npy files found in {directory}")
        return
    
    # Sort files for consistent output
    files.sort()
    
    # Print header
    print(f"{'Filename':<50} {'Shape':<25} {'Has 150 features?':<20} {'Size (MB)':<15}")
    print("-" * 110)
    
    # Check each file
    for file_path in files:
        try:
            # Get file size on disk in MB
            file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
            
            # Load the file using memory mapping (doesn't load full data into memory)
            data = np.load(file_path, mmap_mode='r')
            shape = data.shape
            
            # Check if second dimension is 150
            has_150_features = "Yes" if shape[-1] == 150 else f"No ({shape[-1]})"
            
            # Print information
            filename = os.path.basename(file_path)
            print(f"{filename:<50} {str(shape):<25} {has_150_features:<20} {file_size_mb:.2f}")
            
            # To avoid memory issues, delete the data reference and force garbage collection
            del data
            gc.collect()
            
        except Exception as e:
            print(f"{filename:<50} ERROR: {str(e)}")
        
        # Small pause to ensure memory is released
        time.sleep(0.5)

# Summary header
print("=" * 110)
print("COMPLETE DIMENSION CHECK FOR ALL NEUROGRAM FILES")
print("=" * 110)

# Define all directories to check
directories = [
    '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro',
    '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro/train',
    '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro_ANSD',
    '/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/TIMIT_Neuro_ANSD/train'
]

# Check each directory with recovery between checks
for directory in directories:
    try:
        check_directory(directory)
        # Sleep between directories to ensure memory cleanup
        time.sleep(5)
    except Exception as e:
        print(f"ERROR checking directory {directory}: {str(e)}")
        time.sleep(5)
        continue

print("\nComplete dimension check finished successfully.")
EOF
