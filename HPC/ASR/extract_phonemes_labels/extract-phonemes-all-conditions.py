#!/usr/bin/env python3
import os
import numpy as np
import re
from collections import defaultdict
import argparse

def extract_phoneme_labels(data_dir, output_dir, dataset_type, condition=None):
    """
    Extract true phoneme labels from neurogram filenames.
    
    Args:
        data_dir: Directory containing TIMIT neurogram data
        output_dir: Directory to save output files
        dataset_type: 'train' or 'test'
        condition: Specific noise condition to filter for, e.g., 'default', 'snr0', etc.
                  If None, process all conditions
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
    
    # Regex to extract phoneme and timing info from filenames
    pattern = r'([A-Z]+\d+)_([a-z\-#]+)_(\d+)_(\d+).*'
    
    # Handle condition-specific filtering
    condition_suffix = ""
    snr_pattern = ""
    
    if condition:
        if condition == "default":
            condition_suffix = "_default"
            snr_pattern = "_default"
            print(f"Processing {dataset_type} data with condition: default")
        elif condition == "0":
            condition_suffix = "_snr0"
            snr_pattern = "snr0.0"
            print(f"Processing {dataset_type} data with condition: SNR 0")
        elif condition == "5":
            condition_suffix = "_snr5"
            snr_pattern = "snr5.0"
            print(f"Processing {dataset_type} data with condition: SNR 5")
        elif condition == "10":
            condition_suffix = "_snr10"
            snr_pattern = "snr10.0"
            print(f"Processing {dataset_type} data with condition: SNR 10")
        elif condition == "15":
            condition_suffix = "_snr15"
            snr_pattern = "snr15.0"
            print(f"Processing {dataset_type} data with condition: SNR 15")
        elif condition == "neg5":
            condition_suffix = "_snr-5"
            snr_pattern = "snr-5.0"
            print(f"Processing {dataset_type} data with condition: SNR -5")
        else:
            raise ValueError(f"Unknown condition: {condition}. Use 'default', '0', '5', '10', '15', or 'neg5'")
    else:
        print(f"Processing all {dataset_type} data conditions")
    
    # Walk through the directory structure
    print(f"Scanning directory: {data_dir}")
    file_count = 0
    matched_count = 0
    matched_files_sample = []
    
    for root, dirs, files in os.walk(data_dir):
        for file in files:
            file_count += 1
            
            # Filter by condition if specified
            if condition:
                if snr_pattern not in file:
                    continue
            
            # Process only neurogram files
            if not (file.endswith('.mat') and 'neurogram' in file):
                continue
            
            # Extract phoneme information from filename
            match = re.match(pattern, file)
            if match:
                matched_count += 1
                sentence_id, phoneme, start_time, end_time = match.groups()
                
                # If we're in the first few matches, save example filenames for debugging
                if matched_count <= 5:
                    matched_files_sample.append(file)
                
                # Apply phoneme mapping to get to 39 phonemes
                if phoneme in phoneme_map_61_to_39:
                    phoneme = phoneme_map_61_to_39[phoneme]
                
                # Assign a numeric index to each unique phoneme
                if phoneme not in phoneme_to_index:
                    phoneme_to_index[phoneme] = current_index
                    current_index += 1
                
                all_phonemes.append((phoneme, int(start_time), int(end_time), os.path.join(root, file)))
            else:
                # Print details for the first few unmatched files to help debugging
                if file_count <= 5:
                    print(f"Warning: Couldn't parse filename: {file}")
    
    print(f"Processed {file_count} files, matched {matched_count} files")
    if matched_files_sample:
        print(f"Sample matched files: {', '.join(matched_files_sample[:3])}")
    
    if not all_phonemes:
        print("No matching phoneme segments found! Check your data path and condition.")
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
    
    # Create output filenames with appropriate suffixes
    phoneme_file = f"Phonemes39consecutive_true_{dataset_type}{condition_suffix}.npy"
    position_file = f"Phonemes39_position_index_true_{dataset_type}{condition_suffix}.npy"
    mapping_file = f"phoneme_mapping_{dataset_type}{condition_suffix}.txt"
    
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

def process_all_conditions(base_dir, output_dir, dataset_type):
    """Process all noise conditions for a given dataset type."""
    # First process the default condition
    extract_phoneme_labels(base_dir, output_dir, dataset_type, "default")
    
    # Then process each SNR condition
    for condition in ["0", "5", "10", "15", "neg5"]:
        extract_phoneme_labels(base_dir, output_dir, dataset_type, condition)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Extract phoneme labels from TIMIT neurogram filenames.')
    parser.add_argument('--dataset', choices=['train', 'test'], required=True, 
                        help='Dataset type to process (train or test)')
    parser.add_argument('--condition', default=None,
                        help='Specific condition to process (default, 0, 5, 10, 15, neg5). If not specified, process all conditions.')
    parser.add_argument('--data_dir', required=True,
                        help='Directory containing the neurogram data')
    parser.add_argument('--output_dir', required=True,
                        help='Directory to save output files')
    
    args = parser.parse_args()
    
    # Process specified condition or all conditions
    if args.condition:
        extract_phoneme_labels(args.data_dir, args.output_dir, args.dataset, args.condition)
    else:
        process_all_conditions(args.data_dir, args.output_dir, args.dataset)
    
    print("\nDone!")
