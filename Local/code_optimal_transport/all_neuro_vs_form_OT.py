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
# %%
# Define target frequencies that are perceptually relevant for speech
TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz
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

def load_and_select_frequencies(neurogram_path):
    """
    Load a neurogram and select only the 6 target frequencies.
    
    Parameters:
    neurogram_path (str): Path to the neurogram MAT file
    
    Returns:
    ndarray: Neurogram with only 6 selected frequency channels
    list: Actual selected frequencies
    """
    try:
        # Load the MAT file
        data = loadmat(neurogram_path)
        
        # Extract neurogram and center frequencies
        neurogram = data['r_mean_downsampled']
        center_frequencies = data['center_frequencies'].flatten()
        
        # Find indices of frequencies closest to targets
        selected_indices = find_closest_indices(center_frequencies, TARGET_FREQUENCIES)
        
        # Select only those channels from the neurogram
        selected_neurogram = neurogram[:, selected_indices]
        
        # Get the actual selected frequencies for reference
        selected_frequencies = center_frequencies[selected_indices]
        
        return selected_neurogram, selected_frequencies
    
    except Exception as e:
        print(f"Error loading {neurogram_path}: {e}")
        return None, None

def read_neurograms_from_directory(base_path):
    """
    Read neurograms from a directory structure, selecting only 6 target frequencies.
    
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
                if not mat_file.endswith('_neurogram.mat'):
                    continue
                
                file_path = os.path.join(speaker_path, mat_file)
                
                try:
                    # Load neurogram with selected frequencies
                    neurogram, selected_freqs = load_and_select_frequencies(file_path)
                    
                    if neurogram is None:
                        continue
                    
                    # Extract metadata from filename
                    # Format: SA1_aa_19962_21514_neurogram.mat
                    parts = mat_file.replace('_neurogram.mat', '').split('_')
                    
                    if len(parts) >= 3:
                        utterance_id = parts[0]
                        phoneme = parts[1]
                        
                        # Create a row for this neurogram
                        neurogram_row = {
                            'DR': dr_folder,
                            'Speaker': speaker_folder,
                            'Utterance': utterance_id,
                            'Phoneme': phoneme,
                            'Original': neurogram,
                            'SelectedFrequencies': selected_freqs.tolist(),
                            'FilePath': file_path
                        }
                        
                        all_neurograms.append(neurogram_row)
                    
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    
    # Convert to DataFrame
    if all_neurograms:
        return pd.DataFrame(all_neurograms)
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

def extract_neurogram_values(row):
    """
    Extract mean values for each center frequency.
    
    Parameters:
    row (Series): DataFrame row with neurogram data
    
    Returns:
    Series: Mean values for each center frequency
    """
    neurogram = row['Original']
    if isinstance(neurogram, np.ndarray) and neurogram.ndim == 2:
        return pd.Series({f'CF{i+1}_Mean': np.mean(neurogram[:, i]) for i in range(neurogram.shape[1])})
    return pd.Series({f'CF{i+1}_Mean': np.nan for i in range(6)})  # Default 6 CFs

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

def compute_formant_cf_distances(df):
    """
    Compute distances between formants and center frequencies.
    
    Parameters:
    df (DataFrame): DataFrame with formant and neurogram data
    
    Returns:
    DataFrame: Results with distance measures
    """
    results = []
    
    # Get unique categories
    categories = df['Category'].unique()
    
    # Process each category
    for category in tqdm(categories, desc="Processing categories"):
        category_df = df[df['Category'] == category]
        
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
                    cf_column = category_df[f'CF{cf_num}_Mean']
                    valid_indices = np.where(valid_formant_mask)[0]
                    cf_data = cf_column.iloc[valid_indices].values
                    
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
                            'CF_Freq': TARGET_FREQUENCIES[cf_num-1],  # Approximate frequency
                            'GW_Distance': round(gw_dist, 3),
                            'NumSamples': len(valid_formant_data)
                        })
                    except Exception as e:
                        print(f"Error computing GW distance for {category}-{formant_name}-CF{cf_num}: {e}")
            except Exception as e:
                print(f"Error with distance matrix for {category}-{formant_name}: {e}")
    
    return pd.DataFrame(results)

# Main execution
def main():
    # Define file paths
    neurogram_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/TEST/'
    formants_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Formants/Phonemes/TEST/'
    output_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_F_vs_Neuro_Results/'
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    print("Loading neurogram data...")
    df_neurograms = read_neurograms_from_directory(neurogram_base_path)
    print(f"Loaded {len(df_neurograms)} neurograms")
    
    print("Loading formant data...")
    df_formants = read_formants_from_directory(formants_base_path)
    print(f"Loaded {len(df_formants)} formant measurements")
    
    # Create unique speaker-phoneme identifiers
    df_neurograms['speaker_phoneme'] = df_neurograms['Speaker'] + '_' + df_neurograms['Phoneme']
    
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
    
    # Extract neurogram mean values
    print("Extracting neurogram CF values...")
    cf_means = merged_df.apply(extract_neurogram_values, axis=1)
    merged_df = pd.concat([merged_df, cf_means], axis=1)
    
    # Sample the data if it's too large
    if len(merged_df) > 1000:
        print(f"Sampling data (original size: {len(merged_df)})...")
        merged_df = merged_df.groupby('Phoneme').apply(
            lambda x: x if len(x) <= 100 else x.sample(n=100, random_state=42)
        ).reset_index(drop=True)
        print(f"Sampled size: {len(merged_df)}")

    # Add diagnostic information before running distance calculations
    print("\nDiagnostic information:")
    for category in merged_df['Category'].unique():
        category_df = merged_df[merged_df['Category'] == category]
        for formant in ['f1_mean', 'f2_mean', 'f3_mean']:
            valid_count = category_df[formant].notna().sum()
            total_count = len(category_df)
            print(f"{category} - {formant}: {valid_count}/{total_count} valid values")    
    
    # Compute distances between formants and center frequencies
    print("Computing distances between formants and center frequencies...")
    distance_results = compute_formant_cf_distances(merged_df)
    
    # Save results
    print("Saving results...")
    merged_df.to_pickle(os.path.join(output_dir, 'merged_data.pkl'))
    distance_results.to_pickle(os.path.join(output_dir, 'formant_cf_distances.pkl'))
    
    # Create visualizations
    print("Creating visualizations...")
    
    # Heatmap of distances by formant, CF, and category
    plt.figure(figsize=(15, 10))
    pivot_data = distance_results.pivot_table(
        index='Category',
        columns=['Formant', 'CF'],
        values='GW_Distance',
        aggfunc='mean'
    )
    
    sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
    plt.title('Mean GW Distances Between Formants and Center Frequencies')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'formant_cf_heatmap.png'), dpi=300)
    
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
        plt.title(f'Mean GW Distances: {formant} to Center Frequencies')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'{formant}_cf_heatmap.png'), dpi=300)
    
    print("Analysis complete!")
    return merged_df, distance_results
# %%
if __name__ == "__main__":
    merged_df, distance_results = main()
# %%