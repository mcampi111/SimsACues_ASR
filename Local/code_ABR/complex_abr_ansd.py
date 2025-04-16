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
# Import the five_column_comparison function
def plot_five_column_comparison(normal_results, perturbation_results, output_dir):
    """
    Create a series of unified plots with 5 columns (normal + 4 perturbation types) for each phoneme category.
    Each plot has 4 rows max (4 categories) for better readability.
    
    Parameters:
    -----------
    normal_results : dict
        Dictionary with category as key and dict of ABR results as value for normal neurograms
    perturbation_results : dict
        Dictionary with perturbation type as key and dict of category results as value for ANSD neurograms
    output_dir : str
        Directory to save the plots
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define colors for consistency
    colors = {
        'normal': 'black',
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # Determine all available categories across normal and all perturbation types
    all_categories = set(normal_results.keys())
    for pert_results in perturbation_results.values():
        all_categories.update(pert_results.keys())
    
    # Identify all perturbation types
    perturbation_types = sorted(perturbation_results.keys())
    
    # Filter out categories that aren't in normal results
    key_categories = sorted([cat for cat in all_categories if cat in normal_results])
    
    if key_categories:
        # Determine how many plots we need
        max_rows_per_plot = 4
        categories_per_plot = max_rows_per_plot
        num_plots = (len(key_categories) + categories_per_plot - 1) // categories_per_plot
        
        # Create each plot
        for plot_idx in range(num_plots):
            # Calculate start and end indices for this plot
            start_idx = plot_idx * categories_per_plot
            end_idx = min(start_idx + categories_per_plot, len(key_categories))
            plot_categories = key_categories[start_idx:end_idx]
            
            # Calculate actual number of rows needed for this plot
            n_rows = len(plot_categories)
            
            # Create figure
            fig, axes = plt.subplots(n_rows, 5, figsize=(20, 4 * n_rows), sharex=False)
            
            # If only one row, make axes 2D
            if n_rows == 1:
                axes = axes.reshape(1, -1)
            
            # Add column labels at the top of each column instead of using figtext
            column_labels = ["Normal"] + perturbation_types[:4]
            for j, label in enumerate(column_labels):
                axes[0, j].set_title(label, fontweight='bold', fontsize=12)
            
            # Process each category in this plot
            for i, category in enumerate(plot_categories):
                # Get the 5 axes for this category
                category_axes = axes[i, :]
                
                # Plot normal data in first column for this category
                ax = category_axes[0]
                normal_data = normal_results[category]
                time_ms = normal_data['time'] * 1000
                valid_time = (time_ms >= 0) & (time_ms <= 20)
                
                time_plot = time_ms[valid_time]
                mean_abr = normal_data['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
                std_abr = normal_data['std_abr'][valid_time] * (1.0 / 10000)
                
                ax.plot(time_plot, mean_abr, color=colors['normal'], linewidth=2)
                ax.fill_between(time_plot, mean_abr - std_abr, mean_abr + std_abr, 
                               color=colors['normal'], alpha=0.2)
                
                # Add category label to the left of each row
                ax.set_ylabel(f"{category}\n(μV)", fontsize=10)
                
                # Add x-axis label for bottom row
                if i == n_rows - 1:
                    ax.set_xlabel('Time (ms)')
                
                ax.grid(True, alpha=0.3)
                
                # Plot perturbation types in remaining columns
                for j, pert_type in enumerate(perturbation_types):
                    if j >= 4:  # Ensure we only use at most 4 perturbation types
                        break
                        
                    ax = category_axes[j+1]
                    
                    # Check if this category exists for this perturbation type
                    if pert_type in perturbation_results and category in perturbation_results[pert_type]:
                        results = perturbation_results[pert_type][category]
                        
                        time_ms = results['time'] * 1000
                        valid_time = (time_ms >= 0) & (time_ms <= 20)
                        
                        time_plot = time_ms[valid_time]
                        mean_abr = results['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
                        std_abr = results['std_abr'][valid_time] * (1.0 / 10000)
                        
                        ax.plot(time_plot, mean_abr, color=colors.get(pert_type, 'blue'), linewidth=2)
                        ax.fill_between(time_plot, mean_abr - std_abr, mean_abr + std_abr, 
                                       color=colors.get(pert_type, 'blue'), alpha=0.2)
                        
                        # Add sample count in the corner
                        ax.text(0.95, 0.95, f"n={results['n_samples']}", 
                               transform=ax.transAxes, 
                               horizontalalignment='right',
                               verticalalignment='top',
                               fontsize=8)
                    else:
                        ax.text(0.5, 0.5, "No data", 
                               horizontalalignment='center',
                               verticalalignment='center',
                               transform=ax.transAxes)
                    
                    # Add x-axis label for bottom row
                    if i == n_rows - 1:
                        ax.set_xlabel('Time (ms)')
                    
                    ax.grid(True, alpha=0.3)
                
                # Make sure all axes for this category have the same y-limits for fair comparison
                ylims = [ax.get_ylim() for ax in category_axes]
                ymin = min([lim[0] for lim in ylims])
                ymax = max([lim[1] for lim in ylims])
                for ax in category_axes:
                    ax.set_ylim(ymin, ymax)
            
            # Add plot title with category range
            plt.suptitle(f'ABR Comparison - Categories {start_idx+1}-{end_idx} of {len(key_categories)}', fontsize=16)
            plt.tight_layout(rect=[0, 0, 1, 0.96])  # Make room for suptitle
            plt.savefig(os.path.join(output_dir, f'summary_five_column_comparison_part{plot_idx+1}.png'), dpi=300)
            plt.close()
# %%
def create_abr_heatmaps(normal_results, perturbation_results, output_dir):
    """
    Create heatmaps to visualize amplitude and latency differences between normal and ANSD ABRs.
    
    Parameters:
    -----------
    normal_results : dict
        Dictionary with category as key and dict of ABR results as value for normal neurograms
    perturbation_results : dict
        Dictionary with perturbation type as key and dict of category results as value for ANSD neurograms
    output_dir : str
        Directory to save the heatmaps
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Find categories that exist in both normal and ANSD datasets
    all_categories = set(normal_results.keys())
    
    # Find all perturbation types
    perturbation_types = sorted(perturbation_results.keys())
    
    # Create dictionaries to store metrics
    peak_amplitude_diff = defaultdict(dict)  # Category -> Perturbation -> Value
    peak_latency_diff = defaultdict(dict)    # Category -> Perturbation -> Value
    wave_v_amplitude_diff = defaultdict(dict)  # Category -> Perturbation -> Value
    wave_v_latency_diff = defaultdict(dict)    # Category -> Perturbation -> Value
    
    # Calculate metrics for each category and perturbation type
    for category in sorted(all_categories):
        if category not in normal_results:
            continue
            
        # Get normal data
        normal_data = normal_results[category]
        normal_time_ms = normal_data['time'] * 1000
        normal_valid_time = (normal_time_ms >= 0) & (normal_time_ms <= 20)
        normal_time = normal_time_ms[normal_valid_time]
        normal_abr = normal_data['mean_abr'][normal_valid_time] * (1.0 / 10000)  # Scale to μV
        
        # Find normal peak
        normal_peak_idx = np.argmax(normal_abr)
        normal_peak_amplitude = normal_abr[normal_peak_idx]
        normal_peak_latency = normal_time[normal_peak_idx]
        
        # Find approximate Wave V in normal data (around 6ms)
        wave_v_region = (normal_time >= 5) & (normal_time <= 7)
        if np.any(wave_v_region):
            normal_wave_v_idx = np.argmax(normal_abr[wave_v_region]) + np.where(wave_v_region)[0][0]
            normal_wave_v_amplitude = normal_abr[normal_wave_v_idx]
            normal_wave_v_latency = normal_time[normal_wave_v_idx]
        else:
            normal_wave_v_amplitude = None
            normal_wave_v_latency = None
        
        # Compare with each perturbation type
        for pert_type in perturbation_types:
            if pert_type in perturbation_results and category in perturbation_results[pert_type]:
                results = perturbation_results[pert_type][category]
                
                ansd_time_ms = results['time'] * 1000
                ansd_valid_time = (ansd_time_ms >= 0) & (ansd_time_ms <= 20)
                ansd_time = ansd_time_ms[ansd_valid_time]
                ansd_abr = results['mean_abr'][ansd_valid_time] * (1.0 / 10000)  # Scale to μV
                
                # Find ANSD peak
                ansd_peak_idx = np.argmax(ansd_abr)
                ansd_peak_amplitude = ansd_abr[ansd_peak_idx]
                ansd_peak_latency = ansd_time[ansd_peak_idx]
                
                # Calculate peak differences
                peak_amplitude_diff[category][pert_type] = ansd_peak_amplitude - normal_peak_amplitude
                peak_latency_diff[category][pert_type] = ansd_peak_latency - normal_peak_latency
                
                # Find approximate Wave V in ANSD data
                if normal_wave_v_amplitude is not None and normal_wave_v_latency is not None:
                    # Search in a window around the normal Wave V latency
                    search_window = (ansd_time >= normal_wave_v_latency - 1) & (ansd_time <= normal_wave_v_latency + 1)
                    if np.any(search_window):
                        ansd_wave_v_idx = np.argmax(ansd_abr[search_window]) + np.where(search_window)[0][0]
                        ansd_wave_v_amplitude = ansd_abr[ansd_wave_v_idx]
                        ansd_wave_v_latency = ansd_time[ansd_wave_v_idx]
                        
                        # Calculate Wave V differences
                        wave_v_amplitude_diff[category][pert_type] = ansd_wave_v_amplitude - normal_wave_v_amplitude
                        wave_v_latency_diff[category][pert_type] = ansd_wave_v_latency - normal_wave_v_latency
    
    # Convert to matrices for heatmap plotting
    categories = sorted(all_categories)
    
    # Create matrices for each metric
    peak_amplitude_matrix = np.zeros((len(categories), len(perturbation_types)))
    peak_latency_matrix = np.zeros((len(categories), len(perturbation_types)))
    wave_v_amplitude_matrix = np.zeros((len(categories), len(perturbation_types)))
    wave_v_latency_matrix = np.zeros((len(categories), len(perturbation_types)))
    
    # Fill matrices
    for i, category in enumerate(categories):
        for j, pert_type in enumerate(perturbation_types):
            if category in peak_amplitude_diff and pert_type in peak_amplitude_diff[category]:
                peak_amplitude_matrix[i, j] = peak_amplitude_diff[category][pert_type]
                peak_latency_matrix[i, j] = peak_latency_diff[category][pert_type]
            
            if category in wave_v_amplitude_diff and pert_type in wave_v_amplitude_diff[category]:
                wave_v_amplitude_matrix[i, j] = wave_v_amplitude_diff[category][pert_type]
                wave_v_latency_matrix[i, j] = wave_v_latency_diff[category][pert_type]
    
    # Plot peak amplitude difference heatmap
    plt.figure(figsize=(12, 10))
    cmap = plt.cm.RdBu_r  # Red-Blue colormap, reversed so red is negative
    plt.imshow(peak_amplitude_matrix, cmap=cmap, aspect='auto', interpolation='none')
    plt.colorbar(label='Peak Amplitude Difference (μV)')
    
    plt.xticks(np.arange(len(perturbation_types)), perturbation_types, rotation=45)
    plt.yticks(np.arange(len(categories)), categories)
    plt.title('Peak Amplitude Difference (ANSD - Normal)')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'peak_amplitude_diff_heatmap.png'), dpi=300)
    plt.close()
    
    # Plot peak latency difference heatmap
    plt.figure(figsize=(12, 10))
    cmap = plt.cm.RdBu  # Red-Blue colormap
    plt.imshow(peak_latency_matrix, cmap=cmap, aspect='auto', interpolation='none')
    plt.colorbar(label='Peak Latency Difference (ms)')
    
    plt.xticks(np.arange(len(perturbation_types)), perturbation_types, rotation=45)
    plt.yticks(np.arange(len(categories)), categories)
    plt.title('Peak Latency Difference (ANSD - Normal)')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'peak_latency_diff_heatmap.png'), dpi=300)
    plt.close()
    
    # Plot Wave V heatmaps if we have valid data
    if np.any(wave_v_amplitude_matrix) and np.any(wave_v_latency_matrix):
        plt.figure(figsize=(12, 10))
        plt.imshow(wave_v_amplitude_matrix, cmap=cmap, aspect='auto', interpolation='none')
        plt.colorbar(label='Wave V Amplitude Difference (μV)')
        
        plt.xticks(np.arange(len(perturbation_types)), perturbation_types, rotation=45)
        plt.yticks(np.arange(len(categories)), categories)
        plt.title('Wave V Amplitude Difference (ANSD - Normal)')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'wave_v_amplitude_diff_heatmap.png'), dpi=300)
        plt.close()
        
        plt.figure(figsize=(12, 10))
        plt.imshow(wave_v_latency_matrix, cmap=cmap, aspect='auto', interpolation='none')
        plt.colorbar(label='Wave V Latency Difference (ms)')
        
        plt.xticks(np.arange(len(perturbation_types)), perturbation_types, rotation=45)
        plt.yticks(np.arange(len(categories)), categories)
        plt.title('Wave V Latency Difference (ANSD - Normal)')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'wave_v_latency_diff_heatmap.png'), dpi=300)
        plt.close()
# %%
# Phoneme category mapping (kept as is from original code)
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
# Reuse the key functions from your original script

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

# %%
# New function to read ANSD neurograms
def read_ansd_neurograms(base_path, perturbation_types_file=None):
    """
    Read all ANSD neurogram files from the given directory structure.
    
    Parameters:
    -----------
    base_path : str
        Base path to the ANSD neurograms directory
    perturbation_types_file : str, optional
        Path to the JSON file containing perturbation type information
        
    Returns:
    --------
    list
        List of dictionaries containing neurogram data and metadata
    """
    all_neurograms = []
    error_files = []
    
    # Load perturbation type information if provided
    perturbation_types = {}
    if perturbation_types_file and os.path.exists(perturbation_types_file):
        try:
            with open(perturbation_types_file, 'r') as f:
                perturbation_types = json.load(f)
            print(f"Loaded {len(perturbation_types)} perturbation type entries")
        except Exception as e:
            print(f"Error loading perturbation types: {e}")
    
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
            
            # Get mat files (only ANSD ones that end with _ansd.mat)
            try:
                mat_files = sorted([f for f in os.listdir(speaker_path) 
                                   if f.endswith('_ansd.mat') and not f.startswith('.')])
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
                        
                        # Extract metadata from filename - the format should be like SA1_aa_19962_21514_neurogram_ansd.mat
                        file_base = mat_file.replace('_ansd.mat', '')
                        if '_neurogram' in file_base:
                            file_base = file_base.replace('_neurogram', '')
                        parts = file_base.split('_')
                        
                        # Use the first part as utterance and second part as phoneme
                        if len(parts) >= 2:
                            utterance_id = parts[0]
                            phoneme = parts[1]
                            
                            # Get perturbation type
                            perturbation_type = perturbation_types.get(mat_file, 'unknown')
                            
                            neurogram_row = {
                                'DR': dr_folder,
                                'Speaker': speaker_folder,
                                'Utterance': utterance_id,
                                'Phoneme': phoneme,
                                'Neurogram': neurogram,
                                'PerturbationType': perturbation_type,
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
        print(f"Successfully read {len(all_neurograms)} ANSD neurogram files")
        
        # Count by category
        category_counts = {}
        for item in all_neurograms:
            category = item['Category']
            if category not in category_counts:
                category_counts[category] = 0
            category_counts[category] += 1
        
        print("ANSD Neurograms by category:")
        for category, count in sorted(category_counts.items()):
            print(f"  {category}: {count}")
        
        # Count by perturbation type
        pert_counts = {}
        for item in all_neurograms:
            pert_type = item['PerturbationType']
            if pert_type not in pert_counts:
                pert_counts[pert_type] = 0
            pert_counts[pert_type] += 1
        
        print("ANSD Neurograms by perturbation type:")
        for pert_type, count in sorted(pert_counts.items()):
            print(f"  {pert_type}: {count}")
    else:
        print("No valid ANSD neurogram files were found")
    
    if error_files:
        print(f"Encountered errors with {len(error_files)} files")
        
    return all_neurograms

# %%
# Modify the compute_complex_abr functions to group by perturbation type

def compute_complex_abr_by_category_and_perturbation(neurograms, fs=20000, ap_duration=1, ap_type='auditory_nerve'):
    """
    Compute complex ABR signals for each phoneme category, separated by perturbation type.
    """
    # Create action potential template
    ap_template = create_action_potential_template(fs=fs, duration=ap_duration, ap_type=ap_type)
    
    # First group by perturbation type
    perturbation_groups = {}
    for item in neurograms:
        pert_type = item['PerturbationType']
        if pert_type not in perturbation_groups:
            perturbation_groups[pert_type] = []
        perturbation_groups[pert_type].append(item)
    
    # Then process each perturbation type separately
    perturbation_results = {}
    
    for pert_type, pert_items in perturbation_groups.items():
        print(f"Processing perturbation type: {pert_type} with {len(pert_items)} neurograms")
        
        # Group by category within this perturbation type
        categories = {}
        for item in pert_items:
            category = item['Category']
            if category not in categories:
                categories[category] = []
            categories[category].append(item)
        
        # Process each category for this perturbation type
        category_results = {}
        
        for category, items in tqdm(categories.items(), desc=f"Processing categories for {pert_type}"):
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
            
            # Store results
            category_results[category] = {
                'mean_abr': mean_abr,
                'std_abr': std_abr,
                'n_samples': len(abr_signals),
                'time': np.arange(min_length) / fs  # Time in seconds
            }
        
        # Store results for this perturbation type
        perturbation_results[pert_type] = category_results
    
    return perturbation_results

# %%
# Modify the plotting functions to include perturbation type information

def plot_complex_abrs_by_category_and_perturbation(perturbation_results, output_dir):
    """
    Plot complex ABR results for each category, separated by perturbation type.
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
    
    # Process each perturbation type
    for pert_type, category_results in perturbation_results.items():
        # Create directory for this perturbation type
        pert_dir = os.path.join(output_dir, f"perturbation_{pert_type}")
        os.makedirs(pert_dir, exist_ok=True)
        
        n_categories = len(category_results)
        if n_categories == 0:
            continue
            
        # Create multi-panel figure for this perturbation type
        n_cols = min(5, n_categories)  # 5 columns
        n_rows = (n_categories + n_cols - 1) // n_cols
        
        plt.figure(figsize=(20, 4 * n_rows))
        
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
            
            # Add ABR wave labels for key categories
            if category == 'Vowel' or category == 'Stop':
                # Approximate positions for ABR waves
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
        
        plt.suptitle(f'Complex ABR by Category - Perturbation: {pert_type}')
        plt.tight_layout(rect=[0, 0, 1, 0.97])  # Make room for suptitle
        plt.savefig(os.path.join(pert_dir, f'complex_abr_panels_{pert_type}.png'), dpi=300)
        plt.close()
        
        # Plot all categories on a single plot for this perturbation type
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
        
        plt.title(f'Complex ABR by Phoneme Category - Perturbation: {pert_type}')
        plt.xlabel('Time (ms)')
        plt.ylabel('Amplitude (μV)')
        plt.grid(True, alpha=0.3)
        plt.legend(loc='best', fontsize=8)
        
        plt.tight_layout()
        plt.savefig(os.path.join(pert_dir, f'complex_abr_all_categories_{pert_type}.png'), dpi=300)
        plt.close()
    
    # Create comparison plots across perturbation types for each category
    # Get all categories and perturbation types
    all_categories = set()
    for pert_results in perturbation_results.values():
        all_categories.update(pert_results.keys())
    
    # For each category, plot the different perturbation types
    for category in sorted(all_categories):
        plt.figure(figsize=(12, 6))
        
        for pert_type, category_results in perturbation_results.items():
            if category in category_results:
                results = category_results[category]
                
                # Convert time to ms and limit to 0-20ms for ABR
                time_ms = results['time'] * 1000
                valid_time = (time_ms >= 0) & (time_ms <= 20)
                
                time_plot = time_ms[valid_time]
                mean_abr = results['mean_abr'][valid_time] * scaling_factor
                
                plt.plot(time_plot, mean_abr, 
                         label=f"{pert_type} (n={results['n_samples']})")
        
        plt.title(f'Complex ABR Comparison Across Perturbation Types - {category}')
        plt.xlabel('Time (ms)')
        plt.ylabel('Amplitude (μV)')
        plt.grid(True, alpha=0.3)
        plt.legend(loc='best')
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'comparison_{category}_across_perturbations.png'), dpi=300)
        plt.close()
    
    # Create a summary figure showing the effect of different perturbations on key categories
    key_categories = ['Vowel', 'Stop', 'Fricative', 'Nasal']
    key_categories = [cat for cat in key_categories if cat in all_categories]
    
    if key_categories:
        fig, axes = plt.subplots(len(key_categories), 1, figsize=(12, 4*len(key_categories)), sharex=True)
        if len(key_categories) == 1:
            axes = [axes]  # Ensure axes is a list for single category case
        
        for i, category in enumerate(key_categories):
            ax = axes[i]
            
            for pert_type, category_results in perturbation_results.items():
                if category in category_results:
                    results = category_results[category]
                    
                    # Convert time to ms and limit to 0-20ms for ABR
                    time_ms = results['time'] * 1000
                    valid_time = (time_ms >= 0) & (time_ms <= 20)
                    
                    time_plot = time_ms[valid_time]
                    mean_abr = results['mean_abr'][valid_time] * scaling_factor
                    
                    ax.plot(time_plot, mean_abr, 
                            label=f"{pert_type} (n={results['n_samples']})")
            
            ax.set_title(f'{category}')
            ax.set_ylabel('Amplitude (μV)')
            ax.grid(True, alpha=0.3)
            ax.legend(loc='best', fontsize=8)
        
        axes[-1].set_xlabel('Time (ms)')
        plt.suptitle('Effect of Different Perturbations on Key Phoneme Categories')
        plt.tight_layout(rect=[0, 0, 1, 0.97])  # Make room for suptitle
        plt.savefig(os.path.join(output_dir, 'summary_key_categories_comparison.png'), dpi=300)
        plt.close()

# %%
# Function to create a combined plot showing normal vs ANSD ABRs
def plot_normal_vs_ansd_comparison(normal_results, ansd_results, output_dir):
    """
    Plot comparison between normal and ANSD ABRs.
    
    Parameters:
    -----------
    normal_results : dict
        Dictionary with category as key and dict of ABR results as value for normal neurograms
    ansd_results : dict
        Dictionary with perturbation type as key and dict of category results as value for ANSD neurograms
    output_dir : str
        Directory to save comparison plots
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Define colors for perturbation types in a consistent way
    perturbation_colors = {
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # Get list of all categories present in normal results
    normal_categories = set(normal_results.keys())
    
    # Create a flat dictionary for easier access to all ANSD categories
    all_ansd_categories = {}
    for pert_type, pert_results in ansd_results.items():
        for category, results in pert_results.items():
            if category not in all_ansd_categories:
                all_ansd_categories[category] = []
            all_ansd_categories[category].append((pert_type, results))
    
    # Find categories that exist in both normal and ANSD datasets
    common_categories = normal_categories.intersection(all_ansd_categories.keys())
    
    # Plot each common category
    for category in sorted(common_categories):
        plt.figure(figsize=(12, 6))
        
        # Plot normal data first
        normal_data = normal_results[category]
        time_ms = normal_data['time'] * 1000
        valid_time = (time_ms >= 0) & (time_ms <= 20)
        
        time_plot = time_ms[valid_time]
        mean_abr = normal_data['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
        std_abr = normal_data['std_abr'][valid_time] * (1.0 / 10000)
        
        # Plot normal with bold line and shaded error region
        plt.plot(time_plot, mean_abr, color='black', linewidth=2.5, label=f"Normal (n={normal_data['n_samples']})")
        plt.fill_between(time_plot, mean_abr - std_abr, mean_abr + std_abr, 
                       color='black', alpha=0.1)
        
        # Plot each perturbation type
        for pert_type, results in all_ansd_categories[category]:
            time_ms = results['time'] * 1000
            valid_time = (time_ms >= 0) & (time_ms <= 20)
            
            time_plot = time_ms[valid_time]
            mean_abr = results['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
            
            color = perturbation_colors.get(pert_type, 'gray')
            plt.plot(time_plot, mean_abr, color=color, linewidth=1.5, 
                   label=f"{pert_type} (n={results['n_samples']})")
        
        plt.title(f'Normal vs. ANSD ABR Comparison - {category}')
        plt.xlabel('Time (ms)')
        plt.ylabel('Amplitude (μV)')
        plt.grid(True, alpha=0.3)
        plt.legend(loc='best')
        
        # Add ABR wave labels for key categories
        if category in ['Vowel', 'Stop']:
            # Approximate positions for ABR waves
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
                if idx < len(mean_abr):
                    plt.annotate(wave, 
                              (time_plot[idx], mean_abr[idx]),
                              xytext=(0, 10),
                              textcoords='offset points',
                              fontsize=8,
                              ha='center')
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'normal_vs_ansd_{category}.png'), dpi=300)
        plt.close()
    
    # Create a multi-panel summary figure for the most important categories
    key_categories = ['Vowel', 'Stop', 'Fricative', 'Nasal']
    key_categories = [cat for cat in key_categories if cat in common_categories]
    
    if key_categories:
        # Get all perturbation types for the legend
        all_perturbations = set()
        for cat_data in all_ansd_categories.values():
            for pert_type, _ in cat_data:
                all_perturbations.add(pert_type)
        
        fig, axes = plt.subplots(len(key_categories), 1, figsize=(12, 4*len(key_categories)), sharex=True)
        if len(key_categories) == 1:
            axes = [axes]  # Ensure axes is a list for single category case
        
        for i, category in enumerate(key_categories):
            ax = axes[i]
            
            # Plot normal data
            normal_data = normal_results[category]
            time_ms = normal_data['time'] * 1000
            valid_time = (time_ms >= 0) & (time_ms <= 20)
            
            time_plot = time_ms[valid_time]
            mean_abr = normal_data['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
            
            ax.plot(time_plot, mean_abr, color='black', linewidth=2.5, label="Normal")
            
            # Plot each perturbation type
            for pert_type, results in all_ansd_categories[category]:
                time_ms = results['time'] * 1000
                valid_time = (time_ms >= 0) & (time_ms <= 20)
                
                time_plot = time_ms[valid_time]
                mean_abr = results['mean_abr'][valid_time] * (1.0 / 10000)  # Scale to μV
                
                color = perturbation_colors.get(pert_type, 'gray')
                ax.plot(time_plot, mean_abr, color=color, linewidth=1.5, label=pert_type)
            
            ax.set_title(f'{category}')
            ax.set_ylabel('Amplitude (μV)')
            ax.grid(True, alpha=0.3)
            
            # Only add legend to the first plot to avoid redundancy
            if i == 0:
                ax.legend(loc='best', fontsize=8)
        
        axes[-1].set_xlabel('Time (ms)')
        plt.suptitle('Normal vs. ANSD ABR Comparison Across Key Phoneme Categories')
        plt.tight_layout(rect=[0, 0, 1, 0.97])  # Make room for suptitle
        plt.savefig(os.path.join(output_dir, 'summary_normal_vs_ansd.png'), dpi=300)
        plt.close()
    
    # Create a difference plot (ANSD - Normal) to highlight the changes
    for category in sorted(common_categories):
        plt.figure(figsize=(12, 6))
        
        # Get normal data
        normal_data = normal_results[category]
        normal_time_ms = normal_data['time'] * 1000
        normal_valid_time = (normal_time_ms >= 0) & (normal_time_ms <= 20)
        normal_time = normal_time_ms[normal_valid_time]
        normal_abr = normal_data['mean_abr'][normal_valid_time] * (1.0 / 10000)  # Scale to μV
        
        for pert_type, results in all_ansd_categories[category]:
            ansd_time_ms = results['time'] * 1000
            ansd_valid_time = (ansd_time_ms >= 0) & (ansd_time_ms <= 20)
            ansd_time = ansd_time_ms[ansd_valid_time]
            ansd_abr = results['mean_abr'][ansd_valid_time] * (1.0 / 10000)  # Scale to μV
            
            # Need to interpolate to get the same time points
            # Use the shorter of the two time arrays
            min_len = min(len(normal_time), len(ansd_time))
            if min_len < 5:  # Too short to be meaningful
                continue
                
            common_time = np.linspace(max(normal_time[0], ansd_time[0]), 
                                      min(normal_time[-1], ansd_time[-1]), 
                                      1000)  # 1000 points for smooth interpolation
            
            normal_interp = np.interp(common_time, normal_time, normal_abr)
            ansd_interp = np.interp(common_time, ansd_time, ansd_abr)
            
            # Calculate difference
            diff = ansd_interp - normal_interp
            
            # Plot difference
            color = perturbation_colors.get(pert_type, 'gray')
            plt.plot(common_time, diff, color=color, linewidth=1.5,
                   label=f"{pert_type} (n={results['n_samples']})")
        
        # Add zero line for reference
        plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        
        plt.title(f'ANSD - Normal Difference - {category}')
        plt.xlabel('Time (ms)')
        plt.ylabel('Amplitude Difference (μV)')
        plt.grid(True, alpha=0.3)
        plt.legend(loc='best')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'difference_plot_{category}.png'), dpi=300)
        plt.close()

# %%
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

# %%
def save_abr_results(category_results, output_dir, perturbation_type=None):
    """
    Save complex ABR results as MAT files and CSV summary.
    
    Parameters:
    -----------
    category_results : dict
        Dictionary with category as key and dict of ABR results as value
    output_dir : str
        Directory to save MAT files
    perturbation_type : str, optional
        Perturbation type (if applicable) to include in filenames
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Add perturbation type to filename if provided
    suffix = f"_{perturbation_type}" if perturbation_type else ""
    
    # Save each category as a separate MAT file
    for category, results in category_results.items():
        output_file = os.path.join(output_dir, f'complex_abr_{category}{suffix}.mat')
        savemat(output_file, results)
    
    # Also save as a combined file
    savemat(os.path.join(output_dir, f'complex_abr_all_categories{suffix}.mat'), category_results)
    
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
            
            # Create summary dictionary
            summary_row = {
                'Category': category,
                'NumSamples': results['n_samples'],
                'PeakLatency_ms': round(peak_time, 2),
                'TroughLatency_ms': round(trough_time, 2),
                'PeakAmplitude_uV': round(peak_value, 4),
                'TroughAmplitude_uV': round(trough_value, 4),
                'PeakToTroughAmplitude_uV': round(peak_to_trough, 4),
                'WaveV_Latency_ms': round(wave_v_latency, 2) if wave_v_latency is not None else None,
                'WaveV_Amplitude_uV': round(wave_v_amplitude, 4) if wave_v_amplitude is not None else None
            }
            
            # Add perturbation type if provided
            if perturbation_type:
                summary_row['PerturbationType'] = perturbation_type
                
            summary_data.append(summary_row)
    
    # Save summary as CSV
    summary_df = pd.DataFrame(summary_data)
    summary_df.to_csv(os.path.join(output_dir, f'complex_abr_metrics{suffix}.csv'), index=False)

# %%
def save_perturbation_results(perturbation_results, output_dir):
    """
    Save ABR results for different perturbation types.
    
    Parameters:
    -----------
    perturbation_results : dict
        Dictionary with perturbation type as key and category results as value
    output_dir : str
        Directory to save results
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Save each perturbation type separately
    for pert_type, category_results in perturbation_results.items():
        # Create directory for this perturbation type
        pert_dir = os.path.join(output_dir, f"perturbation_{pert_type}")
        os.makedirs(pert_dir, exist_ok=True)
        
        # Save category results for this perturbation type
        save_abr_results(category_results, pert_dir, pert_type)
    
    # Create a combined CSV with all perturbation types
    all_summary_data = []
    
    for pert_type, category_results in perturbation_results.items():
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
                
                all_summary_data.append({
                    'PerturbationType': pert_type,
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
    
    # Save combined summary as CSV
    if all_summary_data:
        all_summary_df = pd.DataFrame(all_summary_data)
        all_summary_df.to_csv(os.path.join(output_dir, 'all_perturbation_metrics.csv'), index=False)

# %%
def main_ansd():
    """
    Main function to process ANSD neurograms and generate ABRs.
    """
    # Configuration
    base_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all'
    ansd_neurogram_base_path = os.path.join(base_dir, 'SELECT_Neurograms_ANSD/TEST')  # Change to TEST or TRAIN as needed
    output_dir = os.path.join(base_dir, 'ABR_SELECT/ansd_silence')
    normal_abr_dir = os.path.join(base_dir, 'ABR_SELECT/healthy_silence')  # Directory with normal ABR results
    
    # Perturbation types file
    perturbation_types_file = os.path.join(base_dir, 'perturbation_types.json')
    
    # Parameters
    sampling_frequency = 20000  # Hz
    ap_duration = 1  # ms
    ap_type = 'auditory_nerve'  # Type of action potential template to use
    
    # Create output directories
    os.makedirs(output_dir, exist_ok=True)
    
    # Also create comparison directory
    comparison_dir = os.path.join(output_dir, 'comparison_with_normal')
    os.makedirs(comparison_dir, exist_ok=True)
    
    # Step 1: Plot action potential templates for reference
    plot_action_potential_templates(output_dir, 
                                  fs=sampling_frequency, 
                                  duration=ap_duration)
    
    # Step 2: Read ANSD neurograms with perturbation type information
    print("Reading ANSD neurogram files...")
    ansd_neurograms = read_ansd_neurograms(ansd_neurogram_base_path, perturbation_types_file)
    print(f"Found {len(ansd_neurograms)} ANSD neurogram files")
    
    # Step 3: Compute complex ABRs by category and perturbation type
    print(f"Computing complex ABRs for ANSD neurograms using '{ap_type}' template...")
    perturbation_results = compute_complex_abr_by_category_and_perturbation(
        ansd_neurograms, 
        fs=sampling_frequency,
        ap_duration=ap_duration,
        ap_type=ap_type
    )
    
    # Step 4: Plot results for each perturbation type
    print("Generating plots by perturbation type...")
    plot_complex_abrs_by_category_and_perturbation(perturbation_results, output_dir)
    
    # Step 5: Save results
    print("Saving results for each perturbation type...")
    save_perturbation_results(perturbation_results, output_dir)
    
    # Step 6: Compare with normal ABRs if available
    if os.path.exists(normal_abr_dir):
        print("Comparing ANSD to normal ABRs...")
        
        # Try to load normal ABR results
        normal_mat_file = os.path.join(normal_abr_dir, 'complex_abr_all_categories.mat')
        if os.path.exists(normal_mat_file):
            try:
                normal_data = loadmat(normal_mat_file)
                
                # Fix for handling the MAT file structure correctly
                normal_results = {}
                
                # Check if there's a category_results key that might contain all categories
                if 'category_results' in normal_data:
                    for category, data in normal_data['category_results'].items():
                        if isinstance(data, dict):
                            normal_results[category] = data
                else:
                    # Try to directly extract each category
                    for key in normal_data.keys():
                        if not key.startswith('__') and key in phoneme_category_map.values():
                            cat_data = normal_data[key]
                            if isinstance(cat_data, dict):
                                normal_results[key] = cat_data
                
                # If still empty, try loading individual category MAT files
                if not normal_results:
                    print("Trying to load individual category MAT files...")
                    for category in phoneme_category_map.values():
                        cat_file = os.path.join(normal_abr_dir, f'complex_abr_{category}.mat')
                        if os.path.exists(cat_file):
                            try:
                                cat_data = loadmat(cat_file)
                                # Convert any relevant keys to our format
                                if 'mean_abr' in cat_data and 'std_abr' in cat_data and 'time' in cat_data:
                                    normal_results[category] = {
                                        'mean_abr': cat_data['mean_abr'],
                                        'std_abr': cat_data['std_abr'],
                                        'time': cat_data['time'],
                                        'n_samples': cat_data.get('n_samples', 0)
                                    }
                            except Exception as e:
                                print(f"Error loading {cat_file}: {e}")
                
                try:
                    # Plot comparison
                    plot_normal_vs_ansd_comparison(normal_results, perturbation_results, comparison_dir)
                    print(f"Comparison plots saved to {comparison_dir}")
                    
                    # Create the five-column comparison plots 
                    five_col_dir = os.path.join(output_dir, 'five_column_comparison')
                    os.makedirs(five_col_dir, exist_ok=True)
                    plot_five_column_comparison(normal_results, perturbation_results, five_col_dir)
                    print(f"Five-column comparison plots saved to {five_col_dir}")
                    
                    # Create amplitude and latency heatmaps
                    heatmap_dir = os.path.join(output_dir, 'heatmaps')
                    os.makedirs(heatmap_dir, exist_ok=True)
                    create_abr_heatmaps(normal_results, perturbation_results, heatmap_dir)
                    print(f"Amplitude and latency heatmaps saved to {heatmap_dir}")
                except Exception as e:
                    print(f"Error during visualization: {e}")
                    print("Skipping some comparison visualizations")
                
            except Exception as e:
                print(f"Error loading normal ABR data: {e}")
                print("Skipping normal vs. ANSD comparison")
        else:
            print(f"Normal ABR file not found at {normal_mat_file}")
            print("Skipping normal vs. ANSD comparison")
    
    # Step 7: Save metadata about the computation
    metadata = {
        'sampling_frequency': sampling_frequency,
        'ap_duration': ap_duration,
        'ap_type': ap_type,
        'date_computed': pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S'),
        'neurogram_source': ansd_neurogram_base_path,
        'perturbation_types_source': perturbation_types_file
    }
    
    # Save metadata as JSON
    with open(os.path.join(output_dir, 'computation_metadata.json'), 'w') as f:
        json.dump(metadata, f, indent=4)
    
    # Count total phonemes processed by category and perturbation
    category_pert_counts = {}
    for item in ansd_neurograms:
        category = item['Category']
        pert_type = item['PerturbationType']
        
        if category not in category_pert_counts:
            category_pert_counts[category] = {}
        
        if pert_type not in category_pert_counts[category]:
            category_pert_counts[category][pert_type] = 0
            
        category_pert_counts[category][pert_type] += 1
    
    # Save distribution
    distribution_rows = []
    for category, pert_counts in category_pert_counts.items():
        for pert_type, count in pert_counts.items():
            distribution_rows.append({
                'Category': category,
                'PerturbationType': pert_type,
                'Count': count
            })
    
    distribution_df = pd.DataFrame(distribution_rows)
    distribution_df.to_csv(os.path.join(output_dir, 'category_perturbation_distribution.csv'), index=False)
    
    # Print summary
    print("\nSummary of processed ANSD data:")
    print(f"Total ANSD neurograms processed: {len(ansd_neurograms)}")
    print("\nPerturbation types processed:")
    
    pert_counts = {}
    for item in ansd_neurograms:
        pert_type = item['PerturbationType']
        if pert_type not in pert_counts:
            pert_counts[pert_type] = 0
        pert_counts[pert_type] += 1
    
    for pert_type, count in sorted(pert_counts.items()):
        print(f"  {pert_type}: {count} neurograms")
    
    print(f"\nAnalysis complete! Results saved to {output_dir}")
    
    return perturbation_results

# %%
if __name__ == "__main__":
    perturbation_results = main_ansd()
# %%    