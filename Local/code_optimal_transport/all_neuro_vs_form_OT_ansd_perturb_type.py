# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.io import loadmat
from scipy.spatial.distance import cdist
import ot
import json
import ast
from tqdm import tqdm
from collections import Counter
# %%  
# Define target frequencies that are perceptually relevant for speech
TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz

# Phoneme category mapping (using your existing mapping)
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
def select_channels(neurogram, num_channels=6):
    """Select evenly spaced channels from a neurogram."""
    if neurogram is None or neurogram.ndim != 2:
        return None
    
    total_channels = neurogram.shape[1]
    indices = np.linspace(0, total_channels-1, num_channels, dtype=int)
    return neurogram[:, indices]

def get_test_speakers(test_dir):
    """Get the list of speaker folders in the TEST directory."""
    test_speakers = set()
    
    for dr_folder in sorted(os.listdir(test_dir)):
        dr_path = os.path.join(test_dir, dr_folder)
        
        if not os.path.isdir(dr_path) or dr_folder.startswith('.'):
            continue
            
        for speaker_folder in sorted(os.listdir(dr_path)):
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            if not os.path.isdir(speaker_path) or speaker_folder.startswith('.'):
                continue
                
            test_speakers.add(speaker_folder)
    
    return test_speakers

def load_perturbation_types_for_test(json_path, test_speakers):
    """
    Load perturbation type information from JSON file,
    filtering for entries corresponding to TEST speakers.
    
    Parameters:
    json_path (str): Path to the perturbation_types.json file
    test_speakers (set): Set of speaker folders in the TEST directory
    
    Returns:
    dict: Filtered perturbation types for TEST speakers
    """
    try:
        with open(json_path, 'r') as f:
            all_pert_types = json.load(f)
        
        # This will hold perturbation types for files in TEST directory
        filtered_pert_types = {}
        
        # For each entry in the JSON file
        for filename, pert_type in all_pert_types.items():
            # Try to extract speaker information from the filename
            # We'll need to rely on your directory/file structure for this
            # The assumption is that your filenames in the JSON don't include paths
            
            # Based on your file examination script, try to extract utterance and phoneme
            parts = filename.replace('_neurogram_ansd.mat', '').split('_')
            
            if len(parts) >= 2:
                utterance_id = parts[0]  # e.g., "SX30"
                
                # Now we need to check if this file belongs to a TEST speaker
                # We'll have to check all TEST speaker directories
                for speaker in test_speakers:
                    # Look for this file in the TEST directory under this speaker
                    matches_found = False
                    for dr_folder in range(1, 8):  # DR1 to DR7
                        dr_name = f"DR{dr_folder}"
                        check_path = f"/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/TEST/{dr_name}/{speaker}/{filename}"
                        
                        if os.path.exists(check_path):
                            # This file exists in TEST directory, so add it to our filtered list
                            filtered_pert_types[filename] = pert_type
                            matches_found = True
                            break
                    
                    if matches_found:
                        break
        
        return filtered_pert_types
    
    except Exception as e:
        print(f"Error loading perturbation types: {e}")
        return {}

def read_neurograms_with_perturbation(base_path, pert_types):
    """Read neurograms and add perturbation type information using the filename as the key."""
    all_neurograms = []
    
    for dr_folder in sorted(os.listdir(base_path)):
        if dr_folder.startswith('.') or not os.path.isdir(os.path.join(base_path, dr_folder)):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        for speaker_folder in sorted(os.listdir(dr_path)):
            if speaker_folder.startswith('.') or not os.path.isdir(os.path.join(dr_path, speaker_folder)):
                continue
            
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            for mat_file in sorted(os.listdir(speaker_path)):
                if not mat_file.endswith('_neurogram_ansd.mat'):
                    continue
                
                file_path = os.path.join(speaker_path, mat_file)
                
                try:
                    data = loadmat(file_path)
                    
                    if 'r_mean_downsampled' in data:
                        neurogram = data['r_mean_downsampled']
                        selected_neurogram = select_channels(neurogram)
                        
                        # Extract metadata from filename
                        file_base = mat_file.replace('_neurogram_ansd.mat', '')
                        parts = file_base.split('_')
                        
                        if len(parts) >= 2:
                            utterance_id = parts[0]
                            phoneme = parts[1]
                            
                            # Get perturbation type using the filename as the key
                            perturbation_type = pert_types.get(mat_file, 'normal')
                            
                            neurogram_row = {
                                'DR': dr_folder,
                                'Speaker': speaker_folder,
                                'Utterance': utterance_id,
                                'Phoneme': phoneme,
                                'Original': selected_neurogram,
                                'SelectedFrequencies': TARGET_FREQUENCIES,
                                'FilePath': file_path,
                                'FileName': mat_file,
                                'PerturbationType': perturbation_type
                            }
                            
                            all_neurograms.append(neurogram_row)
                    else:
                        print(f"Warning: 'r_mean_downsampled' not found in {file_path}")
                
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    
    if all_neurograms:
        df = pd.DataFrame(all_neurograms)
        df['Category'] = df['Phoneme'].map(phoneme_category_map)
        df['speaker_phoneme'] = df['Speaker'] + '_' + df['Phoneme']
        return df
    else:
        return pd.DataFrame()

def read_formants_from_directory(base_path):
    """Read formant data from .pred files."""
    all_formants = []
    
    for dr_folder in sorted(os.listdir(base_path)):
        if dr_folder.startswith('.') or not os.path.isdir(os.path.join(base_path, dr_folder)):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        for speaker_folder in sorted(os.listdir(dr_path)):
            if speaker_folder.startswith('.') or not os.path.isdir(os.path.join(dr_path, speaker_folder)):
                continue
            
            speaker_path = os.path.join(dr_path, speaker_folder)
            
            for pred_file in sorted(os.listdir(speaker_path)):
                if not pred_file.endswith('.pred'):
                    continue
                
                file_path = os.path.join(speaker_path, pred_file)
                
                try:
                    formant_df = pd.read_csv(file_path, sep='\t', names=['time', 'f1', 'f2', 'f3'])
                    
                    file_base = pred_file.replace('.pred', '')
                    parts = file_base.split('_')
                    
                    if len(parts) >= 2:
                        utterance_id = parts[0]
                        phoneme = parts[1]
                        
                        formant_row = {
                            'DR': dr_folder,
                            'speaker': speaker_folder,
                            'Utterance': utterance_id,
                            'phoneme': phoneme,
                            'f1': formant_df['f1'].tolist(),
                            'f2': formant_df['f2'].tolist(),
                            'f3': formant_df['f3'].tolist(),
                            'time': formant_df['time'].tolist(),
                            'FilePath': file_path
                        }
                        
                        all_formants.append(formant_row)
                
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    
    if all_formants:
        formants_df = pd.DataFrame(all_formants)
        formants_df['Category'] = formants_df['phoneme'].map(phoneme_category_map)
        formants_df['speaker_phoneme'] = formants_df['speaker'] + '_' + formants_df['phoneme']
        return formants_df
    else:
        return pd.DataFrame()

def compute_mean_formant(formant_series):
    """Compute mean of formant values."""
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
    """Extract mean values for each center frequency."""
    neurogram = row['Original']
    if isinstance(neurogram, np.ndarray) and neurogram.ndim == 2:
        return pd.Series({f'CF{i+1}_Mean': np.mean(neurogram[:, i]) for i in range(neurogram.shape[1])})
    return pd.Series({f'CF{i+1}_Mean': np.nan for i in range(6)})

def improved_acoustic_distance(x, y):
    """Compute improved acoustic distance with mel scale transformation."""
    epsilon = 1e-10
    
    def freq_to_mel(f):
        return 2595 * np.log10(1 + f/700)
    
    x = np.atleast_1d(x) + epsilon
    y = np.atleast_1d(y) + epsilon
    
    x_mel = freq_to_mel(x)
    y_mel = freq_to_mel(y)
    
    distances = np.abs(x_mel - y_mel) / np.maximum(x_mel, y_mel)
    
    return np.mean(distances)

def compute_formant_cf_distances_by_perturbation(df):
    """Compute distances between formants and CFs, grouped by perturbation type."""
    results = []
    
    # Determine which category column to use
    category_col = 'Category_x' if 'Category_x' in df.columns else 'Category'
    
    # Get unique categories and perturbation types
    categories = df[category_col].unique()
    perturbation_types = df['PerturbationType'].unique()
    
    print(f"Found {len(categories)} categories and {len(perturbation_types)} perturbation types")
    print(f"Perturbation types: {', '.join(perturbation_types)}")
    
    # Process each category × perturbation type combination
    for category in tqdm(categories, desc="Processing categories"):
        for pert_type in perturbation_types:
            # Filter for this category and perturbation type
            filtered_df = df[(df[category_col] == category) & (df['PerturbationType'] == pert_type)]
            
            # Skip if not enough data
            if len(filtered_df) < 2:
                print(f"Skipping {category}-{pert_type} due to insufficient data (found {len(filtered_df)} samples)")
                continue
            
            # Process each formant
            for formant_name in ['f1', 'f2', 'f3']:
                formant_column = formant_name + '_mean'
                
                if formant_column not in filtered_df.columns:
                    continue
                
                # Get formant data and filter out NaNs
                formant_data = filtered_df[formant_column].values
                valid_formant_mask = ~np.isnan(formant_data)
                
                # Skip if no valid formant data
                if np.sum(valid_formant_mask) <= 1:
                    print(f"Skipping {category}-{pert_type}-{formant_name} due to insufficient valid data")
                    continue
                    
                valid_formant_data = formant_data[valid_formant_mask]
                
                # Compute distance matrix for formant
                formant_matrix = valid_formant_data.reshape(-1, 1)
                try:
                    formant_dist_matrix = cdist(formant_matrix, formant_matrix, metric=improved_acoustic_distance)
                    
                    # Normalize distance matrix
                    max_dist = np.nanmax(formant_dist_matrix)
                    if np.isfinite(max_dist) and max_dist > 0:
                        formant_dist_matrix /= max_dist
                    
                    # Prepare uniform weights
                    p = ot.unif(len(formant_matrix))
                    
                    # Process each CF
                    for cf_num in range(1, 7):
                        cf_column = f'CF{cf_num}_Mean'
                        
                        if cf_column not in filtered_df.columns:
                            continue
                            
                        cf_data = filtered_df[cf_column].iloc[np.where(valid_formant_mask)[0]].values
                        
                        # Skip if no valid CF data
                        if len(cf_data) <= 1:
                            continue
                        
                        # Compute distance matrix for CF
                        cf_matrix = cf_data.reshape(-1, 1)
                        cf_dist_matrix = cdist(cf_matrix, cf_matrix, metric=improved_acoustic_distance)
                        
                        # Normalize
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
                                'CF_Freq': TARGET_FREQUENCIES[cf_num-1],
                                'GW_Distance': round(gw_dist, 3),
                                'NumSamples': len(valid_formant_data),
                                'PerturbationType': pert_type
                            })
                        except Exception as e:
                            print(f"Error computing GW distance for {category}-{pert_type}-{formant_name}-CF{cf_num}: {e}")
                except Exception as e:
                    print(f"Error with distance matrix for {category}-{pert_type}-{formant_name}: {e}")
    
    return pd.DataFrame(results)

def create_visualizations(results_df, output_dir):
    """Create visualizations for the analysis results."""
    os.makedirs(output_dir, exist_ok=True)
    
    # Get unique perturbation types
    pert_types = results_df['PerturbationType'].unique()
    print(f"Creating visualizations for {len(pert_types)} perturbation types: {', '.join(pert_types)}")
    
    # 1. Overall comparison across perturbation types
    plt.figure(figsize=(15, 10))
    sns.boxplot(x='PerturbationType', y='GW_Distance', hue='Formant', data=results_df)
    plt.title('GW Distances by Perturbation Type and Formant')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'perturbation_comparison_overall.png'), dpi=300)
    
    # 2. Heatmaps for each perturbation type
    for pert_type in pert_types:
        pert_data = results_df[results_df['PerturbationType'] == pert_type]
        
        # Skip if not enough data
        if len(pert_data) < 2:
            print(f"Skipping visualization for {pert_type} due to insufficient data")
            continue
        
        plt.figure(figsize=(15, 10))
        pivot_data = pert_data.pivot_table(
            index='Category',
            columns=['Formant', 'CF'],
            values='GW_Distance',
            aggfunc='mean'
        )
        
        sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
        plt.title(f'Mean GW Distances: {pert_type} Perturbation')
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'heatmap_{pert_type}.png'), dpi=300)
        
        # 3. Separate heatmaps for each formant within this perturbation type
        for formant in ['F1', 'F2', 'F3']:
            formant_data = pert_data[pert_data['Formant'] == formant]
            
            # Skip if not enough data
            if len(formant_data) < 2:
                print(f"Skipping visualization for {pert_type}-{formant} due to insufficient data")
                continue
                
            plt.figure(figsize=(10, 8))
            pivot_data = formant_data.pivot_table(
                index='Category',
                columns='CF',
                values='GW_Distance',
                aggfunc='mean'
            )
            
            sns.heatmap(pivot_data, annot=True, cmap='YlGnBu', fmt='.3f')
            plt.title(f'Mean GW Distances: {formant} to CFs ({pert_type} Perturbation)')
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, f'{formant}_cf_heatmap_{pert_type}.png'), dpi=300)

def main_perturbation_analysis():
    """Main function for perturbation-based analysis."""
    # Define file paths
    test_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/TEST/'
    neurogram_base_path = test_dir
    formants_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Formants/Phonemes/TEST/'
    perturbation_json_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/perturbation_types.json'
    output_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_F_vs_Neuro_ANSD_Results_Perturbation/'
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Step 1: Get TEST speakers
    print("Identifying TEST speakers...")
    test_speakers = get_test_speakers(test_dir)
    print(f"Found {len(test_speakers)} TEST speakers: {', '.join(sorted(test_speakers))}")
    
    # Step 2: Load perturbation types for TEST files
    print("Loading perturbation types for TEST files...")
    test_pert_types = load_perturbation_types_for_test(perturbation_json_path, test_speakers)
    print(f"Loaded {len(test_pert_types)} perturbation type entries for TEST files")
    
    if test_pert_types:
        # Show distribution of perturbation types
        pert_counter = Counter(test_pert_types.values())
        print("\nPerturbation type distribution for TEST files:")
        for pert_type, count in pert_counter.items():
            print(f"  {pert_type}: {count} entries ({count/len(test_pert_types)*100:.2f}%)")
    
    # Step 3: Load neurogram data with perturbation info
    print("\nLoading neurogram data with perturbation info...")
    df_neurograms = read_neurograms_with_perturbation(neurogram_base_path, test_pert_types)
    print(f"Loaded {len(df_neurograms)} neurograms")
    
    # Check perturbation types that were found
    if 'PerturbationType' in df_neurograms.columns:
        pert_counts = df_neurograms['PerturbationType'].value_counts()
        print("\nPerturbation type distribution in loaded neurograms:")
        for pert_type, count in pert_counts.items():
            print(f"  {pert_type}: {count} neurograms")
    
    # Step 4: Load formant data
    print("\nLoading formant data...")
    df_formants = read_formants_from_directory(formants_base_path)
    print(f"Loaded {len(df_formants)} formant measurements")
    
    # Step 5: Merge dataframes
    print("\nMerging neurogram and formant data...")
    
    # First try merging on speaker and phoneme
    merged_df = pd.merge(
        df_neurograms, 
        df_formants, 
        left_on=['Speaker', 'Phoneme'], 
        right_on=['speaker', 'phoneme'], 
        how='inner'
    )
    
    # If the merge fails, try alternative approach
    if len(merged_df) == 0:
        print("WARNING: No matches found in the merge. Trying alternative merge approach...")
        merged_df = pd.merge(
            df_neurograms,
            df_formants,
            on='speaker_phoneme',
            how='inner'
        )
    
    print(f"Merged dataframe has {len(merged_df)} rows")
    
    # Check if perturbation types survived the merge
    if 'PerturbationType' in merged_df.columns:
        pert_counts = merged_df['PerturbationType'].value_counts()
        print("\nPerturbation type distribution after merge:")
        for pert_type, count in pert_counts.items():
            print(f"  {pert_type}: {count} entries")
    
    # Step 6: Process the merged data
    if len(merged_df) > 0:
        # Compute mean formant values
        print("\nComputing mean formant values...")
        merged_df['f1_mean'] = compute_mean_formant(merged_df['f1'])
        merged_df['f2_mean'] = compute_mean_formant(merged_df['f2'])
        merged_df['f3_mean'] = compute_mean_formant(merged_df['f3'])
        
        # Extract neurogram values
        print("Extracting neurogram CF values...")
        cf_means = merged_df.apply(extract_neurogram_values, axis=1)
        merged_df = pd.concat([merged_df, cf_means], axis=1)
        
        # Determine category column
        category_col = 'Category_x' if 'Category_x' in merged_df.columns else 'Category'
        
        # Print data distribution
        if 'PerturbationType' in merged_df.columns:
            print("\nData distribution by category and perturbation type:")
            try:
                crosstab = pd.crosstab(merged_df[category_col], merged_df['PerturbationType'])
                print(crosstab)
            except:
                print("Error creating crosstab")
        
        # Step 7: Compute distances
        print("\nComputing distances between formants and center frequencies by perturbation type...")
        distance_results = compute_formant_cf_distances_by_perturbation(merged_df)
        
        if not distance_results.empty:
            # Check the distribution of perturbation types in results
            if 'PerturbationType' in distance_results.columns:
                pert_counts = distance_results['PerturbationType'].value_counts()
                print("\nPerturbation type distribution in results:")
                for pert_type, count in pert_counts.items():
                    print(f"  {pert_type}: {count} results")
            
            # Step 8: Save results
            print("\nSaving results...")
            merged_df.to_pickle(os.path.join(output_dir, 'merged_data_with_perturbation.pkl'))
            distance_results.to_pickle(os.path.join(output_dir, 'formant_cf_distances_by_perturbation.pkl'))
            distance_results.to_csv(os.path.join(output_dir, 'formant_cf_distances_by_perturbation.csv'), index=False)
            
            # Step 9: Create visualizations
            print("\nCreating visualizations...")
            create_visualizations(distance_results, output_dir)
            
            print("\nAnalysis complete!")
            return merged_df, distance_results
        else:
            print("No distance results were generated.")
            return merged_df, None
    else:
        print("ERROR: Failed to merge neurogram and formant data.")
        return None, None
# %%  
if __name__ == "__main__":
    merged_df, distance_results = main_perturbation_analysis()
# %%    