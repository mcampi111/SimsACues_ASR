# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.io import loadmat
from scipy.interpolate import interp1d
import ot
import pickle
from scipy.spatial.distance import cdist
import ast  # for safely evaluating strings as literals
from tqdm import tqdm  # for progress bars
import re  # for regex pattern matching
# %%
# Define target frequencies that are perceptually relevant for speech
TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz

# Define noise types to analyze
NOISE_TYPES = [
    'random',
    'snr-5.0',
    'snr0.0',
    'snr5.0',
    'snr10.0',
    'snr15.0'
]

# Phoneme category mapping
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
def find_closest_indices(center_frequencies, target_frequencies):
    """
    Find indices of center frequencies closest to target frequencies.
    
    Parameters:
    center_frequencies (array): Array of all center frequencies
    target_frequencies (array): Array of target frequencies to match
    
    Returns:
    list: Indices of closest matches
    """
    selected_indices = []
    for target in target_frequencies:
        idx = np.argmin(np.abs(center_frequencies - target))
        selected_indices.append(idx)
    return selected_indices

def extract_noise_type(filename):
    """
    Extract the noise type from the filename.
    
    Parameters:
    filename (str): Name of the file
    
    Returns:
    str: Noise type or None if no match
    """
    if 'random' in filename:
        return 'random'
    
    # Try to match SNR pattern
    snr_match = re.search(r'snr([+-]?\d+\.\d+)', filename)
    if snr_match:
        return f'snr{snr_match.group(1)}'
    
    return None

def read_neurograms_from_directory(base_path):
    """
    Read neurograms with noise from a directory structure.
    
    Parameters:
    base_path (str): Path to the base directory containing DR1-DR7 folders
    
    Returns:
    DataFrame with neurograms and metadata
    """
    all_neurograms = []
    
    # Iterate through DR directories
    for dr_folder in sorted(os.listdir(base_path)):
        if dr_folder.startswith('.') or not os.path.isdir(os.path.join(base_path, dr_folder)):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        # Iterate through speaker directories
        for speaker_folder in sorted(os.listdir(dr_path)):
            if speaker_folder.startswith('.') or not os.path.isdir(os.path.join(dr_path, speaker_folder)):
                continue
            
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            # Iterate through neurogram files
            for mat_file in sorted(os.listdir(speaker_path)):
                # Skip files without noise specification
                if not mat_file.endswith('.mat') or '_with_noise_' not in mat_file:
                    continue
                
                # Extract noise type from filename
                noise_type = extract_noise_type(mat_file)
                if not noise_type:
                    continue
                
                file_path = os.path.join(speaker_path, mat_file)
                
                try:
                    # Load the MAT file
                    data = loadmat(file_path)
                    
                    # Extract neurogram with noise and clean version
                    if 'r_mean_downsampled' in data and 'r_mean_clean_downsampled' in data:
                        neurogram_noisy = data['r_mean_downsampled']
                        neurogram_clean = data['r_mean_clean_downsampled']
                        
                        # Extract center frequencies and select specific channels
                        if 'center_frequencies' in data:
                            center_frequencies = data['center_frequencies'].flatten()
                            
                            # Find indices of frequencies closest to targets
                            selected_indices = find_closest_indices(center_frequencies, TARGET_FREQUENCIES)
                            
                            # Select those channels from both neurograms
                            selected_neurogram_noisy = neurogram_noisy[:, selected_indices]
                            selected_neurogram_clean = neurogram_clean[:, selected_indices]
                            
                            # Get actual selected frequencies
                            selected_frequencies = center_frequencies[selected_indices]
                        else:
                            # If no center frequencies, select evenly spaced channels
                            total_channels = neurogram_noisy.shape[1]
                            selected_indices = np.linspace(0, total_channels-1, 6, dtype=int)
                            
                            selected_neurogram_noisy = neurogram_noisy[:, selected_indices]
                            selected_neurogram_clean = neurogram_clean[:, selected_indices]
                            selected_frequencies = TARGET_FREQUENCIES  # Approximate
                        
                        # Get noise info
                        target_snr = None
                        if 'target_snr_db' in data:
                            target_snr = float(data['target_snr_db'].flatten()[0])
                        
                        noise_filename = None
                        if 'noise_filename' in data:
                            noise_filename = str(data['noise_filename'][0])
                        
                        # Extract metadata from filename
                        # Format: SA1_aa_19962_21514_neurogram_with_noise_snr5.0.mat
                        parts = mat_file.split('_neurogram_')[0].split('_')
                        
                        if len(parts) >= 3:
                            utterance_id = parts[0]
                            phoneme = parts[1]
                            
                            # Create a row for this neurogram
                            neurogram_row = {
                                'DR': dr_folder,
                                'Speaker': speaker_folder,
                                'Utterance': utterance_id,
                                'Phoneme': phoneme,
                                'Noisy': selected_neurogram_noisy,
                                'Clean': selected_neurogram_clean,
                                'NoiseType': noise_type,
                                'TargetSNR': target_snr,
                                'NoiseFilename': noise_filename,
                                'SelectedFrequencies': selected_frequencies.tolist(),
                                'FilePath': file_path
                            }
                            
                            all_neurograms.append(neurogram_row)
                    else:
                        print(f"Warning: Required neurogram keys not found in {file_path}")
                
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    
    # Convert to DataFrame
    if all_neurograms:
        df = pd.DataFrame(all_neurograms)
        
        # Add Category using the phoneme mapping
        df['Category'] = df['Phoneme'].map(phoneme_category_map)
        df['speaker_phoneme'] = df['Speaker'] + '_' + df['Phoneme']
        
        return df
    else:
        return pd.DataFrame()

def read_formants_from_directory(base_path):
    """
    Read formant data from .pred files.
    
    Parameters:
    base_path (str): Path to the formants directory
    
    Returns:
    DataFrame with formant data
    """
    all_formants = []
    
    # Iterate through DR directories
    for dr_folder in sorted(os.listdir(base_path)):
        if dr_folder.startswith('.') or not os.path.isdir(os.path.join(base_path, dr_folder)):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        # Iterate through speaker directories
        for speaker_folder in sorted(os.listdir(dr_path)):
            if speaker_folder.startswith('.') or not os.path.isdir(os.path.join(dr_path, speaker_folder)):
                continue
            
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            # Process .pred files
            for pred_file in sorted(os.listdir(speaker_path)):
                if not pred_file.endswith('.pred'):
                    continue
                
                file_path = os.path.join(speaker_path, pred_file)
                
                try:
                    # Read formant data
                    formant_df = pd.read_csv(file_path, sep='\t', names=['time', 'f1', 'f2', 'f3'])
                    
                    # Extract metadata from filename
                    # Format: SA1_aa_19962_21514.pred
                    parts = pred_file.replace('.pred', '').split('_')
                    
                    if len(parts) >= 3:
                        utterance_id = parts[0]
                        phoneme = parts[1]
                        
                        # Get formant values
                        f1_values = formant_df['f1'].tolist()
                        f2_values = formant_df['f2'].tolist()
                        f3_values = formant_df['f3'].tolist()
                        
                        # Create a row for this formant data
                        formant_row = {
                            'DR': dr_folder,
                            'speaker': speaker_folder,
                            'Utterance': utterance_id,
                            'phoneme': phoneme,
                            'f1': f1_values,
                            'f2': f2_values,
                            'f3': f3_values,
                            'time': formant_df['time'].tolist(),
                            'FilePath': file_path
                        }
                        
                        all_formants.append(formant_row)
                
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    
    # Convert to DataFrame
    if all_formants:
        formants_df = pd.DataFrame(all_formants)
        
        # Add Category using the phoneme mapping
        formants_df['Category'] = formants_df['phoneme'].map(phoneme_category_map)
        formants_df['speaker_phoneme'] = formants_df['speaker'] + '_' + formants_df['phoneme']
        
        return formants_df
    else:
        return pd.DataFrame()

def compute_mean_formant(formant_series):
    """
    Compute mean of formant values.
    
    Parameters:
    formant_series (Series): Series of formant values (lists)
    
    Returns:
    Series: Series of mean formant values
    """
    def safe_mean(x):
        try:
            if isinstance(x, list):
                return np.mean(x)
            elif isinstance(x, str):
                return np.mean(ast.literal_eval(x))
            return np.nan
        except Exception as e:
            return np.nan
    
    return formant_series.apply(safe_mean)

def extract_neurogram_values(row, neurogram_type='Noisy'):
    """
    Extract mean values for each center frequency.
    
    Parameters:
    row (Series): DataFrame row with neurogram data
    neurogram_type (str): 'Noisy' or 'Clean'
    
    Returns:
    Series: Mean values for each center frequency
    """
    neurogram = row[neurogram_type]
    if isinstance(neurogram, np.ndarray) and neurogram.ndim == 2:
        return pd.Series({f'{neurogram_type}_CF{i+1}_Mean': np.mean(neurogram[:, i]) for i in range(neurogram.shape[1])})
    return pd.Series({f'{neurogram_type}_CF{i+1}_Mean': np.nan for i in range(6)})  # Default 6 CFs

def improved_acoustic_distance(x, y):
    """
    Compute improved acoustic distance with mel scale transformation.
    
    Parameters:
    x, y: Frequency values to compare
    
    Returns:
    float: Distance measure
    """
    epsilon = 1e-10
    
    def freq_to_mel(f):
        return 2595 * np.log10(1 + f/700)
    
    # Ensure inputs are numpy arrays
    x = np.atleast_1d(x) + epsilon
    y = np.atleast_1d(y) + epsilon
    
    # Convert to mel scale
    x_mel = freq_to_mel(x)
    y_mel = freq_to_mel(y)
    
    # Compute normalized difference
    distances = np.abs(x_mel - y_mel) / np.maximum(x_mel, y_mel)
    
    return np.mean(distances)

def compute_formant_cf_distances(df, noise_type=None, neurogram_type='Noisy'):
    """
    Compute distances between formants and center frequencies.
    
    Parameters:
    df (DataFrame): DataFrame with formant and neurogram data
    noise_type (str): Which noise type to analyze (optional, filters the dataframe)
    neurogram_type (str): 'Noisy' or 'Clean' neurograms to use
    
    Returns:
    DataFrame: Results with distance measures
    """
    # Filter by noise type if specified
    if noise_type:
        df = df[df['NoiseType'] == noise_type]
        if len(df) == 0:
            print(f"No data for noise type: {noise_type}")
            return pd.DataFrame()
    
    results = []
    
    # Get category column name
    category_col = 'Category_x' if 'Category_x' in df.columns else 'Category'
    
    # Get unique categories
    categories = df[category_col].unique()
    
    # Process each category
    for category in tqdm(categories, desc=f"Processing categories for {noise_type} ({neurogram_type})"):
        category_df = df[df[category_col] == category]
        
        # Process each formant
        for formant_name in ['f1', 'f2', 'f3']:
            # Get formant data and filter out NaNs
            formant_data = category_df[formant_name + '_mean'].values
            valid_formant_mask = ~np.isnan(formant_data)
            
            # Skip if no valid formant data
            if np.sum(valid_formant_mask) <= 1:
                print(f"Skipping {category}-{formant_name} due to insufficient valid data")
                continue
                
            valid_formant_data = formant_data[valid_formant_mask]
            
            # Compute distance matrix for formant
            formant_matrix = valid_formant_data.reshape(-1, 1)
            try:
                formant_dist_matrix = cdist(formant_matrix, formant_matrix, metric=improved_acoustic_distance)
                
                # Normalize distance matrix (safely handle empty or zero matrices)
                max_dist = np.nanmax(formant_dist_matrix)
                if np.isfinite(max_dist) and max_dist > 0:
                    formant_dist_matrix /= max_dist
                
                # Prepare uniform weights
                p = ot.unif(len(formant_matrix))
                
                # For each center frequency
                for cf_num in range(1, 7):
                    # Get CF data for the same samples that had valid formant data
                    cf_column = f'{neurogram_type}_CF{cf_num}_Mean'
                    
                    if cf_column not in category_df.columns:
                        continue
                        
                    cf_data = category_df[cf_column].iloc[np.where(valid_formant_mask)[0]].values
                    
                    # Skip if no valid CF data
                    if len(cf_data) <= 1:
                        continue
                    
                    # Compute distance matrix for CF
                    cf_matrix = cf_data.reshape(-1, 1)
                    cf_dist_matrix = cdist(cf_matrix, cf_matrix, metric=improved_acoustic_distance)
                    
                    # Normalize distance matrix (safely)
                    max_cf_dist = np.nanmax(cf_dist_matrix)
                    if np.isfinite(max_cf_dist) and max_cf_dist > 0:
                        cf_dist_matrix /= max_cf_dist
                    
                    # Prepare uniform weights
                    q = ot.unif(len(cf_matrix))
                    
                    # Compute Gromov-Wasserstein distance
                    try:
                        gw_dist = ot.gromov.gromov_wasserstein2(
                            formant_dist_matrix, cf_dist_matrix, p, q, loss_fun='square_loss'
                        )
                        
                        # Store result
                        results.append({
                            'Category': category,
                            'Formant': formant_name.upper(),
                            'CF': f'CF{cf_num}',
                            'CF_Freq': TARGET_FREQUENCIES[cf_num-1],  # Approximate from target
                            'NoiseType': noise_type if noise_type else 'All',
                            'NeurogramType': neurogram_type,
                            'GW_Distance': round(gw_dist, 3),
                            'NumSamples': len(valid_formant_data)
                        })
                    except Exception as e:
                        print(f"Error computing GW distance for {category}-{formant_name}-CF{cf_num}: {e}")
            except Exception as e:
                print(f"Error with distance matrix for {category}-{formant_name}: {e}")
    
    return pd.DataFrame(results)

def create_visualizations(distance_results, output_dir, noise_type=None, neurogram_type='Noisy'):
    """
    Create visualizations for the distance results.
    
    Parameters:
    distance_results (DataFrame): Results from compute_formant_cf_distances
    output_dir (str): Directory to save visualizations
    noise_type (str): Noise type for file naming
    neurogram_type (str): 'Noisy' or 'Clean' for file naming
    """
    suffix = f"_{noise_type}_{neurogram_type}" if noise_type else f"_{neurogram_type}"
    
    # Heatmap of distances by formant, CF, and category
    plt.figure(figsize=(15, 10))
    pivot_data = distance_results.pivot_table(
        index='Category',
        columns=['Formant', 'CF'],
        values='GW_Distance',
        aggfunc='mean'
    )
    
    sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
    title = f'Mean GW Distances Between Formants and Center Frequencies - {neurogram_type}'
    if noise_type:
        title += f" ({noise_type})"
    plt.title(title)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'formant_cf_heatmap{suffix}.png'), dpi=300)
    plt.close()
    
    # Separate heatmaps for each formant
    for formant in ['F1', 'F2', 'F3']:
        plt.figure(figsize=(10, 8))
        
        formant_data = distance_results[distance_results['Formant'] == formant]
        pivot_data = formant_data.pivot_table(
            index='Category',
            columns='CF',
            values='GW_Distance',
            aggfunc='mean'
        )
        
        sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
        title = f'Mean GW Distances: {formant} to Center Frequencies - {neurogram_type}'
        if noise_type:
            title += f" ({noise_type})"
        plt.title(title)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'{formant}_cf_heatmap{suffix}.png'), dpi=300)
        plt.close()

def compare_noise_types(all_results, output_dir, neurogram_type='Noisy'):
    """
    Create visualizations comparing different noise types.
    
    Parameters:
    all_results (DataFrame): Combined results from all noise types
    output_dir (str): Directory to save visualizations
    neurogram_type (str): 'Noisy' or 'Clean' results to compare
    """
    # Filter by neurogram type
    filtered_results = all_results[all_results['NeurogramType'] == neurogram_type]
    suffix = f"_{neurogram_type}"
    
    # Compare GW distances across noise types (for each formant)
    for formant in ['F1', 'F2', 'F3']:
        plt.figure(figsize=(15, 10))
        
        formant_data = filtered_results[filtered_results['Formant'] == formant]
        pivot_data = formant_data.pivot_table(
            index='Category',
            columns=['NoiseType'],
            values='GW_Distance',
            aggfunc='mean'
        )
        
        sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
        plt.title(f'Mean GW Distances for {formant} Across Noise Types - {neurogram_type}')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'{formant}_noise_comparison{suffix}.png'), dpi=300)
        plt.close()
    
    # Compare GW distances across noise types (averaged across all formants and CFs)
    plt.figure(figsize=(12, 8))
    summary_data = filtered_results.groupby(['NoiseType', 'Category'])['GW_Distance'].mean().reset_index()
    pivot_data = summary_data.pivot(index='Category', columns='NoiseType', values='GW_Distance')
    
    sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
    plt.title(f'Overall Mean GW Distances Across Noise Types - {neurogram_type}')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'overall_noise_comparison{suffix}.png'), dpi=300)
    plt.close()
    
    # Bar plot comparison for SNR levels
    snr_data = filtered_results[filtered_results['NoiseType'].str.startswith('snr')]
    if not snr_data.empty:
        plt.figure(figsize=(12, 8))
        # Extract SNR value for sorting
        snr_data['SNR'] = snr_data['NoiseType'].apply(lambda x: float(x.replace('snr', '')))
        snr_summary = snr_data.groupby(['SNR'])['GW_Distance'].mean().reset_index()
        snr_summary = snr_summary.sort_values('SNR')
        
        plt.bar(snr_summary['SNR'].astype(str), snr_summary['GW_Distance'])
        plt.title(f'Mean GW Distance by SNR Level - {neurogram_type}')
        plt.xlabel('SNR (dB)')
        plt.ylabel('Mean GW Distance')
        plt.grid(axis='y', linestyle='--', alpha=0.7)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'snr_comparison{suffix}.png'), dpi=300)
        plt.close()

def compare_clean_vs_noisy(all_results, output_dir):
    """
    Create visualizations comparing clean vs. noisy neurograms.
    
    Parameters:
    all_results (DataFrame): Combined results from all analyses
    output_dir (str): Directory to save visualizations
    """
    # Pivot table comparing Clean vs Noisy for each noise type and category
    plt.figure(figsize=(15, 10))
    
    # Group by relevant columns and compute mean distances
    summary = all_results.groupby(['NoiseType', 'Category', 'NeurogramType'])['GW_Distance'].mean().reset_index()
    
    # Create pivot table
    pivot_data = summary.pivot_table(
        index=['Category', 'NoiseType'],
        columns='NeurogramType',
        values='GW_Distance'
    )
    
    # Compute difference column
    if 'Clean' in pivot_data.columns and 'Noisy' in pivot_data.columns:
        pivot_data['Difference'] = pivot_data['Noisy'] - pivot_data['Clean']
    
    # Sort by the difference to see most affected categories
    if 'Difference' in pivot_data.columns:
        pivot_data = pivot_data.sort_values(by=['NoiseType', 'Difference'], ascending=[True, False])
    
    # Plot the comparison
    plt.figure(figsize=(12, len(pivot_data) * 0.4))
    sns.heatmap(pivot_data, annot=True, cmap='coolwarm', fmt='.3f', center=0)
    plt.title('Comparison of Clean vs. Noisy Neurograms (Difference = Noisy - Clean)')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'clean_vs_noisy_comparison.png'), dpi=300)
    plt.close()
    
    # Bar plot showing average difference by noise type
    if 'Difference' in pivot_data.columns:
        diff_by_noise = pivot_data.groupby(level='NoiseType')['Difference'].mean()
        
        plt.figure(figsize=(10, 6))
        diff_by_noise.plot(kind='bar', color='skyblue')
        plt.title('Average Difference (Noisy - Clean) by Noise Type')
        plt.ylabel('Mean Difference in GW Distance')
        plt.grid(axis='y', linestyle='--', alpha=0.7)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'avg_difference_by_noise.png'), dpi=300)
        plt.close()

# Main execution
def main():
    # Define file paths
    neurogram_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_WithNoise/TEST/'
    formants_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Formants/Phonemes/TEST/'
    output_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_F_vs_Neuro_Noise_Results/'
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    print("Loading neurogram data...")
    df_neurograms = read_neurograms_from_directory(neurogram_base_path)
    print(f"Loaded {len(df_neurograms)} neurograms")
    
    # Check distribution of noise types
    if 'NoiseType' in df_neurograms.columns:
        noise_counts = df_neurograms['NoiseType'].value_counts()
        print("\nNoise type distribution:")
        print(noise_counts)
    
    print("Loading formant data...")
    df_formants = read_formants_from_directory(formants_base_path)
    print(f"Loaded {len(df_formants)} formant measurements")
    
    # Merge the dataframes
    print("Merging neurogram and formant data...")
    merged_df = pd.merge(
        df_neurograms, 
        df_formants, 
        left_on=['Speaker', 'Phoneme'], 
        right_on=['speaker', 'phoneme'], 
        how='inner'  # Use inner join to keep only matching entries
    )
    print(f"Merged dataframe has {len(merged_df)} rows")
    
    # Compute mean formant values
    print("Computing mean formant values...")
    merged_df['f1_mean'] = compute_mean_formant(merged_df['f1'])
    merged_df['f2_mean'] = compute_mean_formant(merged_df['f2'])
    merged_df['f3_mean'] = compute_mean_formant(merged_df['f3'])
    
    # Extract neurogram mean values for both noisy and clean
    print("Extracting neurogram CF values...")
    noisy_means = merged_df.apply(lambda row: extract_neurogram_values(row, 'Noisy'), axis=1)
    clean_means = merged_df.apply(lambda row: extract_neurogram_values(row, 'Clean'), axis=1)
    
    # Combine with main dataframe
    merged_df = pd.concat([merged_df, noisy_means, clean_means], axis=1)
    
    # Sample the data if it's too large (group by noise type and phoneme)
    if len(merged_df) > 1000:
        print(f"Sampling data (original size: {len(merged_df)})...")
        merged_df = merged_df.groupby(['NoiseType', 'Phoneme']).apply(
            lambda x: x if len(x) <= 50 else x.sample(n=50, random_state=42)
        ).reset_index(drop=True)
        print(f"Sampled size: {len(merged_df)}")

    # Save merged data
    merged_df.to_pickle(os.path.join(output_dir, 'merged_data_noise.pkl'))
    
    # Process each noise type separately for both noisy and clean neurograms
    all_results = []
    
    for neurogram_type in ['Noisy', 'Clean']:
        print(f"\nProcessing {neurogram_type} neurograms")
        
        # First process all noise types together
        print("Processing all noise types combined...")
        distance_results = compute_formant_cf_distances(merged_df, neurogram_type=neurogram_type)
        
        if not distance_results.empty:
            # Save results
            distance_results.to_pickle(os.path.join(output_dir, f'formant_cf_distances_all_{neurogram_type.lower()}.pkl'))
            
            # Create visualizations
            create_visualizations(distance_results, output_dir, neurogram_type=neurogram_type)
            
            # Add to combined results
            all_results.append(distance_results)
        
        # Then process each noise type separately
        for noise_type in NOISE_TYPES:
            print(f"Processing noise type: {noise_type}")
            
            # Compute distances
            distance_results = compute_formant_cf_distances(merged_df, noise_type, neurogram_type)
            
            if not distance_results.empty:
                # Save results
                distance_results.to_pickle(os.path.join(output_dir, f'formant_cf_distances_{noise_type}_{neurogram_type.lower()}.pkl'))
                
                # Create visualizations
                create_visualizations(distance_results, output_dir, noise_type, neurogram_type)
                
                # Add to combined results
                all_results.append(distance_results)
    
    # Combine all results
    if all_results:
        combined_results = pd.concat(all_results, ignore_index=True)
        combined_results.to_pickle(os.path.join(output_dir, 'formant_cf_distances_all_combined.pkl'))
        
        # Create comparison visualizations
        for neurogram_type in ['Noisy', 'Clean']:
            compare_noise_types(combined_results, output_dir, neurogram_type)
        
        # Compare clean vs noisy
        compare_clean_vs_noisy(combined_results, output_dir)
    
    print("Analysis complete!")
    return merged_df, combined_results if all_results else None
# %%
if __name__ == "__main__":
    merged_df, distance_results = main()
# %%