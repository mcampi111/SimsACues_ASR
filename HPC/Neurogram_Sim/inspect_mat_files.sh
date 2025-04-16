#!/bin/bash
#SBATCH --job-name=inspect_mat_files
#SBATCH --output=logs/inspect_mat_files_%j.out
#SBATCH --error=logs/inspect_mat_files_%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

# Create logs directory if it doesn't exist
mkdir -p logs

# Load specific Python version
module load Python/3.11.5

/opt/gensoft/exe/Python/3.11.5/scripts/python3 <<EOF
import os
import h5py
import numpy as np
import scipy.io

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

# Let's also examine the original ANSD test file for comparison
noise_files.append('TIMIT_neurogram_ansd_test.mat')

# Set directory
timit_mat_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_mat'

print("=" * 80)
print("INSPECTING MAT FILE STRUCTURES")
print("=" * 80)

# Process each file
for filename in noise_files:
    print("\n" + "=" * 60)
    print(f"FILE: {filename}")
    print("=" * 60)
    
    try:
        # Full path to the input file
        input_path = os.path.join(timit_mat_dir, filename)
        
        # METHOD 1: Try with scipy.io.loadmat
        print("\nMETHOD 1: Using scipy.io.loadmat")
        print("-" * 40)
        try:
            mat_data = scipy.io.loadmat(input_path)
            print(f"Available keys: {list(mat_data.keys())}")
            
            # Examine each key
            data_keys = [k for k in mat_data.keys() if not k.startswith('__')]
            for key in data_keys:
                value = mat_data[key]
                shape_str = f"shape: {value.shape}" if hasattr(value, 'shape') else "no shape attribute"
                print(f"Key: {key}, Type: {type(value)}, {shape_str}")
                
                # If it's a complex object, inspect further
                if isinstance(value, np.ndarray) and value.dtype == np.dtype('O'):
                    print(f"  Contains objects of type: {type(value.item(0)) if value.size > 0 else 'empty'}")
        except Exception as e:
            print(f"scipy.io.loadmat error: {e}")
        
        # METHOD 2: Try with h5py
        print("\nMETHOD 2: Using h5py")
        print("-" * 40)
        try:
            with h5py.File(input_path, 'r') as f:
                print(f"Available keys: {list(f.keys())}")
                
                # Print file structure recursively
                def print_attrs(name, obj):
                    print(f"Path: {name}, Type: {type(obj)}", end="")
                    if isinstance(obj, h5py.Dataset):
                        print(f", Shape: {obj.shape}, Dtype: {obj.dtype}")
                    else:
                        print("")
                    
                    # Print attributes
                    for key, val in obj.attrs.items():
                        print(f"  Attribute: {key} = {val}")
                    
                    return None
                
                print("\nFile structure:")
                f.visititems(print_attrs)
        except Exception as e:
            print(f"h5py error: {e}")
            
        # Try to compare with what works for ANSD test file
        if filename == 'TIMIT_neurogram_ansd_test.mat':
            print("\nPROBING ANSD TEST FILE (known working file)")
            print("-" * 40)
            try:
                with h5py.File(input_path, 'r') as f:
                    print("Keys that worked in original script:")
                    data = f.get('TIMIT_neurogram_ansd')
                    if data is not None:
                        print(f"'TIMIT_neurogram_ansd' exists, Type: {type(data)}")
                        if hasattr(data, 'shape'):
                            print(f"Shape: {data.shape}")
                    else:
                        print("'TIMIT_neurogram_ansd' key not found")
            except Exception as e:
                print(f"Error probing ANSD file: {e}")
            
    except Exception as e:
        print(f"Overall error processing {filename}: {e}")

print("\n" + "=" * 80)
print("INSPECTION COMPLETE")
print("=" * 80)
EOF
