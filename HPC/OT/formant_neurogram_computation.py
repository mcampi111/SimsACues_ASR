# %%
import os
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.spatial.distance import cdist
import ot
import json
import ast
from tqdm import tqdm
from collections import Counter
import multiprocessing as mp
from functools import partial
import time
import gc

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

def load_perturbation_types_for_test(json_path, test_speakers, test_dir):
    """
    Load perturbation type information from JSON file,
    filtering for entries corresponding to TEST speakers.
    """
    try:
        with open(json_path, 'r') as f:
            all_pert_types = json.load(f)
        
        # This will hold perturbation types for files in TEST directory
        filtered_pert_types = {}
        
        # For each entry in the JSON file
        for filename, pert_type in all_pert_types.items():
            # Try to extract speaker information from the filename
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
                        check_path = f"{test_dir}/{dr_name}/{speaker}/{filename}"
                        
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

def process_combination(args, df, category_col, processed_combinations, target_frequencies):
    """Process a single category-perturbation-formant-CF combination."""
    category, pert_type, formant_name, cf_num = args
    
    # Skip if already processed
    formant_upper = formant_name.upper()
    cf_name = f'CF{cf_num}'
    if (category, formant_upper, cf_name, pert_type) in processed_combinations:
        return None
    
    # Filter for this category and perturbation type
    filtered_df = df[(df[category_col] == category) & (df['PerturbationType'] == pert_type)]
    
    # Skip if not enough data
    if len(filtered_df) < 2:
        return None
    
    formant_column = formant_name + '_mean'
    if formant_column not in filtered_df.columns:
        return None
    
    # Get formant data and filter out NaNs
    formant_data = filtered_df[formant_column].values
    valid_formant_mask = ~np.isnan(formant_data)
    
    # Skip if no valid formant data
    if np.sum(valid_formant_mask) <= 1:
        return None
        
    valid_formant_data = formant_data[valid_formant_mask]
    
    # Limit the size of matrices for memory efficiency
    # If there are too many samples, take a random subset
    max_samples = 1000
    if len(valid_formant_data) > max_samples:
        np.random.seed(42)  # For reproducibility
        indices = np.random.choice(len(valid_formant_data), max_samples, replace=False)
        valid_formant_data = valid_formant_data[indices]
    
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
        
        # Process CF
        cf_column = f'CF{cf_num}_Mean'
        if cf_column not in filtered_df.columns:
            return None
            
        cf_data = filtered_df[cf_column].iloc[np.where(valid_formant_mask)[0]].values
        
        # Skip if no valid CF data
        if len(cf_data) <= 1:
            return None
        
        # Apply the same subset if we limited the formant data
        if len(valid_formant_data) != len(formant_data[valid_formant_mask]):
            cf_data = cf_data[indices]
        
        # Compute distance matrix for CF
        cf_matrix = cf_data.reshape(-1, 1)
        cf_dist_matrix = cdist(cf_matrix, cf_matrix, metric=improved_acoustic_distance)
        
        # Normalize
        max_cf_dist = np.nanmax(cf_dist_matrix)
        if np.isfinite(max_cf_dist) and max_cf_dist > 0:
            cf_dist_matrix /= max_cf_dist
        
        # Prepare uniform weights
        q = ot.unif(len(cf_matrix))
        
        # Compute Gromov-Wasserstein distance with reduced iterations for memory efficiency
        try:
            gw_dist = ot.gromov.gromov_wasserstein2(
                formant_dist_matrix, cf_dist_matrix, p, q, 
                loss_fun='square_loss', 
                max_iter=20       # Limited inner loop iterations
            )
            
            # Return result
            return {
                'Category': category,
                'Formant': formant_upper,
                'CF': cf_name,
                'CF_Freq': target_frequencies[cf_num-1],
                'GW_Distance': round(gw_dist, 3),
                'NumSamples': len(valid_formant_data),
                'PerturbationType': pert_type
            }
        except Exception as e:
            print(f"Error computing GW distance for {category}-{pert_type}-{formant_name}-CF{cf_num}: {e}")
            return None
    except Exception as e:
        print(f"Error with distance matrix for {category}-{pert_type}-{formant_name}: {e}")
        return None

def compute_formant_cf_distances_parallel(df, output_dir=None, checkpoint_interval=10, n_processes=None):
    """Compute distances between formants and CFs using parallel processing."""
    results = []
    checkpoint_file = os.path.join(output_dir, "distance_results_checkpoint.pkl") if output_dir else None
    
    # Load existing results if available
    if checkpoint_file and os.path.exists(checkpoint_file):
        try:
            checkpoint_df = pd.read_pickle(checkpoint_file)
            results = checkpoint_df.to_dict('records')
            print(f"Loaded {len(results)} existing results from checkpoint")
        except Exception as e:
            print(f"Could not load checkpoint: {e}")
    
    # Determine which category column to use
    category_col = 'Category_x' if 'Category_x' in df.columns else 'Category'
    
    # Get unique categories and perturbation types
    categories = df[category_col].unique()
    perturbation_types = df['PerturbationType'].unique()
    
    print(f"Found {len(categories)} categories and {len(perturbation_types)} perturbation types")
    print(f"Perturbation types: {', '.join(perturbation_types)}")
    
    # Track which combinations we've already processed
    processed_combinations = set()
    if results:
        for r in results:
            processed_combinations.add((r['Category'], r['Formant'], r['CF'], r['PerturbationType']))
    
    # Generate all combinations to process
    all_combinations = []
    for category in categories:
        for pert_type in perturbation_types:
            for formant_name in ['f1', 'f2', 'f3']:
                for cf_num in range(1, 7):
                    all_combinations.append((category, pert_type, formant_name, cf_num))
    
    print(f"Total combinations to process: {len(all_combinations)}")
    print(f"Already processed: {len(processed_combinations)}")
    
    # Determine number of processes to use
    if n_processes is None:
        n_processes = mp.cpu_count() // 2  # Use half the cores to avoid memory issues
    
    # Add batch processing to control memory usage
    batch_size = 20  # Process 20 combinations at a time
    all_batches = [all_combinations[i:i + batch_size] for i in range(0, len(all_combinations), batch_size)]
    print(f"Processing in {len(all_batches)} batches of size {batch_size}")
    
    # Create a pool of workers
    with mp.Pool(processes=n_processes) as pool:
        # Create partial function with fixed arguments
        process_func = partial(
            process_combination, 
            df=df, 
            category_col=category_col, 
            processed_combinations=processed_combinations,
            target_frequencies=TARGET_FREQUENCIES
        )
        
        # Process combinations in batches to control memory usage
        total_processed = 0
        for batch_idx, batch in enumerate(all_batches):
            print(f"\nProcessing batch {batch_idx+1}/{len(all_batches)}")
            batch_results = []
            
            # Process current batch
            for result in tqdm(pool.imap_unordered(process_func, batch), 
                              total=len(batch),
                              desc=f"Batch {batch_idx+1}"):
                if result is not None:
                    batch_results.append(result)
            
            # Add batch results to overall results
            results.extend(batch_results)
            total_processed += len(batch_results)
            
            # Save checkpoint after each batch
            if checkpoint_file:
                checkpoint_df = pd.DataFrame(results)
                checkpoint_df.to_pickle(checkpoint_file)
                print(f"Checkpoint saved: Total results = {len(results)}")
            
            # Force garbage collection
            del batch_results
            gc.collect()
            
            # Periodically save to CSV as well
            if total_processed % 100 == 0 or batch_idx == len(all_batches) - 1:
                csv_file = os.path.join(output_dir, "distance_results_partial.csv")
                pd.DataFrame(results).to_csv(csv_file, index=False)
                print(f"Saved intermediate CSV results: {len(results)} entries")
    
    # Save final results
    if checkpoint_file:
        checkpoint_df = pd.DataFrame(results)
        checkpoint_df.to_pickle(checkpoint_file)
        print(f"Final results saved: {len(results)} total combinations")
    
    return pd.DataFrame(results)

def main_perturbation_analysis():
    """Main function for perturbation-based analysis."""
    # Define file paths for HPC environment
    base_scratch = '/pasteur/helix/scratch/mcampi'
    
    test_dir = f'{base_scratch}/SELECT_Neurograms_ANSD/TEST/'
    neurogram_base_path = test_dir
    formants_base_path = f'{base_scratch}/SELECT_Formants/Phonemes/TEST/'
    perturbation_json_path = f'{base_scratch}/OT/perturbation_types.json'
    output_dir = f'{base_scratch}/OT/results/ANSD_OT_Results/'
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Record start time
    start_time = time.time()
    
    # Check for existing merged data to potentially skip data loading steps
    merged_data_file = os.path.join(output_dir, 'merged_data.pkl')
    if os.path.exists(merged_data_file):
        try:
            print(f"Found existing merged data at {merged_data_file}")
            print("Loading merged data to skip preprocessing steps...")
            merged_df = pd.read_pickle(merged_data_file)
            
            # Ensure required columns exist
            if ('PerturbationType' in merged_df.columns and
                'f1_mean' in merged_df.columns and
                'f2_mean' in merged_df.columns and
                'f3_mean' in merged_df.columns and
                'CF1_Mean' in merged_df.columns):
                
                print(f"Successfully loaded merged data with {len(merged_df)} rows")
                print("Skipping preprocessing steps and proceeding directly to distance computation...")
                
                # Determine category column
                category_col = 'Category_x' if 'Category_x' in merged_df.columns else 'Category'
                
                # Print data distribution
                print("\nData distribution by category and perturbation type:")
                try:
                    crosstab = pd.crosstab(merged_df[category_col], merged_df['PerturbationType'])
                    print(crosstab)
                except:
                    print("Error creating crosstab")
                
                # Skip to Step 7
                print("\nComputing distances between formants and center frequencies by perturbation type...")
                n_processes = mp.cpu_count() // 2  # Use half the cores to avoid memory issues
                print(f"Using {n_processes} CPU cores for parallel processing")
                
                distance_results = compute_formant_cf_distances_parallel(
                    merged_df, 
                    output_dir=output_dir, 
                    checkpoint_interval=10,
                    n_processes=n_processes
                )
                
                if not distance_results.empty:
                    # Check the distribution of perturbation types in results
                    if 'PerturbationType' in distance_results.columns:
                        pert_counts = distance_results['PerturbationType'].value_counts()
                        print("\nPerturbation type distribution in results:")
                        for pert_type, count in pert_counts.items():
                            print(f"  {pert_type}: {count} results")
                    
                    # Save results
                    print("\nSaving results...")
                    distance_results.to_pickle(os.path.join(output_dir, 'formant_cf_distances_by_perturbation.pkl'))
                    distance_results.to_csv(os.path.join(output_dir, 'formant_cf_distances_by_perturbation.csv'), index=False)
                    
                    # Record end time and calculate duration
                    end_time = time.time()
                    duration = end_time - start_time
                    hours, remainder = divmod(duration, 3600)
                    minutes, seconds = divmod(remainder, 60)
                    
                    print(f"\nAnalysis complete! Total runtime: {int(hours)}h {int(minutes)}m {int(seconds)}s")
                    
                    # Save runtime information
                    with open(os.path.join(output_dir, 'runtime_info.txt'), 'w') as f:
                        f.write(f"Analysis started: {time.ctime(start_time)}\n")
                        f.write(f"Analysis completed: {time.ctime(end_time)}\n")
                        f.write(f"Total runtime: {int(hours)}h {int(minutes)}m {int(seconds)}s\n")
                        f.write(f"Processed {len(merged_df)} merged data points\n")
                        f.write(f"Generated {len(distance_results)} distance results\n")
                    
                    return merged_df, distance_results
                else:
                    print("No distance results were generated.")
                    return merged_df, None
        except Exception as e:
            print(f"Error loading existing merged data: {e}")
            print("Proceeding with full data processing pipeline...")
    
    # Step 1: Get TEST speakers
    print("Identifying TEST speakers...")
    test_speakers = get_test_speakers(test_dir)
    print(f"Found {len(test_speakers)} TEST speakers: {', '.join(sorted(test_speakers))}")
    
    # Step 2: Load perturbation types for TEST files
    print("Loading perturbation types for TEST files...")
    test_pert_types = load_perturbation_types_for_test(perturbation_json_path, test_speakers, test_dir)
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
    
    # Free up memory
    del df_neurograms
    del df_formants
    gc.collect()
    
    # Step 6: Process the merged data
    if len(merged_df) > 0:
        # Save merged data for later inspection
        print(f"\nSaving merged data to {merged_data_file}")
        merged_df.to_pickle(merged_data_file)
        
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
        
        # Step 7: Compute distances with parallel processing
        print("\nComputing distances between formants and center frequencies by perturbation type...")
        # Use half the available cores for HPC to avoid memory issues
        n_processes = mp.cpu_count() // 2
        print(f"Using {n_processes} CPU cores for parallel processing")
        
        distance_results = compute_formant_cf_distances_parallel(
            merged_df, 
            output_dir=output_dir, 
            checkpoint_interval=10,
            n_processes=n_processes
        )
        
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
            
            # Record end time and calculate duration
            end_time = time.time()
            duration = end_time - start_time
            hours, remainder = divmod(duration, 3600)
            minutes, seconds = divmod(remainder, 60)
            
            print(f"\nAnalysis complete! Total runtime: {int(hours)}h {int(minutes)}m {int(seconds)}s")
            
            # Save runtime information
            with open(os.path.join(output_dir, 'runtime_info.txt'), 'w') as f:
                f.write(f"Analysis started: {time.ctime(start_time)}\n")
                f.write(f"Analysis completed: {time.ctime(end_time)}\n")
                f.write(f"Total runtime: {int(hours)}h {int(minutes)}m {int(seconds)}s\n")
                f.write(f"Processed {len(merged_df)} merged data points\n")
                f.write(f"Generated {len(distance_results)} distance results\n")
            
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
