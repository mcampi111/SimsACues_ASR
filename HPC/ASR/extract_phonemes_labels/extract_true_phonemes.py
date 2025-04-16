#!/usr/bin/env python3
import os
import numpy as np
import re
from collections import defaultdict

def extract_phoneme_labels(data_dir, output_dir=None):
    """
    Extract true phoneme labels from neurogram filenames.
    
    Args:
        data_dir: Directory containing TIMIT neurogram data
        output_dir: Directory to save output files (defaults to current directory)
    """
    if output_dir is None:
        output_dir = os.getcwd()
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Define the phoneme mapping (61 to 39 phonemes) based on your existing code
    # This is based on the mapping in your TimitData.py
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
    
    # Walk through the directory structure
    print("Scanning directory structure...")
    for root, dirs, files in os.walk(data_dir):
        for file in files:
            # Skip non-neurogram files
            if not file.endswith('_neurogram_ansd_with_noise.mat') and not file.endswith('.wav'):
                continue
                
            # Extract phoneme information from filename
            match = re.match(pattern, file)
            if match:
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
                print(f"Warning: Couldn't parse filename: {file}")
    
    # Sort all phonemes by start time
    all_phonemes.sort(key=lambda x: x[1])
    
    # Print summary statistics
    print(f"Found {len(all_phonemes)} phoneme segments")
    print(f"Found {len(phoneme_to_index)} unique phonemes")
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
    
    # Save the arrays
    np.save(os.path.join(output_dir, "Phonemes39consecutive_true.npy"), phonemes_consecutive)
    np.save(os.path.join(output_dir, "Phonemes39_position_index_true.npy"), position_index)
    
    # Also save the phoneme mapping for reference
    with open(os.path.join(output_dir, "phoneme_mapping.txt"), "w") as f:
        f.write("Phoneme Mapping (index -> phoneme):\n")
        for phoneme, index in sorted(phoneme_to_index.items(), key=lambda x: x[1]):
            f.write(f"{index}: {phoneme}\n")
    
    print(f"Saved phoneme data to {output_dir}")
    print(f"Phonemes array shape: {phonemes_consecutive.shape}")
    print(f"Position index shape: {position_index.shape}")
    
    return phonemes_consecutive, position_index, phoneme_to_index

if __name__ == "__main__":
    # Set the paths for your data
    TRAIN_DATA_DIR = "/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise/TRAIN"
    OUTPUT_DIR = "/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/Phonemes39_posindex_labels/train/healthy"
    
    # Extract phoneme labels
    phonemes, positions, mapping = extract_phoneme_labels(TRAIN_DATA_DIR, OUTPUT_DIR)
    
    print("\nDone!")
