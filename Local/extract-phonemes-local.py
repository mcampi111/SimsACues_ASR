#!/usr/bin/env python3
import os
import numpy as np
import re
from collections import defaultdict
import argparse

def extract_phoneme_labels(data_dir, output_dir, dataset_type, dataset_name, noise_level=None):
    """
    Extract true phoneme labels from neurogram filenames.
    
    Args:
        data_dir: Directory containing TIMIT neurogram data
        output_dir: Directory to save output files
        dataset_type: 'train' or 'test'
        dataset_name: Name of the dataset ('healthy_silence', 'healthy_noise', 'ansd_silence')
        noise_level: Specific noise level to process (e.g., 'random', 'snr-5.0', 'snr0.0', etc.)
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define the phoneme mapping (61 to 39 phonemes)
    phoneme_map_61_to_39 = {
        'ao': 'aa', 'ax': 'ah', 'ax-h': 'ah', 'axr': 'er', 'hv': 'hh',
        'ix': 'ih', 'el': 'l', 'em': 'm', 'en': 'n', 'nx': 'n',
        'eng': 'ng', 'zh': 'sh', 'ux': 'uw',
        'pcl': 'h#', 'tcl': 'h#', 'kcl': 'h#', 'bcl': 'h#', 
        'dcl': 'h#', 'gcl': 'h#', 'pau': 'h#', 'epi': 'h#'
    }
    
    # Create a dictionary to map 39 phonemes to consistent numeric labels
    phoneme_to_index = {}
    current_index = 0
    
    # Track all discovered phonemes and their time ranges
    all_phonemes = []  # List of (phoneme, start_time, end_time, file_path)
    
    # Regex patterns to match different filename formats
    # Pattern for healthy silence neurograms
    silence_pattern = r'([A-Z]+\d+)_([a-z\-#]+)_(\d+)_(\d+)_neurogram\.mat'
    
    # Pattern for healthy noise neurograms
    if noise_level is None:
        noise_pattern = r'([A-Z]+\d+)_([a-z\-#]+)_(\d+)_(\d+)_neurogram_with_noise\.mat'
    else:
        # For specific noise levels
        noise_suffix = f"_neurogram_with_noise_{noise_level}"
        noise_pattern = f'([A-Z]+\\d+)_([a-z\\-#]+)_(\\d+)_(\\d+){noise_suffix}\\.mat'
    
    # Pattern for ANSD silence neurograms
    if noise_level is None or noise_level == 'default':
        ansd_pattern = r'([A-Z]+\d+)_([a-z\-#]+)_(\d+)_(\d+)_neurogram_ansd\.mat'
    else:
        # For specific ANSD settings
        ansd_suffix = f"_neurogram_ansd_{noise_level}"
        ansd_pattern = f'([A-Z]+\\d+)_([a-z\\-#]+)_(\\d+)_(\\d+){ansd_suffix}\\.mat'
    
    # Select the appropriate pattern based on dataset_name
    if dataset_name == 'healthy_silence':
        pattern = silence_pattern
        file_suffix = '_neurogram.mat'
    elif dataset_name == 'healthy_noise':
        pattern = noise_pattern
        if noise_level is None:
            file_suffix = '_neurogram_with_noise.mat'
        else:
            file_suffix = f'_neurogram_with_noise_{noise_level}.mat'
    elif dataset_name == 'ansd_silence':
        pattern = ansd_pattern
        if noise_level is None or noise_level == 'default':
            file_suffix = '_neurogram_ansd.mat'
        else:
            file_suffix = f'_neurogram_ansd_{noise_level}.mat'
    else:
        raise ValueError(f"Unknown dataset name: {dataset_name}. Please use 'healthy_silence', 'healthy_noise', or 'ansd_silence'")
    
    # Walk through the directory structure
    print(f"Scanning directory: {data_dir}")
    print(f"Processing dataset: {dataset_name}" + (f" with noise level: {noise_level}" if noise_level else ""))
    file_count = 0
    matched_count = 0
    
    # Add this for debugging
    print("Example files found:")
    for root, dirs, files in os.walk(data_dir):
        for i, file in enumerate(files):
            if i < 5:  # Print first 5 files
                print(f"  {file}")
        break  # Just look at the first directory
    
    for root, dirs, files in os.walk(data_dir):
        for file in files:
            file_count += 1
            
            # Skip files that don't match our expected suffix
            if dataset_name == 'healthy_silence' and not file.endswith('_neurogram.mat'):
                continue
            elif dataset_name == 'healthy_noise':
                if noise_level is None and not file.endswith('_neurogram_with_noise.mat'):
                    continue
                elif noise_level is not None and not file.endswith(f'_neurogram_with_noise_{noise_level}.mat'):
                    continue
            elif dataset_name == 'ansd_silence':
                if noise_level is None or noise_level == 'default':
                    if not file.endswith('_neurogram_ansd.mat'):
                        continue
                elif not file.endswith(f'_neurogram_ansd_{noise_level}.mat'):
                    continue
            
            # Extract phoneme information from filename
            match = re.match(pattern, file)
            if match:
                matched_count += 1
                sentence_id, phoneme, start_time, end_time = match.groups()
                
                # Apply phoneme mapping to get to 39 phonemes
                if phoneme in phoneme_map_61_to_39:
                    phoneme = phoneme_map_61_to_39[phoneme]
                
                # Assign a numeric index to each unique phoneme
                if phoneme not in phoneme_to_index:
                    phoneme_to_index[phoneme] = current_index
                    current_index += 1
                
                all_phonemes.append((phoneme, int(start_time), int(end_time), os.path.join(root, file)))
            else:
                # If we're encountering many unmatched files, print a few examples
                if matched_count == 0 and file_count <= 5:
                    print(f"Example unmatched file: {file}")
    
    print(f"Processed {file_count} files, matched {matched_count} files")
    
    if not all_phonemes:
        print("No matching phoneme segments found! Check your data path and file patterns.")
        print(f"Make sure files follow the pattern for {dataset_name} dataset with noise level {noise_level}")
        return None, None, None
    
    # Sort all phonemes by start time
    all_phonemes.sort(key=lambda x: x[1])
    
    # Print summary statistics
    print(f"Found {len(all_phonemes)} phoneme segments")
    print(f"Found {len(phoneme_to_index)} unique phonemes")
    
    # Ensure phonemes are printed in order of their index
    for phoneme, index in sorted(phoneme_to_index.items(), key=lambda x: x[1]):
        print(f"  {phoneme}: {index}")
    
    # Find the maximum time value to set the length of our arrays
    max_time = max(end_time for _, _, end_time, _ in all_phonemes)
    print(f"Maximum time: {max_time}")
    
    # Create the phoneme array (will have one entry per time step)
    phonemes_consecutive = np.zeros(max_time + 1, dtype=np.float32)
    
    # Fill in the phoneme array
    for phoneme, start_time, end_time, _ in all_phonemes:
        phoneme_index = phoneme_to_index[phoneme]
        phonemes_consecutive[start_time:end_time+1] = phoneme_index
    
    # Create position index array (used by your model)
    # This will find stable regions where the phoneme doesn't change
    position_index = []
    for i in range(8, len(phonemes_consecutive)):
        # Check if phoneme is stable for 8 consecutive time steps
        if phonemes_consecutive[i] == phonemes_consecutive[i-8]:
            position_index.append(i)
    
    position_index = np.array(position_index, dtype=np.int32).reshape(-1, 1)
    
    # Create output filenames with noise level
    noise_suffix = f"_{noise_level}" if noise_level else ""
    phoneme_file = f"Phonemes39consecutive_true_{dataset_type}_{dataset_name}{noise_suffix}.npy"
    position_file = f"Phonemes39_position_index_true_{dataset_type}_{dataset_name}{noise_suffix}.npy"
    mapping_file = f"phoneme_mapping_{dataset_type}_{dataset_name}{noise_suffix}.txt"
    
    # Save the arrays
    np.save(os.path.join(output_dir, phoneme_file), phonemes_consecutive)
    np.save(os.path.join(output_dir, position_file), position_index)
    
    # Also save the phoneme mapping for reference
    with open(os.path.join(output_dir, mapping_file), "w") as f:
        f.write("Phoneme Mapping (index -> phoneme):\n")
        for phoneme, index in sorted(phoneme_to_index.items(), key=lambda x: x[1]):
            f.write(f"{index}: {phoneme}\n")
    
    print(f"Saved phoneme data to {output_dir}")
    print(f"Phonemes array shape: {phonemes_consecutive.shape}")
    print(f"Position index shape: {position_index.shape}")
    
    return phonemes_consecutive, position_index, phoneme_to_index

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Extract phoneme labels from TIMIT neurogram filenames.')
    parser.add_argument('--dataset', choices=['train', 'test'], required=True, 
                        help='Dataset type to process (train or test)')
    parser.add_argument('--dataset_name', choices=['healthy_silence', 'healthy_noise', 'ansd_silence'], required=True,
                        help='Name of the dataset (healthy_silence, healthy_noise, ansd_silence)')
    parser.add_argument('--data_dir', required=True,
                        help='Directory containing the neurogram data')
    parser.add_argument('--output_dir', required=True,
                        help='Directory to save output files')
    parser.add_argument('--noise_level', default=None,
                        help='Specific noise level to process (e.g., random, snr-5.0, snr0.0, etc.)')
    
    args = parser.parse_args()
    
    # Process the data
    extract_phoneme_labels(args.data_dir, args.output_dir, args.dataset, args.dataset_name, args.noise_level)
    
    print("\nDone!")
    



