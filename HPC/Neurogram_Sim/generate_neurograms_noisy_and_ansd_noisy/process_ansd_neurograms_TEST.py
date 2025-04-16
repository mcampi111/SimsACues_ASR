import os
import sys
import numpy as np
from scipy.io import loadmat, savemat
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler('ansd_neurogram_processing_test.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

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
    
    # Ensure we don't try to remove more bands than available
    max_bands_to_remove = min(max_bands_to_remove, max_bands_available)
    
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

def process_test_neurograms(input_base, output_base, task_id, num_tasks):
    # Set random seed for reproducibility
    np.random.seed(42 + task_id)
    
    # Perturbation parameters
    sampling_rate = 16000
    max_jitter_ms_range = (3, 10)
    max_freq_jitter_bands_range = (1, 4)
    num_bands_to_remove_range = (1, 4)
    truncation_ratio_range = (0.3, 0.7)
    
    # Input and output paths for TEST
    input_path = os.path.join(input_base, 'TEST')
    output_path = os.path.join(output_base, 'TEST')
    os.makedirs(output_path, exist_ok=True)
    
    # Collect all .mat files in TEST
    all_files = []
    for dr_dir in sorted(os.listdir(input_path)):
        if not dr_dir.startswith('DR'):
            continue
        
        dr_input_path = os.path.join(input_path, dr_dir)
        
        for speaker_dir in os.listdir(dr_input_path):
            if speaker_dir.startswith('.'):
                continue
            
            speaker_input_path = os.path.join(dr_input_path, speaker_dir)
            
            # Find all noisy .mat files in TEST with different SNR conditions
            files_in_speaker = [
                os.path.join(speaker_input_path, f) 
                for f in os.listdir(speaker_input_path) 
                if '_neurogram_with_noise_' in f and f.endswith('.mat')
            ]
            all_files.extend(files_in_speaker)
    
    # Distribute files across tasks
    files_per_task = len(all_files) // num_tasks
    start_idx = task_id * files_per_task
    end_idx = start_idx + files_per_task if task_id < num_tasks - 1 else len(all_files)
    
    task_files = all_files[start_idx:end_idx]
    
    logging.info(f"Processing TEST: {len(task_files)} files for task {task_id}")
    logging.info(f"Total files found: {len(all_files)}")
    
    # Process files for this task
    for file_path in task_files:
        try:
            # Reconstruct output path
            relative_path = os.path.relpath(file_path, input_path)
            output_file_path = os.path.join(output_path, relative_path)
            
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_file_path), exist_ok=True)
            
            # Replace neurogram_with_noise with neurogram_with_noise_ansd
            output_file_path = output_file_path.replace('neurogram_with_noise', 'neurogram_with_noise_ansd')
            
            # Skip if file already exists
            if os.path.exists(output_file_path):
                logging.info(f"Skipping existing file: {output_file_path}")
                continue
            
            # Load and process neurogram
            mat_data = loadmat(file_path)
            neurogram = mat_data['r_mean_downsampled']
            
            # Validate neurogram
            if neurogram.ndim != 2:
                logging.warning(f"Unexpected neurogram shape in {file_path}: {neurogram.shape}")
                continue
            
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
            
            # Save perturbed neurogram
            savemat(output_file_path, {
                'r_mean_downsampled': perturbed,
                'original_filename': file_path,
                'perturbation_type': perturbation_type
            })
            
            logging.info(f"Processed {file_path} with {perturbation_type}")
        
        except Exception as e:
            logging.error(f"Error processing {file_path}: {e}")
            logging.error(f"Traceback: {sys.exc_info()}")

def main():
    # Read task parameters from environment variables
    task_id = int(os.environ.get('SLURM_ARRAY_TASK_ID', 0))
    num_tasks = int(os.environ.get('SLURM_ARRAY_TASK_COUNT', 1))
    
    input_base = '/pasteur/helix/scratch/mcampi/neurograms_wham/healthy/'
    output_base = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise'
    
    process_test_neurograms(input_base, output_base, task_id, num_tasks)

if __name__ == '__main__':
    main()
