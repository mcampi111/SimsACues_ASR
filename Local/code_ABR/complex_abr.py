# %%
import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat, savemat
from scipy.signal import convolve, butter, filtfilt
import pandas as pd
from tqdm import tqdm
import json
from collections import defaultdict
# %%
# Phoneme category mapping (kept as is)
phoneme_category_map = {
    'm': 'Nasal',  'n': 'Nasal', 'ng': 'Nasal',  'em': 'Nasal',
    'en': 'Nasal', 'nx': 'Nasal', 
    'iy': 'Vowel', 'ih': 'Vowel', 'ix': 'Vowel', 'ey': 'Vowel', 
    'eh': 'Vowel', 'ae': 'Vowel', 'aa': 'Vowel','aw': 'Vowel',
    'ay': 'Vowel', 'ah': 'Vowel','ax': 'Vowel', 'ax-h': 'Vowel',
    'ao': 'Vowel','oy': 'Vowel', 'ow': 'Vowel','uh': 'Vowel', 
    'uw': 'Vowel', 'ux': 'Vowel','er': 'Vowel','axr': 'Vowel',
    'l': 'Liquid', 'r': 'Liquid',
    'w': 'Glide', 'y': 'Glide',
    's': 'Fricative', 'z': 'Fricative', 'f': 'Fricative', 'v': 'Fricative',
    'th': 'Fricative','dh': 'Fricative', 'sh': 'Fricative', 'hh': 'Fricative',
    'hv': 'Fricative',
    't': 'Stop', 'd': 'Stop', 'p': 'Stop', 'b': 'Stop', 'k': 'Stop', 'g': 'Stop',
    'tcl': 'Stop', 'dcl': 'Stop', 'pcl': 'Stop', 'bcl': 'Stop', 'kcl': 'Stop',
    'gcl': 'Stop',
    'ch': 'Affricate', 'jh': 'Affricate',
    'dx': 'Flap',
    'q': 'Glottal Stop',
    'epi': 'Epenthetic',
    'h#': 'Silence',
    'el': 'Syllabic Consonant'
}
# %%
def create_action_potential_template(fs=20000, duration=1, ap_type='auditory_nerve'):
    """
    Create a template for a typical auditory nerve action potential with CORRECT polarity.
    
    Parameters:
    -----------
    fs : int
        Sampling frequency in Hz
    duration : float
        Duration of the template in milliseconds
    ap_type : str
        Type of action potential template
        
    Returns:
    --------
    np.ndarray
        Action potential template as a numpy array
    """
    # Convert duration from ms to samples
    n_samples = int(fs * duration / 1000)
    
    # Time vector
    t = np.linspace(0, duration/1000, n_samples)
    
    # Different action potential waveforms
    if ap_type == 'auditory_nerve':
        # Auditory nerve specialized waveform
        # Based on literature of AN fiber recordings
        tau1 = 0.05e-3  # rising time constant (s)
        tau2 = 0.1e-3   # falling time constant (s)
        tau3 = 0.2e-3   # recovery time constant (s)
        
        # Generate the template with INVERTED polarity (positive peaks)
        ap = -1 * ((np.exp(-t/tau1) - np.exp(-t/tau2)) * (1 - np.exp(-t/tau3)))
        
    elif ap_type == 'compound_ap':
        # Compound action potential - broader response
        tau1 = 0.1e-3
        tau2 = 0.3e-3
        tau3 = 0.6e-3
        
        ap = -1 * ((np.exp(-t/tau1) - np.exp(-t/tau2)) * (1 - np.exp(-t/tau3)))
        # Add small second peak (also inverted)
        ap += 0.2 * np.exp(-(t-0.5e-3)**2 / (2*(0.1e-3)**2))
        
    elif ap_type == 'biphasic':
        # Simple biphasic waveform (positive then negative)
        ap = np.exp(-t / 0.0001) * np.sin(2 * np.pi * 1000 * t)
        
    elif ap_type == 'triphasic':
        # More realistic triphasic waveform (pos-neg-pos)
        f = 3000  # Hz - frequency of oscillation
        ap = np.exp(-t / 0.0002) * np.sin(2 * np.pi * f * t)
        ap = np.diff(np.diff(ap, prepend=0), prepend=0)  # Second derivative creates triphasic shape
        
    else:
        # Default to a simple single spike (positive)
        sigma = 0.05e-3  # spike width
        ap = np.exp(-(t-0.2e-3)**2 / (2*sigma**2))
    
    # Set values before t=0 to zero
    ap[t < 0] = 0
    
    # Normalize
    ap = ap / np.max(np.abs(ap))
    
    return ap

def bandpass_filter(signal, lowcut=100, highcut=1500, fs=20000, order=4):
    """
    Apply a bandpass filter to a signal.
    """
    # Check if signal is long enough for the filter order
    min_length = 3 * order
    if len(signal) < min_length:
        # For very short signals, use a simple 1st order filter or return unfiltered
        if len(signal) < 5:
            return signal  # Too short to filter reasonably
        order = 1
    
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    
    # Make sure the filter frequencies are valid
    low = max(0.001, min(low, 0.99))
    high = min(0.999, max(high, low + 0.001))
    
    try:
        b, a = butter(order, [low, high], btype='band')
        return filtfilt(b, a, signal, padlen=min(order*3, len(signal)-1))
    except Exception as e:
        print(f"Filtering error: {e}")
        # Fall back to a simpler filter if needed
        try:
            if order > 1:
                b, a = butter(1, [low, high], btype='band')
                return filtfilt(b, a, signal, padlen=min(3, len(signal)-1))
            else:
                return signal  # Give up on filtering
        except:
            return signal  # Return original signal if all filtering fails

def neurogram_to_complex_abr(neurogram, ap_template, fs=20000):
    """
    Convert a neurogram to a complex ABR by convolving with an action potential
    template and summing across frequency channels.
    
    Parameters:
    -----------
    neurogram : np.ndarray
        Neurogram data with shape (time, frequency)
    ap_template : np.ndarray
        Action potential template
    fs : int
        Sampling frequency in Hz
        
    Returns:
    --------
    np.ndarray
        Complex ABR signal
    """
    # Check if neurogram is too short
    if neurogram.shape[0] < 30:  # Arbitrary minimum length threshold
        print(f"Warning: Neurogram too short ({neurogram.shape[0]} samples). Skipping filtering.")
        # Just perform convolution without filtering for very short signals
        abr = np.zeros(neurogram.shape[0] + len(ap_template) - 1)
        for i in range(neurogram.shape[1]):
            convolved = convolve(neurogram[:, i], ap_template)
            abr += convolved
        return abr
    
    # Initialize output array
    abr = np.zeros(neurogram.shape[0] + len(ap_template) - 1)
    
    # Process each frequency channel
    for i in range(neurogram.shape[1]):
        # Convolve the channel with the action potential template
        convolved = convolve(neurogram[:, i], ap_template)
        
        # Add to the total ABR
        abr += convolved
    
    # Apply bandpass filtering to isolate relevant ABR frequencies
    # Use lower filter order for shorter signals
    filter_order = min(4, max(2, neurogram.shape[0] // 15))
    try:
        abr_filtered = bandpass_filter(abr, lowcut=100, highcut=1500, fs=fs, order=filter_order)
        return abr_filtered
    except ValueError as e:
        print(f"Warning: Filtering failed ({str(e)}). Returning unfiltered signal.")
        return abr

def read_neurograms(base_path):
    """
    Read all neurogram files from the given directory structure.
    """
    all_neurograms = []
    error_files = []
    
    # Ensure the base path exists
    if not os.path.exists(base_path):
        print(f"Error: Base path '{base_path}' does not exist")
        return all_neurograms
    
    # Get a list of all DR folders
    try:
        dr_folders = sorted([f for f in os.listdir(base_path) 
                            if os.path.isdir(os.path.join(base_path, f)) and not f.startswith('.')])
    except Exception as e:
        print(f"Error reading base directory: {e}")
        return all_neurograms
    
    if not dr_folders:
        print(f"No DR folders found in {base_path}")
        
    # Process DR folders
    for dr_folder in dr_folders:
        dr_path = os.path.join(base_path, dr_folder)
        
        # Get speaker folders
        try:
            speaker_folders = sorted([f for f in os.listdir(dr_path) 
                                     if os.path.isdir(os.path.join(dr_path, f)) and not f.startswith('.')])
        except Exception as e:
            print(f"Error reading DR folder {dr_folder}: {e}")
            continue
        
        # Process speaker folders
        for speaker_folder in speaker_folders:
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            # Get mat files
            try:
                mat_files = sorted([f for f in os.listdir(speaker_path) 
                                   if f.endswith('_neurogram.mat') and not f.startswith('.')])
            except Exception as e:
                print(f"Error reading speaker folder {speaker_folder}: {e}")
                continue
            
            # Process each mat file
            for mat_file in mat_files:
                file_path = os.path.join(speaker_path, mat_file)
                
                try:
                    data = loadmat(file_path)
                    
                    # Check for the neurogram data
                    neurogram_key = None
                    for key in ['r_mean_downsampled', 'r_mean', 'neurogram', 'data']:
                        if key in data:
                            neurogram_key = key
                            break
                    
                    if neurogram_key:
                        neurogram = data[neurogram_key]
                        
                        # Validate neurogram
                        if not isinstance(neurogram, np.ndarray) or neurogram.ndim != 2:
                            print(f"Warning: Invalid neurogram format in {file_path}")
                            error_files.append(file_path)
                            continue
                        
                        # Extract metadata from filename - your pattern is like SA1_aa_19962_21514_neurogram.mat
                        file_base = mat_file.replace('_neurogram.mat', '')
                        parts = file_base.split('_')
                        
                        # Use the first part as utterance and second part as phoneme
                        if len(parts) >= 2:
                            utterance_id = parts[0]
                            phoneme = parts[1]
                            
                            neurogram_row = {
                                'DR': dr_folder,
                                'Speaker': speaker_folder,
                                'Utterance': utterance_id,
                                'Phoneme': phoneme,
                                'Neurogram': neurogram,
                                'FilePath': file_path,
                                'FileName': mat_file
                            }
                            
                            # Map to phoneme category
                            if phoneme in phoneme_category_map:
                                neurogram_row['Category'] = phoneme_category_map[phoneme]
                            else:
                                neurogram_row['Category'] = 'Unknown'
                            
                            all_neurograms.append(neurogram_row)
                        else:
                            print(f"Warning: Unable to extract phoneme from filename {mat_file}")
                            error_files.append(file_path)
                    else:
                        print(f"Warning: No neurogram data found in {file_path}")
                        error_files.append(file_path)
                
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
                    error_files.append(file_path)
    
    # Print summary
    if all_neurograms:
        print(f"Successfully read {len(all_neurograms)} neurogram files")
        
        # Count by category
        category_counts = {}
        for item in all_neurograms:
            category = item['Category']
            if category not in category_counts:
                category_counts[category] = 0
            category_counts[category] += 1
        
        print("Neurograms by category:")
        for category, count in sorted(category_counts.items()):
            print(f"  {category}: {count}")
    else:
        print("No valid neurogram files were found")
    
    if error_files:
        print(f"Encountered errors with {len(error_files)} files")
        
    return all_neurograms

def compute_complex_abr_by_category(neurograms, fs=20000, ap_duration=1, ap_type='auditory_nerve'):
    """
    Compute complex ABR signals for each phoneme category.
    """
    # Create action potential template
    ap_template = create_action_potential_template(fs=fs, duration=ap_duration, ap_type=ap_type)
    
    # Group by category
    categories = {}
    for item in neurograms:
        category = item['Category']
        if category not in categories:
            categories[category] = []
        categories[category].append(item)
    
    # Process each category
    category_results = {}
    
    for category, items in tqdm(categories.items(), desc="Processing categories"):
        print(f"Processing {category} with {len(items)} neurograms")
        
        # Skip categories with too few samples
        if len(items) < 2:
            print(f"Skipping {category} due to insufficient data")
            continue
        
        # Process each neurogram in this category
        abr_signals = []
        
        for item in items:
            try:
                neurogram = item['Neurogram']
                
                # Skip neurograms with invalid data
                if neurogram is None or not isinstance(neurogram, np.ndarray):
                    print(f"Skipping invalid neurogram for {item.get('Phoneme', 'unknown')}")
                    continue
                
                # Skip neurograms that are too small
                if neurogram.size == 0 or neurogram.ndim != 2:
                    print(f"Skipping neurogram with invalid shape: {neurogram.shape}")
                    continue
                
                # Convert neurogram to ABR
                abr = neurogram_to_complex_abr(neurogram, ap_template, fs=fs)
                
                # Only add valid ABR signals
                if abr is not None and len(abr) > 0:
                    abr_signals.append(abr)
                
            except Exception as e:
                print(f"Error processing neurogram: {e}")
                continue
        
        # Skip if we don't have enough valid ABR signals
        if len(abr_signals) < 2:
            print(f"Skipping {category} due to insufficient valid data after processing")
            continue
        
        # Find the minimum length to align all signals
        min_length = min(len(signal) for signal in abr_signals)
        
        # Make sure we have a meaningful minimum length
        if min_length < 10:
            print(f"Warning: Very short signals in {category} (min length: {min_length})")
        
        # Truncate all signals to the same length
        aligned_signals = [signal[:min_length] for signal in abr_signals]
        
        # Convert to numpy array for easier calculation
        aligned_array = np.array(aligned_signals)
        
        # Calculate mean and standard deviation
        mean_abr = np.mean(aligned_array, axis=0)
        std_abr = np.std(aligned_array, axis=0)
        
        # Store results
        category_results[category] = {
            'mean_abr': mean_abr,
            'std_abr': std_abr,
            'n_samples': len(abr_signals),
            'time': np.arange(min_length) / fs  # Time in seconds
        }
    
    return category_results

def compute_complex_abr_by_phoneme(neurograms, fs=20000, ap_duration=1, ap_type='auditory_nerve'):
    """
    Compute complex ABR signals for each individual phoneme.
    """
    # Create action potential template
    ap_template = create_action_potential_template(fs=fs, duration=ap_duration, ap_type=ap_type)
    
    # Group by phoneme
    phonemes = {}
    for item in neurograms:
        phoneme = item['Phoneme']
        if phoneme not in phonemes:
            phonemes[phoneme] = []
        phonemes[phoneme].append(item)
    
    # Process each phoneme
    phoneme_results = {}
    
    for phoneme, items in tqdm(phonemes.items(), desc="Processing phonemes"):
        # Skip phonemes with too few samples
        if len(items) < 2:
            print(f"Skipping phoneme {phoneme} due to insufficient data")
            continue
        
        print(f"Processing phoneme {phoneme} with {len(items)} neurograms")
        
        # Process each neurogram for this phoneme
        abr_signals = []
        
        for item in items:
            try:
                neurogram = item['Neurogram']
                
                # Skip neurograms with invalid data
                if neurogram is None or not isinstance(neurogram, np.ndarray):
                    continue
                
                # Skip neurograms that are too small
                if neurogram.size == 0 or neurogram.ndim != 2:
                    continue
                
                # Convert neurogram to ABR
                abr = neurogram_to_complex_abr(neurogram, ap_template, fs=fs)
                
                # Only add valid ABR signals
                if abr is not None and len(abr) > 0:
                    abr_signals.append(abr)
                
            except Exception as e:
                print(f"Error processing neurogram: {e}")
                continue
        
        # Skip if we don't have enough valid ABR signals
        if len(abr_signals) < 2:
            continue
        
        # Find the minimum length to align all signals
        min_length = min(len(signal) for signal in abr_signals)
        
        # Truncate all signals to the same length
        aligned_signals = [signal[:min_length] for signal in abr_signals]
        
        # Convert to numpy array for easier calculation
        aligned_array = np.array(aligned_signals)
        
        # Calculate mean and standard deviation
        mean_abr = np.mean(aligned_array, axis=0)
        std_abr = np.std(aligned_array, axis=0)
        
        # Get category for this phoneme
        category = phoneme_category_map.get(phoneme, 'Unknown')
        
        # Store results
        phoneme_results[phoneme] = {
            'mean_abr': mean_abr,
            'std_abr': std_abr,
            'n_samples': len(abr_signals),
            'time': np.arange(min_length) / fs,  # Time in seconds
            'category': category  # Store the category for coloring
        }
    
    return phoneme_results

def plot_complex_abrs_by_category(category_results, output_dir):
    """
    Plot complex ABR results for each category with 5 columns.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define colors for categories
    category_colors = {
        'Vowel': 'blue',
        'Stop': 'red',
        'Fricative': 'green',
        'Nasal': 'purple',
        'Liquid': 'orange',
        'Glide': 'brown',
        'Affricate': 'pink',
        'Flap': 'gray',
        'Glottal Stop': 'olive',
        'Epenthetic': 'cyan',
        'Silence': 'black',
        'Syllabic Consonant': 'magenta',
        'Unknown': 'lightgray'
    }
    
    # Create a subplot figure with all categories - MODIFIED TO 5 COLUMNS
    n_categories = len(category_results)
    n_cols = min(5, n_categories)  # Changed from 3 to 5 columns
    n_rows = (n_categories + n_cols - 1) // n_cols
    
    plt.figure(figsize=(20, 4 * n_rows))  # Wider figure to accommodate more columns
    
    # Rest of the function remains the same
    for i, (category, results) in enumerate(sorted(category_results.items())):
        plt.subplot(n_rows, n_cols, i+1)
        
        # Convert time to ms and limit to 0-20ms for ABR
        time_ms = results['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        time_plot = time_ms[valid_time]
        mean_abr = results['mean_abr'][valid_time]
        std_abr = results['std_abr'][valid_time]
        
        # Scale amplitudes to microvolts for display
        scaling_factor = 1.0 / 10000  # Adjust this based on your actual data range
        mean_abr_scaled = mean_abr * scaling_factor
        std_abr_scaled = std_abr * scaling_factor
        
        color = category_colors.get(category, 'blue')
        
        plt.plot(time_plot, mean_abr_scaled, color=color)
        plt.fill_between(time_plot, 
                        mean_abr_scaled - std_abr_scaled, 
                        mean_abr_scaled + std_abr_scaled, 
                        alpha=0.2, color=color)
        
        plt.title(f'{category} (n={results["n_samples"]})')
        plt.xlabel('Time (ms)')
        plt.ylabel('Amplitude (μV)')
        plt.grid(True, alpha=0.3)
        
        # Add ABR wave labels
        if category == 'Vowel' or category == 'Stop':  # Add labels for reference categories
            # Approximate positions for ABR waves (these should be adjusted based on actual data)
            wave_positions = {
                'V': 6.0, 
                'A': 7.5,
                'C': 10.5,
                'D': 12.5,
                'E': 14.5,
                'F': 16.5,
                'O': 18.5
            }
            
            for wave, pos in wave_positions.items():
                # Find the closest time point
                idx = np.abs(time_plot - pos).argmin()
                if idx < len(mean_abr_scaled):
                    plt.annotate(wave, 
                              (time_plot[idx], mean_abr_scaled[idx]),
                              xytext=(0, 10),
                              textcoords='offset points',
                              fontsize=8,
                              ha='center')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'complex_abr_panels_adjusted.png'), dpi=300)
    plt.close()
    
    # Plot all categories on a single plot - this part remains unchanged
    plt.figure(figsize=(10, 6))
    
    for category, results in category_results.items():
        # Convert time to ms and limit to 0-20ms for ABR
        time_ms = results['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        time_plot = time_ms[valid_time]
        mean_abr = results['mean_abr'][valid_time] * scaling_factor
        
        color = category_colors.get(category, 'blue')
        plt.plot(time_plot, mean_abr, 
                 label=f"{category} (n={results['n_samples']})",
                 color=color)
    
    plt.title('Complex ABR by Phoneme Category')
    plt.xlabel('Time (ms)')
    plt.ylabel('Amplitude (μV)')
    plt.grid(True, alpha=0.3)
    plt.legend(loc='best', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'complex_abr_all_categories_adjusted.png'), dpi=300)
    plt.close()

def plot_complex_abrs_by_phoneme(phoneme_results, output_dir):
    """
    Plot complex ABR results for individual phonemes.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define colors for categories to use for phonemes
    category_colors = {
        'Vowel': 'blue',
        'Stop': 'red',
        'Fricative': 'green',
        'Nasal': 'purple',
        'Liquid': 'orange',
        'Glide': 'brown',
        'Affricate': 'pink',
        'Flap': 'gray',
        'Glottal Stop': 'olive',
        'Epenthetic': 'cyan',
        'Silence': 'black',
        'Syllabic Consonant': 'magenta',
        'Unknown': 'lightgray'
    }
    
    # Group phonemes by category for plotting
    phonemes_by_category = defaultdict(list)
    for phoneme, results in phoneme_results.items():
        category = results['category']
        phonemes_by_category[category].append(phoneme)
    
    # Plot each category in a separate figure with its phonemes
    for category, phoneme_list in phonemes_by_category.items():
        # Skip if not enough phonemes
        if len(phoneme_list) < 1:
            continue
            
        # Determine grid size
        n_phonemes = len(phoneme_list)
        n_cols = min(4, n_phonemes)
        n_rows = (n_phonemes + n_cols - 1) // n_cols
        
        plt.figure(figsize=(15, 4 * n_rows))
        
        for i, phoneme in enumerate(sorted(phoneme_list)):
            plt.subplot(n_rows, n_cols, i+1)
            
            results = phoneme_results[phoneme]
            
            # Convert time to ms and limit to 0-20ms for ABR
            time_ms = results['time'] * 1000
            valid_time = (time_ms >= 0) & (time_ms <= 20)
            
            time_plot = time_ms[valid_time]
            mean_abr = results['mean_abr'][valid_time]
            std_abr = results['std_abr'][valid_time]
            
            # Scale amplitudes to microvolts for display
            scaling_factor = 1.0 / 10000  # Adjust as needed
            mean_abr_scaled = mean_abr * scaling_factor
            std_abr_scaled = std_abr * scaling_factor
            
            color = category_colors[category]
            
            plt.plot(time_plot, mean_abr_scaled, color=color)
            plt.fill_between(time_plot, 
                           mean_abr_scaled - std_abr_scaled, 
                           mean_abr_scaled + std_abr_scaled, 
                           alpha=0.2, color=color)
            
            plt.title(f'Phoneme: {phoneme} (n={results["n_samples"]})')
            plt.xlabel('Time (ms)')
            plt.ylabel('Amplitude (μV)')
            plt.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'phoneme_{category}_abrs.png'), dpi=300)
        plt.close()
    
    # Create a summary plot with one representative from each category
    plt.figure(figsize=(12, 6))
    
    for category, phoneme_list in phonemes_by_category.items():
        # Skip if no phonemes
        if not phoneme_list:
            continue
            
        # Choose the phoneme with the most samples
        best_phoneme = phoneme_list[0]
        max_samples = phoneme_results[best_phoneme]['n_samples']
        
        for phoneme in phoneme_list:
            if phoneme_results[phoneme]['n_samples'] > max_samples:
                best_phoneme = phoneme
                max_samples = phoneme_results[phoneme]['n_samples']
        
        results = phoneme_results[best_phoneme]
        
        # Convert time to ms and limit to 0-20ms for ABR
        time_ms = results['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        time_plot = time_ms[valid_time]
        mean_abr = results['mean_abr'][valid_time] * scaling_factor
        
        color = category_colors[category]
        plt.plot(time_plot, mean_abr, 
                label=f"{best_phoneme} ({category}, n={results['n_samples']})",
                color=color)
    
    plt.title('Representative ABRs by Phoneme Category')
    plt.xlabel('Time (ms)')
    plt.ylabel('Amplitude (μV)')
    plt.grid(True, alpha=0.3)
    plt.legend(loc='best', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'representative_phoneme_abrs.png'), dpi=300)
    plt.close()

def main():
    # Configuration
    base_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all'
    neurogram_base_path = os.path.join(base_dir, 'SELECT_Neurograms/TEST')
    output_dir = os.path.join(base_dir, 'ABR_SELECT/healthy_silence')
    phoneme_output_dir = os.path.join(output_dir, 'phoneme_abrs')
    sampling_frequency = 20000  # Hz
    ap_duration = 1  # ms
    ap_type = 'auditory_nerve'  # Type of action potential template to use
    
    # Create output directories
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(phoneme_output_dir, exist_ok=True)
    
    # Also create a directory for different AP template tests
    ap_test_dir = os.path.join(output_dir, 'ap_template_tests')
    os.makedirs(ap_test_dir, exist_ok=True)
    
    # Plot different action potential templates for reference
    ap_templates = plot_action_potential_templates(output_dir, 
                                                 fs=sampling_frequency, 
                                                 duration=ap_duration)
    
    # Step 1: Read all neurograms
    print("Reading neurogram files...")
    all_neurograms = read_neurograms(neurogram_base_path)
    print(f"Found {len(all_neurograms)} neurogram files")
    
    # Step 2: Compute complex ABRs by category with the primary action potential type
    print(f"Computing complex ABRs by phoneme category using '{ap_type}' template...")
    category_results = compute_complex_abr_by_category(
        all_neurograms, 
        fs=sampling_frequency,
        ap_duration=ap_duration,
        ap_type=ap_type
    )
    
    # Step 3: Compute complex ABRs by individual phoneme
    print(f"Computing complex ABRs by individual phoneme using '{ap_type}' template...")
    phoneme_results = compute_complex_abr_by_phoneme(
        all_neurograms, 
        fs=sampling_frequency,
        ap_duration=ap_duration,
        ap_type=ap_type
    )
    
    # Step 4: Plot results
    print("Generating plots...")
    plot_complex_abrs_by_category(category_results, output_dir)
    plot_complex_abrs_by_phoneme(phoneme_results, phoneme_output_dir)
    plot_all_phonemes_combined(phoneme_results, output_dir)
    
    # Step 5: Save results
    print("Saving results...")
    save_abr_results(category_results, output_dir, all_neurograms)
    
    # Optionally compute results with different AP templates for comparison
    if len(all_neurograms) > 0:
        # Choose a subset of data for AP template comparison
        # Use only the two largest categories
        categories = {}
        for item in all_neurograms:
            cat = item['Category']
            if cat not in categories:
                categories[cat] = 0
            categories[cat] += 1
        
        # Sort categories by number of samples and take top 2
        major_cats = sorted(categories.items(), key=lambda x: x[1], reverse=True)[:2]
        major_cat_names = [cat[0] for cat in major_cats]
        
        # Filter neurograms to just these categories
        subset_neurograms = [item for item in all_neurograms if item['Category'] in major_cat_names]
        
        print(f"\nTesting different AP templates on {len(subset_neurograms)} neurograms from {major_cat_names}...")
        
        ap_types = ['auditory_nerve', 'compound_ap', 'biphasic', 'triphasic']
        ap_test_results = {}
        
        # Only generate these if a reasonable subset is available
        if len(subset_neurograms) >= 10:
            for ap_type_test in ap_types:
                if ap_type_test != ap_type:  # Skip the one we already computed
                    print(f"Computing with '{ap_type_test}' template...")
                    ap_test_results[ap_type_test] = compute_complex_abr_by_category(
                        subset_neurograms,
                        fs=sampling_frequency,
                        ap_duration=ap_duration,
                        ap_type=ap_type_test
                    )
            
            # Generate comparison plots
            if ap_test_results:
                print("Generating AP template comparison plots...")
                
                for category in major_cat_names:
                    if all(category in results for results in ap_test_results.values()):
                        plt.figure(figsize=(12, 8))
                        
                        # Plot the primary results
                        if category in category_results:
                            time = category_results[category]['time'] * 1000
                            valid_time = (time >= 0) & (time <= 20)
                            time = time[valid_time]
                            mean_abr = category_results[category]['mean_abr'][valid_time] * (1.0 / 10000)
                            plt.plot(time, mean_abr, label=f"{ap_type} (primary)", 
                                    linewidth=2, color='black')
                        
                        # Plot each AP test result
                        for ap_type_test, results in ap_test_results.items():
                            if category in results:
                                time = results[category]['time'] * 1000
                                valid_time = (time >= 0) & (time <= 20)
                                time = time[valid_time]
                                mean_abr = results[category]['mean_abr'][valid_time] * (1.0 / 10000)
                                plt.plot(time, mean_abr, label=ap_type_test, linewidth=1.5)
                        
                        plt.title(f'Complex ABR Comparison with Different AP Templates - {category}')
                        plt.xlabel('Time (ms)')
                        plt.ylabel('Amplitude (μV)')
                        plt.grid(True, alpha=0.3)
                        plt.legend()
                        
                        plt.tight_layout()
                        plt.savefig(os.path.join(ap_test_dir, f'ap_template_comparison_{category}.png'), dpi=300)
                        plt.close()
    
    # Save metadata about the computation
    metadata = {
        'sampling_frequency': sampling_frequency,
        'ap_duration': ap_duration,
        'ap_type': ap_type,
        'date_computed': pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S'),
        'neurogram_source': neurogram_base_path
    }
    
    # Save metadata as JSON
    with open(os.path.join(output_dir, 'computation_metadata.json'), 'w') as f:
        json.dump(metadata, f, indent=4)
    
    # Count total phonemes processed by category
    category_counts = {}
    phoneme_counts = {}
    for item in all_neurograms:
        category = item['Category']
        phoneme = item['Phoneme']
        
        if category not in category_counts:
            category_counts[category] = 0
        category_counts[category] += 1
        
        if phoneme not in phoneme_counts:
            phoneme_counts[phoneme] = 0
        phoneme_counts[phoneme] += 1
    
    # Save phoneme distribution
    phoneme_df = pd.DataFrame([
        {'Phoneme': phoneme, 'Count': count}
        for phoneme, count in sorted(phoneme_counts.items(), key=lambda x: x[1], reverse=True)
    ])
    phoneme_df.to_csv(os.path.join(output_dir, 'phoneme_counts.csv'), index=False)
    
    # Print summary
    print("\nSummary of processed data:")
    print(f"Total neurograms processed: {len(all_neurograms)}")
    print("\nPhoneme categories:")
    for category, count in sorted(category_counts.items()):
        print(f"  {category}: {count} neurograms")
    
    # Print top 10 most common phonemes
    print("\nTop 10 most common phonemes:")
    for phoneme, count in sorted(phoneme_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {phoneme}: {count} neurograms")
    
    # Print unknown phonemes
    unknown_phonemes = [phoneme for phoneme in phoneme_counts.keys() 
                       if phoneme not in phoneme_category_map]
    if unknown_phonemes:
        print("\nPhonemes not in category map (mapped to 'Unknown'):")
        for phoneme in sorted(unknown_phonemes):
            print(f"  {phoneme}: {phoneme_counts.get(phoneme, 0)} neurograms")
    
    print(f"\nAnalysis complete! Results saved to {output_dir}")
    
    return category_results, phoneme_results

def plot_action_potential_templates(output_dir, fs=20000, duration=1):
    """
    Plot different action potential templates for comparison.
    
    Parameters:
    -----------
    output_dir : str
        Directory to save the plot
    fs : int
        Sampling frequency in Hz
    duration : float
        Duration of the templates in milliseconds
    """
    # Create different AP templates
    ap_types = ['auditory_nerve', 'compound_ap', 'biphasic', 'triphasic']
    templates = {}
    
    for ap_type in ap_types:
        templates[ap_type] = create_action_potential_template(fs, duration, ap_type)
    
    # Time vector in ms
    t = np.linspace(0, duration, int(fs * duration / 1000)) * 1000
    
    # Create plot
    plt.figure(figsize=(12, 8))
    
    for ap_type, template in templates.items():
        plt.plot(t, template, label=ap_type.replace('_', ' ').title())
    
    plt.title('Action Potential Templates Used for Convolution')
    plt.xlabel('Time (ms)')
    plt.ylabel('Normalized Amplitude')
    plt.grid(True, alpha=0.3)
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'action_potential_templates.png'), dpi=300)
    plt.close()
    
    return templates


def plot_all_phonemes_combined(phoneme_results, output_dir):
    """
    Create a single large figure with ALL phoneme ABRs using 10 columns.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define colors for categories to use for phonemes
    category_colors = {
        'Vowel': 'blue',
        'Stop': 'red',
        'Fricative': 'green',
        'Nasal': 'purple',
        'Liquid': 'orange',
        'Glide': 'brown',
        'Affricate': 'pink',
        'Flap': 'gray',
        'Glottal Stop': 'olive',
        'Epenthetic': 'cyan',
        'Silence': 'black',
        'Syllabic Consonant': 'magenta',
        'Unknown': 'lightgray'
    }
    
    # Get all phonemes and sort by category then by phoneme
    phoneme_items = []
    for phoneme, results in phoneme_results.items():
        phoneme_items.append({
            'phoneme': phoneme,
            'category': results['category'],
            'n_samples': results['n_samples']
        })
    
    # Sort first by category, then by phoneme name
    phoneme_items.sort(key=lambda x: (x['category'], x['phoneme']))
    
    # Set up the figure with 10 columns
    n_phonemes = len(phoneme_items)
    n_cols = 10  # Fixed at 10 columns as requested
    n_rows = (n_phonemes + n_cols - 1) // n_cols
    
    # Create a large figure - adjust figsize as needed
    plt.figure(figsize=(30, 3 * n_rows))
    
    # Plot each phoneme
    for i, item in enumerate(phoneme_items):
        phoneme = item['phoneme']
        category = item['category']
        
        # Skip if phoneme not in results (shouldn't happen but just in case)
        if phoneme not in phoneme_results:
            continue
        
        results = phoneme_results[phoneme]
        
        plt.subplot(n_rows, n_cols, i+1)
        
        # Convert time to ms and limit to 0-20ms for ABR
        time_ms = results['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        time_plot = time_ms[valid_time]
        mean_abr = results['mean_abr'][valid_time]
        std_abr = results['std_abr'][valid_time]
        
        # Scale amplitudes to microvolts for display
        scaling_factor = 1.0 / 10000  # Adjust as needed
        mean_abr_scaled = mean_abr * scaling_factor
        std_abr_scaled = std_abr * scaling_factor
        
        color = category_colors.get(category, 'blue')
        
        plt.plot(time_plot, mean_abr_scaled, color=color)
        plt.fill_between(time_plot, 
                       mean_abr_scaled - std_abr_scaled, 
                       mean_abr_scaled + std_abr_scaled, 
                       alpha=0.2, color=color)
        
        # Use smaller font for the title to save space
        plt.title(f'{phoneme} ({category}, n={results["n_samples"]})', fontsize=8)
        
        # Only add x/y labels to the leftmost and bottom plots to save space
        if i % n_cols == 0:  # Leftmost column
            plt.ylabel('Amplitude (μV)', fontsize=8)
        if i >= (n_rows-1) * n_cols:  # Bottom row
            plt.xlabel('Time (ms)', fontsize=8)
        
        plt.grid(True, alpha=0.3)
        plt.tick_params(labelsize=6)  # Smaller tick labels
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'all_phonemes_combined.png'), dpi=300)
    plt.close()
    
    print(f"Combined plot of all {n_phonemes} phonemes saved to {output_dir}")


def save_abr_results(category_results, output_dir, all_neurograms=None):
    """
    Save complex ABR results as MAT files and CSV summary.
    
    Parameters:
    -----------
    category_results : dict
        Dictionary with category as key and dict of ABR results as value
    output_dir : str
        Directory to save MAT files
    all_neurograms : list, optional
        List of all neurogram dictionaries for additional metadata
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Save each category as a separate MAT file
    for category, results in category_results.items():
        output_file = os.path.join(output_dir, f'complex_abr_{category}.mat')
        savemat(output_file, results)
    
    # Also save as a combined file
    savemat(os.path.join(output_dir, 'complex_abr_all_categories.mat'), category_results)
    
    # Create a CSV summary with key metrics
    summary_data = []
    for category, results in category_results.items():
        mean_abr = results['mean_abr']
        time_ms = results['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        # Find key metrics in the ABR time window (0-20ms)
        mean_abr_abr = mean_abr[valid_time]
        time_abr = time_ms[valid_time]
        
        if len(mean_abr_abr) > 0:
            peak_idx = np.argmax(mean_abr_abr)
            trough_idx = np.argmin(mean_abr_abr)
            peak_time = time_abr[peak_idx]
            trough_time = time_abr[trough_idx]
            peak_value = mean_abr_abr[peak_idx] * (1.0 / 10000)  # Convert to μV
            trough_value = mean_abr_abr[trough_idx] * (1.0 / 10000)  # Convert to μV
            peak_to_trough = peak_value - trough_value
            
            # Calculate approximate Wave V latency (typically around 6ms)
            wave_v_region = (time_abr >= 5) & (time_abr <= 7)
            if np.any(wave_v_region):
                wave_v_idx = np.argmax(mean_abr_abr[wave_v_region]) + np.where(wave_v_region)[0][0]
                wave_v_latency = time_abr[wave_v_idx]
                wave_v_amplitude = mean_abr_abr[wave_v_idx] * (1.0 / 10000)  # Convert to μV
            else:
                wave_v_latency = None
                wave_v_amplitude = None
            
            # Calculate ABR wave amplitude and latency metrics
            summary_data.append({
                'Category': category,
                'NumSamples': results['n_samples'],
                'PeakLatency_ms': round(peak_time, 2),
                'TroughLatency_ms': round(trough_time, 2),
                'PeakAmplitude_uV': round(peak_value, 4),
                'TroughAmplitude_uV': round(trough_value, 4),
                'PeakToTroughAmplitude_uV': round(peak_to_trough, 4),
                'WaveV_Latency_ms': round(wave_v_latency, 2) if wave_v_latency is not None else None,
                'WaveV_Amplitude_uV': round(wave_v_amplitude, 4) if wave_v_amplitude is not None else None
            })
    
    # Save summary as CSV
    summary_df = pd.DataFrame(summary_data)
    summary_df.to_csv(os.path.join(output_dir, 'complex_abr_metrics.csv'), index=False)
    
    # If we have neurogram details, save phoneme distribution info
    if all_neurograms:
        # Count phonemes by category
        phoneme_counts = {}
        for item in all_neurograms:
            category = item['Category']
            phoneme = item['Phoneme']
            
            if category not in phoneme_counts:
                phoneme_counts[category] = {}
            
            if phoneme not in phoneme_counts[category]:
                phoneme_counts[category][phoneme] = 0
            
            phoneme_counts[category][phoneme] += 1
        
        # Convert to dataframe for easy saving
        phoneme_rows = []
        for category, phonemes in phoneme_counts.items():
            for phoneme, count in phonemes.items():
                phoneme_rows.append({
                    'Category': category,
                    'Phoneme': phoneme,
                    'Count': count
                })
        
        phoneme_df = pd.DataFrame(phoneme_rows)
        phoneme_df.to_csv(os.path.join(output_dir, 'phoneme_distribution.csv'), index=False)
# %%
if __name__ == "__main__":
    category_results, phoneme_results = main()
# %%