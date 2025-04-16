import os
import sys
import numpy as np
from scipy.io import loadmat

def validate_noisy_neurograms(input_base):
    """
    Check if all noisy neurograms can be loaded correctly
    """
    problematic_files = []
    
    # Process TRAIN and TEST separately
    for dataset in ['TRAIN', 'TEST']:
        input_path = os.path.join(input_base, dataset)
        
        for dr_dir in sorted(os.listdir(input_path)):
            if not dr_dir.startswith('DR'):
                continue
            
            dr_input_path = os.path.join(input_path, dr_dir)
            
            for speaker_dir in os.listdir(dr_input_path):
                if speaker_dir.startswith('.'):
                    continue
                
                speaker_input_path = os.path.join(dr_input_path, speaker_dir)
                
                # Find all noisy .mat files
                noisy_files = [
                    os.path.join(speaker_input_path, f) 
                    for f in os.listdir(speaker_input_path) 
                    if f.endswith('_with_noise.mat')
                ]
                
                # Check each noisy file
                for file_path in noisy_files:
                    try:
                        mat_data = loadmat(file_path)
                        
                        # Check for required fields
                        if 'r_mean_downsampled' not in mat_data:
                            print(f"Missing 'r_mean_downsampled' in {file_path}")
                            problematic_files.append(file_path)
                            continue
                        
                        neurogram = mat_data['r_mean_downsampled']
                        
                        # Additional checks
                        if neurogram.size == 0:
                            print(f"Empty neurogram in {file_path}")
                            problematic_files.append(file_path)
                        
                        if len(neurogram.shape) != 2:
                            print(f"Unexpected neurogram shape in {file_path}: {neurogram.shape}")
                            problematic_files.append(file_path)
                    
                    except Exception as e:
                        print(f"Error loading {file_path}: {e}")
                        problematic_files.append(file_path)
    
    # Print summary
    print("\n--- Validation Summary ---")
    print(f"Total problematic files: {len(problematic_files)}")
    if problematic_files:
        print("Problematic files:")
        for file in problematic_files:
            print(file)
    else:
        print("All noisy neurograms loaded successfully!")
    
    return problematic_files

def main():
    input_base = '/pasteur/helix/scratch/mcampi/neurograms_wham/healthy/'
    
    # Validate noisy neurograms
    problematic_files = validate_noisy_neurograms(input_base)
    
    # Optional: exit with error code if problematic files found
    if problematic_files:
        sys.exit(1)

if __name__ == '__main__':
    main()
