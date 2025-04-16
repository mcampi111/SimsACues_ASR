# %%
import os
import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat

# %%
##############################
# PERTURBATION FUNCTIONS     #
##############################

def apply_temporal_jitter(neurogram, max_jitter_ms, sampling_rate):
    """ Introduces scattered, small delays (temporal jitter) in neural responses across the neurogram. """
    neurogram_jittered = neurogram.copy()
    max_jitter_samples = int((max_jitter_ms / 1000) * sampling_rate)
    
    for band in range(neurogram.shape[1]):
        for i in range(neurogram.shape[0]):
            jitter = np.random.randint(-1, max_jitter_samples)  # Random jitter within the range
            new_index = i + jitter
            if 0 <= new_index < neurogram.shape[0]:
                neurogram_jittered[new_index, band] = neurogram[i, band]
            else:
                neurogram_jittered[i, band] = 0  # Set to zero if out of bounds after jitter

    return neurogram_jittered

def apply_scattered_jitter(neurogram, max_time_jitter_ms, max_freq_jitter_bands, sampling_rate):
    """
    Introduces scattered jitter in both time and frequency domains.
    """
    neurogram_jittered = np.zeros_like(neurogram)
    max_time_jitter_samples = int((max_time_jitter_ms / 1000) * sampling_rate)
    num_time_points, num_freq_bands = neurogram.shape
    
    # Create jitter matrices for time and frequency
    time_jitters = np.random.randint(-max_time_jitter_samples, max_time_jitter_samples + 1, neurogram.shape)
    freq_jitters = np.random.randint(-max_freq_jitter_bands, max_freq_jitter_bands + 1, neurogram.shape)
    
    # Apply scattered jitter
    for t in range(num_time_points):
        for f in range(num_freq_bands):
            # Calculate new indices with jitter
            new_time = t + time_jitters[t, f]
            new_freq = f + freq_jitters[t, f]
            
            # Check if new indices are within bounds
            if (0 <= new_time < num_time_points) and (0 <= new_freq < num_freq_bands):
                neurogram_jittered[new_time, new_freq] = neurogram[t, f]
    
    return neurogram_jittered

def apply_selective_loss(neurogram, max_bands_to_remove):
    """ Randomly removes a specified number of neural responses in different frequency bands. """
    neurogram_lost = neurogram.copy()
    max_bands_available = neurogram.shape[1]
    bands_to_remove = np.random.choice(max_bands_available, max_bands_to_remove, replace=False)
    for band in bands_to_remove:
        neurogram_lost[:, band] = 0  # Zero out the selected bands
    return neurogram_lost

def apply_truncation(neurogram, truncation_ratio):
    """ Truncates (reduces) neural responses above a threshold based on the neurogram's max amplitude. """
    neurogram_truncated = neurogram.copy()
    threshold = truncation_ratio * np.max(neurogram)  # Threshold as a function of neurogram's max value
    neurogram_truncated[neurogram > threshold] = threshold  # Cap values above threshold
    return neurogram_truncated

def process_neurograms(input_path, output_path, is_train=True):
    """
    Process all neurograms maintaining directory structure and adding '_ansd' to filenames
    """
    # Perturbation parameters
    sampling_rate = 16000
    max_jitter_ms_range = (3, 10)
    max_freq_jitter_bands_range = (1, 4)
    num_bands_to_remove_range = (1, 4)
    truncation_ratio_range = (0.3, 0.7)
    
    processed_count = 0
    
    # Walk through the directory structure
    for dr_dir in sorted(os.listdir(input_path)):
        if not dr_dir.startswith('DR'):
            continue
            
        dr_path = os.path.join(input_path, dr_dir)
        dr_output_path = os.path.join(output_path, dr_dir)
        os.makedirs(dr_output_path, exist_ok=True)
        print(f"Processing {dr_dir}...")
        
        for speaker_dir in os.listdir(dr_path):
            if speaker_dir.startswith('.'):
                continue
                
            speaker_path = os.path.join(dr_path, speaker_dir)
            speaker_output_path = os.path.join(dr_output_path, speaker_dir)
            os.makedirs(speaker_output_path, exist_ok=True)
            print(f"Processing speaker {speaker_dir}...")
            
            # Process each .mat file
            for filename in os.listdir(speaker_path):
                if not filename.endswith('_neurogram.mat'):
                    continue
                    
                # Load the neurogram
                file_path = os.path.join(speaker_path, filename)
                mat_data = loadmat(file_path)
                
                # Get the neurogram data
                neurogram = mat_data['r_mean_downsampled']
                
                # Randomly choose perturbation type
                perturbation_type = np.random.choice(['scattered_jitter', 'jitter', 'loss', 'truncation'])
                
                # Apply random perturbation
                if perturbation_type == 'scattered_jitter':
                    max_jitter_ms = np.random.randint(*max_jitter_ms_range)
                    max_freq_jitter = np.random.randint(*max_freq_jitter_bands_range)
                    perturbed = apply_scattered_jitter(neurogram, max_jitter_ms, max_freq_jitter, sampling_rate)
                elif perturbation_type == 'jitter':
                    max_jitter_ms = np.random.randint(*max_jitter_ms_range)
                    perturbed = apply_temporal_jitter(neurogram, max_jitter_ms, sampling_rate)
                elif perturbation_type == 'loss':
                    num_bands = np.random.randint(*num_bands_to_remove_range)
                    perturbed = apply_selective_loss(neurogram, num_bands)
                else:  # truncation
                    ratio = np.random.uniform(*truncation_ratio_range)
                    perturbed = apply_truncation(neurogram, ratio)
                
                # Create output filename (add _ansd before .mat)
                base_name = filename[:-4]  # remove .mat
                output_filename = f"{base_name}_ansd.mat"
                output_file_path = os.path.join(speaker_output_path, output_filename)
                
                # Save perturbed neurogram
                savemat(output_file_path, {'r_mean_downsampled': perturbed})
                
                processed_count += 1
                print(f"Processed {filename} with {perturbation_type}")
    
    print(f"Processed and saved {processed_count} neurograms")

# %%

# Set random seed for reproducibility
np.random.seed(42)

# Define base paths for input and output
input_base = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes'
output_base = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes'

# %%
# Define paths
base_input_paths = [
    #os.path.join(input_base, 'TEST'),
    os.path.join(input_base, 'TRAIN')
]

output_paths = [
    #os.path.join(output_base, 'TEST'),
    os.path.join(output_base, 'TRAIN')
]
# %%
# Create output directories if they don't exist
for output_path in output_paths:
    os.makedirs(output_path, exist_ok=True)

# %%    

# Process TRAIN and TEST separately
for input_path, output_path in zip(base_input_paths, output_paths):
    print(f"\nProcessing {input_path} -> {output_path}...")
    process_neurograms(
        input_path, 
        output_path,
        is_train='TRAIN' in input_path
    )

print("\nAll processing complete!")

# %%

# %%

# %%
###############
#CHECK output # TRAIN
###############
###############

# %%
# Let's pick one specific neurogram to compare
import os
from scipy.io import loadmat
import numpy as np

# Define paths to original and perturbed directories (changed to TRAIN)
orig_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TRAIN/DR1'
pert_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TRAIN/DR1'

# Get first speaker directory
speaker_dir = next(d for d in os.listdir(orig_dir) if not d.startswith('.'))

# Get first neurogram file
orig_speaker_path = os.path.join(orig_dir, speaker_dir)
pert_speaker_path = os.path.join(pert_dir, speaker_dir)

# Get first .mat file
orig_file = next(f for f in os.listdir(orig_speaker_path) if f.endswith('_neurogram.mat'))
pert_file = orig_file[:-4] + '_ansd.mat'  # corresponding perturbed file

# Load both files
orig_data = loadmat(os.path.join(orig_speaker_path, orig_file))
pert_data = loadmat(os.path.join(pert_speaker_path, pert_file))

# Print information
print("Original file:", orig_file)
print("Perturbed file:", pert_file)
print("\nOriginal shape:", orig_data['r_mean_downsampled'].shape)
print("Perturbed shape:", pert_data['r_mean_downsampled'].shape)
print("\nAre shapes identical?", orig_data['r_mean_downsampled'].shape == pert_data['r_mean_downsampled'].shape)
print("Are values different?", not np.array_equal(orig_data['r_mean_downsampled'], pert_data['r_mean_downsampled']))

# Print some basic statistics
print("\nOriginal stats:")
print("Min:", np.min(orig_data['r_mean_downsampled']))
print("Max:", np.max(orig_data['r_mean_downsampled']))
print("Mean:", np.mean(orig_data['r_mean_downsampled']))

print("\nPerturbed stats:")
print("Min:", np.min(pert_data['r_mean_downsampled']))
print("Max:", np.max(pert_data['r_mean_downsampled']))
print("Mean:", np.mean(pert_data['r_mean_downsampled']))

# %%

# %%
#
###############
###############
#CHECK output # TEST
###############
###############

# %%
# Let's pick one specific neurogram to compare
# For example, from TEST/DR1/First_speaker directory
import os
from scipy.io import loadmat
import numpy as np


# Define paths to original and perturbed directories
orig_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TEST/DR1'
pert_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TEST/DR1'

# Get first speaker directory
speaker_dir = next(d for d in os.listdir(orig_dir) if not d.startswith('.'))

# Get first neurogram file
orig_speaker_path = os.path.join(orig_dir, speaker_dir)
pert_speaker_path = os.path.join(pert_dir, speaker_dir)

# Get first .mat file
orig_file = next(f for f in os.listdir(orig_speaker_path) if f.endswith('_neurogram.mat'))
pert_file = orig_file[:-4] + '_ansd.mat'  # corresponding perturbed file

# Load both files
orig_data = loadmat(os.path.join(orig_speaker_path, orig_file))
pert_data = loadmat(os.path.join(pert_speaker_path, pert_file))

# Print information
print("Original file:", orig_file)
print("Perturbed file:", pert_file)
print("\nOriginal shape:", orig_data['r_mean_downsampled'].shape)
print("Perturbed shape:", pert_data['r_mean_downsampled'].shape)
print("\nAre shapes identical?", orig_data['r_mean_downsampled'].shape == pert_data['r_mean_downsampled'].shape)
print("Are values different?", not np.array_equal(orig_data['r_mean_downsampled'], pert_data['r_mean_downsampled']))

# Print some basic statistics
print("\nOriginal stats:")
print("Min:", np.min(orig_data['r_mean_downsampled']))
print("Max:", np.max(orig_data['r_mean_downsampled']))
print("Mean:", np.mean(orig_data['r_mean_downsampled']))

print("\nPerturbed stats:")
print("Min:", np.min(pert_data['r_mean_downsampled']))
print("Max:", np.max(pert_data['r_mean_downsampled']))
print("Mean:", np.mean(pert_data['r_mean_downsampled']))

# %%


# %%




# %%




# %%




# %%




# %%
