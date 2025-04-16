import os
import numpy as np
import h5py
import scipy.io as sio

def diagnose_mat_file(file_path):
    """
    Attempt to open .mat file using different methods and provide detailed diagnostics
    """
    print(f"\nDiagnosing file: {file_path}")
    
    # File basic information
    print("File size:", os.path.getsize(file_path), "bytes")
    
    # Method 1: scipy.io.loadmat
    try:
        print("\nMethod 1: scipy.io.loadmat")
        mat_data = sio.loadmat(file_path)
        print("Keys found:", list(mat_data.keys()))
        
        # Check for r_mean_downsampled
        if 'r_mean_downsampled' in mat_data:
            print("r_mean_downsampled shape:", mat_data['r_mean_downsampled'].shape)
            print("r_mean_downsampled dtype:", mat_data['r_mean_downsampled'].dtype)
    except Exception as e:
        print("scipy.io.loadmat failed:", str(e))
    
    # Method 2: h5py
    try:
        print("\nMethod 2: h5py")
        with h5py.File(file_path, 'r') as f:
            print("H5PY keys:", list(f.keys()))
            
            # Try to access r_mean_downsampled if it exists
            for key in f.keys():
                try:
                    dataset = f[key]
                    print(f"Key {key}:")
                    print("  Shape:", dataset.shape)
                    print("  Dtype:", dataset.dtype)
                except Exception as e:
                    print(f"  Error accessing {key}: {e}")
    except Exception as e:
        print("h5py failed:", str(e))
    
    # Method 3: raw binary inspection
    try:
        print("\nMethod 3: Raw binary inspection")
        with open(file_path, 'rb') as f:
            # Read first 1024 bytes
            header = f.read(1024)
            print("First 1024 bytes (hex):", header.hex())
    except Exception as e:
        print("Raw binary inspection failed:", str(e))

def diagnose_mat_files_in_directory(directory):
    """
    Diagnose all .mat files in a given directory
    """
    for filename in os.listdir(directory):
        if filename.endswith('_neurogram_with_noise.mat'):
            file_path = os.path.join(directory, filename)
            diagnose_mat_file(file_path)

# Specify the directory
directory = '/pasteur/helix/scratch/mcampi/neurograms_wham/healthy/TRAIN/DR1/FCJF0/'

# Run diagnosis
diagnose_mat_files_in_directory(directory)
