# %%
import os
import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat

# %%

##############################
# FUNCTIONS ANSD Perturbation#
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

# %%

# Mapping dictionary for phoneme categories
phoneme_category_map = {
    'm': 'Nasal','n': 'Nasal', 'ng': 'Nasal','em': 'Nasal', 'en': 'Nasal', 'nx': 'Nasal',
    'iy': 'Vowel',  'ih': 'Vowel', 'ix': 'Vowel', 'ey': 'Vowel','eh': 'Vowel', 'ae': 'Vowel',
    'aa': 'Vowel','aw': 'Vowel','ay': 'Vowel','ah': 'Vowel','ax': 'Vowel','ax-h': 'Vowel',
    'ao': 'Vowel','oy': 'Vowel','ow': 'Vowel','uh': 'Vowel','uw': 'Vowel', 'ux': 'Vowel',
    'er': 'Vowel','axr': 'Vowel',
    'l': 'Liquid','r': 'Liquid',
    'w': 'Glide', 'y': 'Glide',
    's': 'Fricative','z': 'Fricative','f': 'Fricative','v': 'Fricative','th': 'Fricative',
    'dh': 'Fricative',  'sh': 'Fricative','hh': 'Fricative','hv': 'Fricative',
    't': 'Stop','d': 'Stop','p': 'Stop','b': 'Stop','k': 'Stop','g': 'Stop','tcl': 'Stop',
    'dcl': 'Stop','pcl': 'Stop','bcl': 'Stop','kcl': 'Stop', 'gcl': 'Stop',
    'ch': 'Affricate','jh': 'Affricate',
    'dx': 'Flap',
    'q': 'Glottal Stop',
    'epi': 'Epenthetic',
    'h#': 'Silence',
    'el': 'Syllabic Consonant'
}

# %%
#######################
#DIRECTORIES and SEEDs#
#######################

# Set random seed for reproducibility
np.random.seed(42)

# Define paths
base_input_paths = [
    '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TEST/',
    '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TRAIN/'
]

base_output_paths = [
    '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TEST/',
    '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TRAIN/'
]


# %%

# Perturbation Parameters
sampling_rate = 16000
max_jitter_ms_range = (3, 10)
num_bands_to_remove_range = (1, 4)
truncation_ratio_range = (0.3, 0.7)

# Process each base path (TEST and TRAIN)
for base_input_path, base_output_path in zip(base_input_paths, base_output_paths):
    # Iterate through DR directories
    for dr_dir in sorted(os.listdir(base_input_path)):
        # Skip .DS_Store and other non-directory files
        if not dr_dir.startswith('DR'):
            continue
        
        dr_input_path = os.path.join(base_input_path, dr_dir)
        dr_output_path = os.path.join(base_output_path, dr_dir)
        
        # Iterate through speaker directories
        for speaker_dir in os.listdir(dr_input_path):
            # Skip .DS_Store and other non-directory files
            if speaker_dir.startswith('.'):
                continue
            
            speaker_input_path = os.path.join(dr_input_path, speaker_dir)
            speaker_output_path = os.path.join(dr_output_path, speaker_dir)
            
            # Create output directory if it doesn't exist
            os.makedirs(speaker_output_path, exist_ok=True)
            
            # List to store neurograms for this speaker
            neurograms_ansd_data = []
            
            # Process each .mat neurogram file
            for filename in os.listdir(speaker_input_path):
                # Skip .DS_Store and other non-.mat files
                if not filename.endswith('.mat'):
                    continue
                
                # Load neurogram
                file_path = os.path.join(speaker_input_path, filename)
                mat_data = loadmat(file_path)
                
                neurogram = mat_data['r_mean']
                center_frequencies = mat_data['center_frequencies'].flatten()
                
                # Extract phoneme from filename
                phoneme = filename.split('_')[1]
                category = phoneme_category_map.get(phoneme, 'Unknown')
                
                # Randomize perturbation parameters
                max_jitter_ms = np.random.randint(*max_jitter_ms_range)
                num_bands_to_remove = np.random.randint(*num_bands_to_remove_range)
                truncation_ratio = np.random.uniform(*truncation_ratio_range)
                
                # Apply perturbations
                neurogram_jittered = apply_temporal_jitter(neurogram, max_jitter_ms, sampling_rate)
                neurogram_selective_loss = apply_selective_loss(neurogram, num_bands_to_remove)
                neurogram_truncated = apply_truncation(neurogram, truncation_ratio)
                
                # Store data
                neurograms_ansd_data.append({
                    'Speaker': speaker_dir,
                    'Phoneme': phoneme,
                    'Category': category,
                    'Original': neurogram,
                    'Temporal_Jitter': neurogram_jittered,
                    'Selective_Loss': neurogram_selective_loss,
                    'Truncation': neurogram_truncated,
                    'CenterFrequencies': center_frequencies,
                    'Jitter_ms': max_jitter_ms,            
                    'Bands_Removed': num_bands_to_remove,   
                    'Truncation_Ratio': truncation_ratio    
                })
            
            # Convert to DataFrame
            df_neurograms_ANSD = pd.DataFrame(neurograms_ansd_data)
            
            # Save as pickle file in the speaker's output directory
            output_pkl_path = os.path.join(speaker_output_path, f'{speaker_dir}_neurograms_ANSD.pkl')
            df_neurograms_ANSD.to_pickle(output_pkl_path)
            
            print(f"Processed {speaker_dir} in {dr_dir} - Saved {output_pkl_path}")

print("Neurogram perturbation complete!")

# %%


# %%


# %%



# %%

# %%


# %%


# %%


# %%