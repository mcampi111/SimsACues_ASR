# %%
import numpy as np
import h5py
import scipy.io
import sklearn.preprocessing

# %%

# Define perturbation functions (as you had them before)
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


# %%

# Set random seed
np.random.seed(42)

# Load the original matrix
print("Loading matrix...")
f = h5py.File('TIMIT_neurogram_small.mat', 'r')
TIMIT_neurogram = np.array(f.get('TIMIT_neurogram')).T  # Transpose to get correct shape
f.close()

print("Original matrix shape:", TIMIT_neurogram.shape)
print("Original matrix stats:")
print("Min:", np.min(TIMIT_neurogram))
print("Max:", np.max(TIMIT_neurogram))
print("Mean:", np.mean(TIMIT_neurogram))


# %%

# Parameters
sampling_rate = 16000
max_jitter_ms_range = (3, 10)
num_bands_to_remove_range = (1, 4)
truncation_ratio_range = (0.3, 0.7)

# %%

# Get individual neurogram sizes
selected_files = scipy.io.loadmat('selected_files_list.mat')['selected_filenames']
n_files = len(selected_files.flatten())
samples_per_file = TIMIT_neurogram.shape[0] // n_files

# %%

# Create perturbed matrix
# Create perturbed matrix
TIMIT_neurogram_ANSD = np.zeros_like(TIMIT_neurogram)

# Apply perturbations to each neurogram
print("\nApplying perturbations...")
for i in range(n_files):
    if i % 100 == 0:
        print(f"Processing neurogram {i}/{n_files}")
    
    start_idx = i * samples_per_file
    end_idx = (i + 1) * samples_per_file
    
    current_neurogram = TIMIT_neurogram[start_idx:end_idx, :]
    
    # Randomly select perturbation type
    perturbation_type = np.random.choice(['jitter', 'loss', 'truncation'])
    
    if perturbation_type == 'jitter':
        max_jitter_ms = np.random.randint(*max_jitter_ms_range)
        perturbed_neurogram = apply_temporal_jitter(current_neurogram, max_jitter_ms, sampling_rate)
    elif perturbation_type == 'loss':
        num_bands = np.random.randint(*num_bands_to_remove_range)
        perturbed_neurogram = apply_selective_loss(current_neurogram, num_bands)
    else:  # truncation
        ratio = np.random.uniform(*truncation_ratio_range)
        perturbed_neurogram = apply_truncation(current_neurogram, ratio)
    
    TIMIT_neurogram_ANSD[start_idx:end_idx, :] = perturbed_neurogram

# Save perturbed matrix
print("\nSaving results...")
scipy.io.savemat('TIMIT_neurogram_small_ANSD.mat', {'TIMIT_neurogram': TIMIT_neurogram_ANSD})

# Scale the perturbed matrix
TIMIT_neurogram_ANSD_scaled = sklearn.preprocessing.scale(TIMIT_neurogram_ANSD)
np.save('TIMIT_neurogram_small_ANSD_scaled.npy', TIMIT_neurogram_ANSD_scaled)

print("\nProcessing complete!")
print("Original shape:", TIMIT_neurogram.shape)
print("ANSD shape:", TIMIT_neurogram_ANSD.shape)
print("Scaled ANSD shape:", TIMIT_neurogram_ANSD_scaled.shape)

# %%

# %%