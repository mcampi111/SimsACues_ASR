# %%
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Statistical Analysis for ABR comparisons between normal and ANSD conditions.
Analyzes both point estimates (amplitude, latency) and waveform shapes (MMD).
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.io import loadmat
from scipy.stats import mannwhitneyu
from sklearn.metrics.pairwise import rbf_kernel
from statsmodels.stats.multitest import multipletests
import warnings
# %%
# Suppress specific warnings
warnings.filterwarnings("ignore", category=RuntimeWarning, message="invalid value encountered in divide")
warnings.filterwarnings("ignore", category=RuntimeWarning, message="Mean of empty slice")

def compute_mmd(x, y, gamma=None):
    """
    Compute Maximum Mean Discrepancy between two samples.
    
    Parameters:
    -----------
    x : numpy.ndarray
        First sample, shape (n_samples_x, n_features)
    y : numpy.ndarray
        Second sample, shape (n_samples_y, n_features)
    gamma : float, optional
        RBF kernel bandwidth parameter
        
    Returns:
    --------
    float
        MMD squared value
    """
    # Ensure input arrays are 2D
    if x.ndim == 1:
        x = x.reshape(-1, 1)
    if y.ndim == 1:
        y = y.reshape(-1, 1)
    
    # Compute kernels
    x_kernel = rbf_kernel(x, x, gamma)
    y_kernel = rbf_kernel(y, y, gamma)
    xy_kernel = rbf_kernel(x, y, gamma)
    
    # Compute MMD squared
    mmd_squared = x_kernel.mean() + y_kernel.mean() - 2 * xy_kernel.mean()
    
    return mmd_squared

def permutation_test_mmd(x, y, n_permutations=1000, gamma=None):
    """
    Run a permutation test to assess statistical significance of MMD.
    
    Parameters:
    -----------
    x : numpy.ndarray
        First sample, shape (n_samples_x, n_features)
    y : numpy.ndarray
        Second sample, shape (n_samples_y, n_features)
    n_permutations : int
        Number of permutations to run
    gamma : float, optional
        RBF kernel bandwidth parameter
        
    Returns:
    --------
    float
        p-value from permutation test
    """
    # Compute observed MMD
    observed_mmd = compute_mmd(x, y, gamma)
    
    # Combine samples
    combined = np.vstack([x, y])
    n_x = x.shape[0]
    n_combined = combined.shape[0]
    
    # Run permutation test
    count = 0
    for i in range(n_permutations):
        # Shuffle indices
        indices = np.random.permutation(n_combined)
        # Split into two groups
        perm_x = combined[indices[:n_x]]
        perm_y = combined[indices[n_x:]]
        # Compute MMD for permuted groups
        perm_mmd = compute_mmd(perm_x, perm_y, gamma)
        # Count permutations with MMD >= observed
        if perm_mmd >= observed_mmd:
            count += 1
    
    # Compute p-value
    p_value = count / n_permutations
    
    return p_value, observed_mmd

def load_normal_abr_data(normal_abr_dir):
    """
    Load normal ABR data from MAT files.
    
    Parameters:
    -----------
    normal_abr_dir : str
        Directory containing normal ABR data
        
    Returns:
    --------
    dict
        Dictionary with category as key and ABR results as value
    """
    normal_results = {}
    
    # Try loading combined file first
    normal_mat_file = os.path.join(normal_abr_dir, 'complex_abr_all_categories.mat')
    if os.path.exists(normal_mat_file):
        try:
            normal_data = loadmat(normal_mat_file)
            
            # Check if there's a category_results key
            if 'category_results' in normal_data:
                for category, data in normal_data['category_results'].items():
                    if isinstance(data, dict):
                        normal_results[category] = data
            else:
                # Try to directly extract each category
                for key in normal_data.keys():
                    if not key.startswith('__'):
                        cat_data = normal_data[key]
                        if isinstance(cat_data, dict):
                            normal_results[key] = cat_data
            
            print(f"Loaded {len(normal_results)} categories from combined normal ABR file")
        except Exception as e:
            print(f"Error loading combined normal ABR file: {e}")
    
    # If still empty, try loading individual category MAT files
    if not normal_results:
        print("Trying to load individual category MAT files...")
        # Define phoneme categories to look for
        phoneme_categories = [
            'Vowel', 'Stop', 'Fricative', 'Nasal', 'Liquid', 'Glide', 
            'Affricate', 'Flap', 'Glottal Stop', 'Epenthetic', 
            'Silence', 'Syllabic Consonant'
        ]
        
        for category in phoneme_categories:
            cat_file = os.path.join(normal_abr_dir, f'complex_abr_{category}.mat')
            if os.path.exists(cat_file):
                try:
                    cat_data = loadmat(cat_file)
                    # Convert relevant keys to our format
                    if 'mean_abr' in cat_data and 'std_abr' in cat_data and 'time' in cat_data:
                        normal_results[category] = {
                            'mean_abr': cat_data['mean_abr'],
                            'std_abr': cat_data['std_abr'],
                            'time': cat_data['time'],
                            'n_samples': cat_data.get('n_samples', 0)
                        }
                        print(f"Loaded category {category} from individual file")
                except Exception as e:
                    print(f"Error loading {cat_file}: {e}")
    
    # Print summary
    if normal_results:
        print(f"Loaded {len(normal_results)} normal ABR categories")
    else:
        print("WARNING: No normal results were loaded!")
    
    return normal_results

def load_perturbed_abr_data(ansd_dir):
    """
    Load perturbed (ANSD) ABR data from the directory structure.
    
    Parameters:
    -----------
    ansd_dir : str
        Directory containing perturbed ABR data
        
    Returns:
    --------
    dict
        Dictionary with perturbation type as key and dict of category results as value
    """
    perturbation_results = {}
    
    # Look for perturbation subdirectories
    perturbation_dirs = [d for d in os.listdir(ansd_dir) 
                        if os.path.isdir(os.path.join(ansd_dir, d)) and d.startswith('perturbation_')]
    
    if not perturbation_dirs:
        print("No perturbation directories found, checking for direct MAT files")
        # Try to load a combined file
        combined_file = os.path.join(ansd_dir, 'complex_abr_all_categories.mat')
        if os.path.exists(combined_file):
            try:
                data = loadmat(combined_file)
                if 'category_results' in data:
                    perturbation_results['unknown'] = {}
                    for category, cat_data in data['category_results'].items():
                        if isinstance(cat_data, dict):
                            perturbation_results['unknown'][category] = cat_data
                else:
                    # Try to extract categories directly
                    perturbation_results['unknown'] = {}
                    for key in data.keys():
                        if not key.startswith('__'):
                            cat_data = data[key]
                            if isinstance(cat_data, dict):
                                perturbation_results['unknown'][key] = cat_data
            except Exception as e:
                print(f"Error loading combined ANSD file: {e}")
    else:
        # Process each perturbation directory
        for pert_dir in perturbation_dirs:
            # Extract perturbation type from directory name
            pert_type = pert_dir.replace('perturbation_', '')
            pert_path = os.path.join(ansd_dir, pert_dir)
            
            # First try to load the combined file WITH the perturbation suffix
            combined_file_with_suffix = os.path.join(pert_path, f'complex_abr_all_categories_{pert_type}.mat')
            
            if os.path.exists(combined_file_with_suffix):
                try:
                    print(f"Loading combined file: {combined_file_with_suffix}")
                    data = loadmat(combined_file_with_suffix)
                    perturbation_results[pert_type] = {}
                    
                    # Try to extract categories from MAT file
                    categories_found = False
                    for key in data.keys():
                        if not key.startswith('__'):
                            if isinstance(data[key], dict) and 'mean_abr' in data[key]:
                                category = key
                                cat_data = data[key]
                                perturbation_results[pert_type][category] = cat_data
                                categories_found = True
                                print(f"  Extracted category {category} from combined file")
                    
                    if categories_found:
                        print(f"Loaded {len(perturbation_results[pert_type])} categories for perturbation: {pert_type}")
                        continue  # Skip to next perturbation type
                except Exception as e:
                    print(f"Error loading combined file with suffix: {e}")
            
            # If we reach here, try original filename
            combined_file = os.path.join(pert_path, 'complex_abr_all_categories.mat')
            if os.path.exists(combined_file):
                try:
                    data = loadmat(combined_file)
                    perturbation_results[pert_type] = {}
                    
                    if 'category_results' in data:
                        for category, cat_data in data['category_results'].items():
                            if isinstance(cat_data, dict):
                                perturbation_results[pert_type][category] = cat_data
                    else:
                        # Try to extract categories directly
                        for key in data.keys():
                            if not key.startswith('__'):
                                cat_data = data[key]
                                if isinstance(cat_data, dict):
                                    perturbation_results[pert_type][key] = cat_data
                    
                    print(f"Loaded {len(perturbation_results[pert_type])} categories for perturbation: {pert_type}")
                except Exception as e:
                    print(f"Error loading combined file: {e}")
            
            # If combined files didn't work, try individual category files with suffix
            if pert_type not in perturbation_results or not perturbation_results[pert_type]:
                print(f"Trying individual category files for {pert_type}")
                perturbation_results[pert_type] = {}
                
                # Define phoneme categories to look for
                phoneme_categories = [
                    'Vowel', 'Stop', 'Fricative', 'Nasal', 'Liquid', 'Glide', 
                    'Affricate', 'Flap', 'Glottal Stop', 'Epenthetic', 
                    'Silence', 'Syllabic Consonant'
                ]
                
                for category in phoneme_categories:
                    # Look for a file with the perturbation suffix
                    cat_file_with_suffix = os.path.join(pert_path, f'complex_abr_{category}_{pert_type}.mat')
                    
                    if os.path.exists(cat_file_with_suffix):
                        try:
                            cat_data = loadmat(cat_file_with_suffix)
                            # Convert relevant keys to our format
                            if 'mean_abr' in cat_data and 'std_abr' in cat_data and 'time' in cat_data:
                                perturbation_results[pert_type][category] = {
                                    'mean_abr': cat_data['mean_abr'],
                                    'std_abr': cat_data['std_abr'],
                                    'time': cat_data['time'],
                                    'n_samples': cat_data.get('n_samples', 0)
                                }
                                print(f"  Loaded category {category} for {pert_type} from suffixed file")
                            else:
                                print(f"  Warning: Required fields not found in {cat_file_with_suffix}")
                        except Exception as e:
                            print(f"  Error loading {cat_file_with_suffix}: {e}")
                    else:
                        # Try the regular filename as a fallback
                        cat_file = os.path.join(pert_path, f'complex_abr_{category}.mat')
                        if os.path.exists(cat_file):
                            try:
                                cat_data = loadmat(cat_file)
                                # Convert relevant keys to our format
                                if 'mean_abr' in cat_data and 'std_abr' in cat_data and 'time' in cat_data:
                                    perturbation_results[pert_type][category] = {
                                        'mean_abr': cat_data['mean_abr'],
                                        'std_abr': cat_data['std_abr'],
                                        'time': cat_data['time'],
                                        'n_samples': cat_data.get('n_samples', 0)
                                    }
                                    print(f"  Loaded category {category} for {pert_type}")
                            except Exception as e:
                                print(f"  Error loading {cat_file}: {e}")
    
    # Count the total number of categories across all perturbations
    total_categories = sum(len(cats) for cats in perturbation_results.values())
    print(f"Loaded a total of {total_categories} category results across {len(perturbation_results)} perturbation types")
    
    return perturbation_results

def run_point_estimate_tests(normal_results, perturbation_results):
    """
    Run Mann-Whitney U tests for amplitude and latency differences.
    
    Parameters:
    -----------
    normal_results : dict
        Dictionary with category as key and ABR results as value for normal ABRs
    perturbation_results : dict
        Dictionary with perturbation type as key and dict of category results as value
        
    Returns:
    --------
    pd.DataFrame
        DataFrame with test results
    """
    results = []
    
    # For each category and perturbation type
    for category in normal_results.keys():
        if category not in normal_results:
            continue
            
        normal_data = normal_results[category]
        # Get normal peak information
        normal_time = normal_data['time'] * 1000  # Convert to ms
        normal_valid_time = (normal_time >= 0) & (normal_time <= 20)
        normal_waveform = normal_data['mean_abr'][normal_valid_time] * (1.0/10000)  # Convert to μV
        normal_std = normal_data['std_abr'][normal_valid_time] * (1.0/10000)  # For effect size calculation
        
        # Find normal peak
        normal_peak_idx = np.argmax(normal_waveform)
        normal_peak_amplitude = normal_waveform[normal_peak_idx]
        normal_peak_latency = normal_time[normal_valid_time][normal_peak_idx]
        
        # Find Wave V in normal (typically around 6ms)
        wave_v_region = (normal_time[normal_valid_time] >= 5) & (normal_time[normal_valid_time] <= 7)
        if np.any(wave_v_region):
            normal_wave_v_idx = np.argmax(normal_waveform[wave_v_region]) + np.where(wave_v_region)[0][0]
            normal_wave_v_amplitude = normal_waveform[normal_wave_v_idx]
            normal_wave_v_latency = normal_time[normal_valid_time][normal_wave_v_idx]
        else:
            normal_wave_v_amplitude = None
            normal_wave_v_latency = None
        
        # Compare with each perturbation type
        for pert_type in perturbation_results.keys():
            if category not in perturbation_results[pert_type]:
                continue
                
            pert_data = perturbation_results[pert_type][category]
            pert_time = pert_data['time'] * 1000
            pert_valid_time = (pert_time >= 0) & (pert_time <= 20)
            pert_waveform = pert_data['mean_abr'][pert_valid_time] * (1.0/10000)
            
            # Find perturbation peak
            pert_peak_idx = np.argmax(pert_waveform)
            pert_peak_amplitude = pert_waveform[pert_peak_idx]
            pert_peak_latency = pert_time[pert_valid_time][pert_peak_idx]
            
            # Find Wave V in perturbed data
            ansd_wave_v_amplitude = None
            ansd_wave_v_latency = None
            
            if normal_wave_v_latency is not None:
                # Search in a window around where normal Wave V is found
                search_window = (pert_time[pert_valid_time] >= normal_wave_v_latency - 1) & (pert_time[pert_valid_time] <= normal_wave_v_latency + 1)
                if np.any(search_window):
                    ansd_wave_v_idx = np.argmax(pert_waveform[search_window]) + np.where(search_window)[0][0]
                    ansd_wave_v_amplitude = pert_waveform[ansd_wave_v_idx]
                    ansd_wave_v_latency = pert_time[pert_valid_time][ansd_wave_v_idx]
            
            # Calculate differences
            amplitude_diff = pert_peak_amplitude - normal_peak_amplitude
            latency_diff = pert_peak_latency - normal_peak_latency
            
            if normal_wave_v_amplitude is not None and ansd_wave_v_amplitude is not None:
                wave_v_amplitude_diff = ansd_wave_v_amplitude - normal_wave_v_amplitude
                wave_v_latency_diff = ansd_wave_v_latency - normal_wave_v_latency
            else:
                wave_v_amplitude_diff = None
                wave_v_latency_diff = None
            
            # Calculate standardized differences (effect size)
            if np.mean(normal_std) > 0:
                standardized_peak_diff = amplitude_diff / np.mean(normal_std)
            else:
                standardized_peak_diff = None
            
            # Store results
            results.append({
                'Category': category,
                'Perturbation': pert_type,
                'Normal_Peak_Amplitude': normal_peak_amplitude,
                'ANSD_Peak_Amplitude': pert_peak_amplitude,
                'Peak_Amplitude_Diff': amplitude_diff,
                'Standardized_Peak_Diff': standardized_peak_diff,
                'Normal_Peak_Latency': normal_peak_latency,
                'ANSD_Peak_Latency': pert_peak_latency,
                'Peak_Latency_Diff': latency_diff,
                'Normal_WaveV_Amplitude': normal_wave_v_amplitude,
                'ANSD_WaveV_Amplitude': ansd_wave_v_amplitude,
                'WaveV_Amplitude_Diff': wave_v_amplitude_diff,
                'Normal_WaveV_Latency': normal_wave_v_latency,
                'ANSD_WaveV_Latency': ansd_wave_v_latency,
                'WaveV_Latency_Diff': wave_v_latency_diff,
                'n_Normal': normal_data.get('n_samples', 0),
                'n_ANSD': pert_data.get('n_samples', 0)
            })
    
    return pd.DataFrame(results)

def run_mmd_tests(normal_results, perturbation_results, n_permutations=1000):
    """
    Run MMD tests with permutation testing and multiple test correction.
    
    Parameters:
    -----------
    normal_results : dict
        Dictionary with category as key and ABR results as value for normal ABRs
    perturbation_results : dict
        Dictionary with perturbation type as key and dict of category results as value
    n_permutations : int
        Number of permutations for each MMD test
        
    Returns:
    --------
    pd.DataFrame
        DataFrame with MMD test results
    """
    results = []
    p_values = []
    
    # For each category and perturbation type
    for category in normal_results.keys():
        if category not in normal_results:
            continue
            
        normal_data = normal_results[category]
        normal_time = normal_data['time'] * 1000  # Convert to ms
        normal_valid_time = (normal_time >= 0) & (normal_time <= 20)
        normal_waveform = normal_data['mean_abr'][normal_valid_time] * (1.0/10000)  # Convert to μV
        
        # Compare with each perturbation type
        for pert_type in perturbation_results.keys():
            if category not in perturbation_results[pert_type]:
                continue
                
            pert_data = perturbation_results[pert_type][category]
            pert_time = pert_data['time'] * 1000
            pert_valid_time = (pert_time >= 0) & (pert_time <= 20)
            pert_waveform = pert_data['mean_abr'][pert_valid_time] * (1.0/10000)
            
            # Interpolate to common time base if needed
            if len(normal_waveform) != len(pert_waveform):
                # Use the shorter of the two time arrays as reference
                min_len = min(len(normal_time[normal_valid_time]), len(pert_time[pert_valid_time]))
                if min_len < 5:  # Too short to be meaningful
                    continue
                    
                common_time = np.linspace(
                    max(normal_time[normal_valid_time][0], pert_time[pert_valid_time][0]),
                    min(normal_time[normal_valid_time][-1], pert_time[pert_valid_time][-1]),
                    1000
                )
                
                normal_interp = np.interp(common_time, normal_time[normal_valid_time], normal_waveform)
                pert_interp = np.interp(common_time, pert_time[pert_valid_time], pert_waveform)
            else:
                normal_interp = normal_waveform
                pert_interp = pert_waveform
            
            # Run MMD test
            try:
                p_value, mmd_value = permutation_test_mmd(
                    normal_interp.reshape(-1, 1),
                    pert_interp.reshape(-1, 1),
                    n_permutations=n_permutations
                )
                
                # Store results and p-values for multiple test correction
                results.append({
                    'Category': category,
                    'Perturbation': pert_type,
                    'MMD': mmd_value,
                    'MMD_p_value': p_value,
                    'n_Normal': normal_data.get('n_samples', 0),
                    'n_ANSD': pert_data.get('n_samples', 0)
                })
                p_values.append(p_value)
            except Exception as e:
                print(f"Error in MMD test for {category}, {pert_type}: {e}")
    
    # Create DataFrame from results
    results_df = pd.DataFrame(results)
    
    # Apply multiple test correction if we have results
    if p_values and len(p_values) > 1:
        try:
            reject, p_adjusted, _, _ = multipletests(p_values, method='fdr_bh')
            
            # Add adjusted p-values to results
            results_df['MMD_p_adjusted'] = p_adjusted
            results_df['MMD_significant'] = reject
        except Exception as e:
            print(f"Error in multiple test correction: {e}")
    
    return results_df

def plot_point_estimate_results(point_df, output_dir):
    """(continued from previous part)"""
    
    # Create plots directory
    plots_dir = os.path.join(output_dir, 'plots')
    os.makedirs(plots_dir, exist_ok=True)
    
    # Check if DataFrame is empty
    if point_df.empty:
        print("No point estimate data available for plotting")
        return
    
    # Define color palette for perturbation types
    colors = {
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # 1. Bar plot of peak amplitude differences by category and perturbation
    plt.figure(figsize=(14, 8))
    sns.barplot(
        data=point_df, 
        x='Category', 
        y='Peak_Amplitude_Diff', 
        hue='Perturbation',
        palette=colors
    )
    plt.title('Peak Amplitude Difference (ANSD - Normal) by Category and Perturbation Type')
    plt.xlabel('Phoneme Category')
    plt.ylabel('Amplitude Difference (μV)')
    plt.xticks(rotation=45)
    plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, 'peak_amplitude_diff_by_category.png'), dpi=300)
    plt.close()
    
    # 2. Bar plot of peak latency differences by category and perturbation
    plt.figure(figsize=(14, 8))
    sns.barplot(
        data=point_df, 
        x='Category', 
        y='Peak_Latency_Diff', 
        hue='Perturbation',
        palette=colors
    )
    plt.title('Peak Latency Difference (ANSD - Normal) by Category and Perturbation Type')
    plt.xlabel('Phoneme Category')
    plt.ylabel('Latency Difference (ms)')
    plt.xticks(rotation=45)
    plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, 'peak_latency_diff_by_category.png'), dpi=300)
    plt.close()
    
    # 3. Bar plot by perturbation type
    plt.figure(figsize=(10, 6))
    sns.barplot(
        data=point_df,
        x='Perturbation',
        y='Peak_Amplitude_Diff',
        palette=colors
    )
    plt.title('Peak Amplitude Difference by Perturbation Type')
    plt.xlabel('Perturbation Type')
    plt.ylabel('Amplitude Difference (μV)')
    plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, 'peak_amplitude_diff_by_perturbation.png'), dpi=300)
    plt.close()
    
    # 4. Boxplots for each perturbation type
    for pert_type in point_df['Perturbation'].unique():
        pert_data = point_df[point_df['Perturbation'] == pert_type]
        
        # Peak amplitude boxplot
        plt.figure(figsize=(12, 6))
        sns.boxplot(
            data=pert_data, 
            x='Category', 
            y='Peak_Amplitude_Diff',
            color=colors.get(pert_type, 'blue')
        )
        plt.title(f'Peak Amplitude Difference Distribution - {pert_type}')
        plt.xlabel('Phoneme Category')
        plt.ylabel('Amplitude Difference (μV)')
        plt.xticks(rotation=45)
        plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, f'amplitude_boxplot_{pert_type}.png'), dpi=300)
        plt.close()
        
        # Peak latency boxplot
        plt.figure(figsize=(12, 6))
        sns.boxplot(
            data=pert_data, 
            x='Category', 
            y='Peak_Latency_Diff',
            color=colors.get(pert_type, 'blue')
        )
        plt.title(f'Peak Latency Difference Distribution - {pert_type}')
        plt.xlabel('Phoneme Category')
        plt.ylabel('Latency Difference (ms)')
        plt.xticks(rotation=45)
        plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, f'latency_boxplot_{pert_type}.png'), dpi=300)
        plt.close()
    
    # 5. Standardized effect sizes for peak amplitude
    if 'Standardized_Peak_Diff' in point_df.columns:
        plt.figure(figsize=(14, 8))
        sns.barplot(
            data=point_df, 
            x='Category', 
            y='Standardized_Peak_Diff', 
            hue='Perturbation',
            palette=colors
        )
        plt.title('Standardized Peak Amplitude Effect Size by Category and Perturbation Type')
        plt.xlabel('Phoneme Category')
        plt.ylabel('Effect Size (std units)')
        plt.xticks(rotation=45)
        plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'standardized_effect_size.png'), dpi=300)
        plt.close()
    
    # 6. Wave V specific plots if available
    wave_v_cols = ['WaveV_Amplitude_Diff', 'WaveV_Latency_Diff']
    for col in wave_v_cols:
        if col in point_df.columns and not point_df[col].isna().all():
            plt.figure(figsize=(14, 8))
            sns.barplot(
                data=point_df.dropna(subset=[col]), 
                x='Category', 
                y=col, 
                hue='Perturbation',
                palette=colors
            )
            plt.title(f'{col.replace("_", " ")} by Category and Perturbation Type')
            plt.xlabel('Phoneme Category')
            plt.ylabel('Difference')
            plt.xticks(rotation=45)
            plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            plt.tight_layout()
            plt.savefig(os.path.join(plots_dir, f'{col.lower()}_by_category.png'), dpi=300)
            plt.close()

def plot_mmd_results(mmd_df, output_dir):
    """
    Create visualizations for MMD test results.
    
    Parameters:
    -----------
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    output_dir : str
        Directory to save plots
    """
    # Create plots directory
    plots_dir = os.path.join(output_dir, 'plots')
    os.makedirs(plots_dir, exist_ok=True)
    
    # Check if DataFrame is empty
    if mmd_df.empty:
        print("No MMD data available for plotting")
        return
    
    # Define color palette for perturbation types
    colors = {
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # 1. Bar plot of MMD values by category and perturbation
    plt.figure(figsize=(14, 8))
    sns.barplot(
        data=mmd_df, 
        x='Category', 
        y='MMD', 
        hue='Perturbation',
        palette=colors
    )
    plt.title('Maximum Mean Discrepancy (MMD) by Category and Perturbation Type')
    plt.xlabel('Phoneme Category')
    plt.ylabel('MMD Value (higher = more difference)')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, 'mmd_by_category.png'), dpi=300)
    plt.close()
    
    # 2. Bar plot of MMD by perturbation type
    plt.figure(figsize=(10, 6))
    sns.barplot(
        data=mmd_df,
        x='Perturbation',
        y='MMD',
        palette=colors
    )
    plt.title('Maximum Mean Discrepancy (MMD) by Perturbation Type')
    plt.xlabel('Perturbation Type')
    plt.ylabel('MMD Value')
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, 'mmd_by_perturbation.png'), dpi=300)
    plt.close()
    
    # 3. Heatmap of MMD values
    if len(mmd_df) > 3:  # Only create heatmap if we have enough data
        pivot_mmd = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD'
        )
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            pivot_mmd, 
            annot=True, 
            cmap='YlOrRd', 
            linewidths=.5,
            fmt='.3f'
        )
        plt.title('MMD Values by Category and Perturbation Type')
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'mmd_heatmap.png'), dpi=300)
        plt.close()
    
    # 4. Heatmap of p-values
    if 'MMD_p_value' in mmd_df.columns and len(mmd_df) > 3:
        pivot_p = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD_p_value'
        )
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            pivot_p, 
            annot=True, 
            cmap='YlGnBu_r',  # Reversed: darker = more significant
            linewidths=.5,
            fmt='.3f',
            vmin=0,
            vmax=1
        )
        plt.title('MMD p-values by Category and Perturbation Type')
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'mmd_pvalue_heatmap.png'), dpi=300)
        plt.close()
    
    # 5. Heatmap of adjusted p-values
    if 'MMD_p_adjusted' in mmd_df.columns and len(mmd_df) > 3:
        pivot_p_adj = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD_p_adjusted'
        )
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            pivot_p_adj, 
            annot=True, 
            cmap='YlGnBu_r',  # Reversed: darker = more significant
            linewidths=.5,
            fmt='.3f',
            vmin=0,
            vmax=1
        )
        plt.title('MMD Adjusted p-values (FDR correction) by Category and Perturbation Type')
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'mmd_adjusted_pvalue_heatmap.png'), dpi=300)
        plt.close()
    
    # 6. Significance plot
    if 'MMD_significant' in mmd_df.columns and len(mmd_df) > 3:
        pivot_sig = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD_significant'
        )
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            pivot_sig, 
            annot=True, 
            cmap='Reds', 
            linewidths=.5,
            fmt='.0f'
        )
        plt.title('Significant MMD Differences (after correction)')
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'mmd_significance_heatmap.png'), dpi=300)
        plt.close()

def create_combined_visualization(point_df, mmd_df, output_dir):
    """
    Create a combined visualization that summarizes the key findings.
    
    Parameters:
    -----------
    point_df : pd.DataFrame
        DataFrame with point estimate test results
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    output_dir : str
        Directory to save the visualization
    """
    if point_df.empty:
        print("No point estimate data available for combined visualization")
        return
    
    # Create figure
    fig = plt.figure(figsize=(20, 15))
    
    # Define color palette for perturbation types
    colors = {
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # Plot 1: Bar chart of peak amplitude differences
    ax1 = plt.subplot(2, 2, 1)
    if 'Peak_Amplitude_Diff' in point_df.columns:
        sns.barplot(
            data=point_df, 
            x='Perturbation', 
            y='Peak_Amplitude_Diff', 
            ax=ax1,
            palette=colors
        )
        ax1.set_title('Mean Peak Amplitude Difference by Perturbation')
        ax1.set_xlabel('Perturbation Type')
        ax1.set_ylabel('Amplitude Difference (μV)')
        ax1.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    else:
        ax1.text(0.5, 0.5, 'Peak Amplitude Diff data not available', 
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax1.transAxes)
        ax1.set_title('Peak Amplitude Difference (Not Available)')
    
    # Plot 2: Bar chart of peak latency differences
    ax2 = plt.subplot(2, 2, 2)
    if 'Peak_Latency_Diff' in point_df.columns:
        sns.barplot(
            data=point_df, 
            x='Perturbation', 
            y='Peak_Latency_Diff', 
            ax=ax2,
            palette=colors
        )
        ax2.set_title('Mean Peak Latency Difference by Perturbation')
        ax2.set_xlabel('Perturbation Type')
        ax2.set_ylabel('Latency Difference (ms)')
        ax2.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    else:
        ax2.text(0.5, 0.5, 'Peak Latency Diff data not available', 
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax2.transAxes)
        ax2.set_title('Peak Latency Difference (Not Available)')
    
    # Plot 3: MMD values by perturbation (if available)
    ax3 = plt.subplot(2, 2, 3)
    if not mmd_df.empty and 'MMD' in mmd_df.columns and 'Perturbation' in mmd_df.columns:
        sns.barplot(
            data=mmd_df, 
            x='Perturbation', 
            y='MMD', 
            ax=ax3,
            palette=colors
        )
        ax3.set_title('Mean MMD Value by Perturbation')
        ax3.set_xlabel('Perturbation Type')
        ax3.set_ylabel('MMD Value')
    else:
        ax3.text(0.5, 0.5, 'MMD data not available', 
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax3.transAxes)
        ax3.set_title('MMD Comparison (Not Available)')
    
    # Plot 4: Heatmap of effect by category and perturbation
    ax4 = plt.subplot(2, 2, 4)
    if 'Category' in point_df.columns and 'Standardized_Peak_Diff' in point_df.columns and len(point_df) > 3:
        # Use peak amplitude difference standardized by normal std
        pivot_effect = point_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='Standardized_Peak_Diff'
        )
        
        if not pivot_effect.empty:
            sns.heatmap(
                pivot_effect, 
                ax=ax4,
                annot=True, 
                cmap='RdBu_r',  # Red-Blue diverging colormap, centered at 0
                linewidths=.5,
                fmt='.2f',
                center=0  # Center colormap at 0
            )
            ax4.set_title('Standardized Effect Size by Category and Perturbation')
        else:
            ax4.text(0.5, 0.5, 'Cannot create heatmap - pivot table is empty', 
                    horizontalalignment='center',
                    verticalalignment='center',
                    transform=ax4.transAxes)
            ax4.set_title('Effect Size Heatmap (Error)')
    elif 'Standardized_Peak_Diff' not in point_df.columns:
        ax4.text(0.5, 0.5, 'Standardized Peak Diff not available', 
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax4.transAxes)
        ax4.set_title('Effect Size Heatmap (Not Available)')
    else:
        ax4.text(0.5, 0.5, 'Not enough data for heatmap', 
                horizontalalignment='center',
                verticalalignment='center',
                transform=ax4.transAxes)
        ax4.set_title('Effect Size Heatmap (Not Available)')
    
    # Add an overall title
    plt.suptitle('ABR Statistical Analysis Summary', fontsize=16)
    plt.tight_layout(rect=[0, 0, 1, 0.96])  # Make room for suptitle
    
    # Save the combined figure
    plt.savefig(os.path.join(output_dir, 'statistical_summary.png'), dpi=300)
    plt.close()

def main_statistical_analysis():
    """
    Main function to run the statistical analysis pipeline.
    """
    # Configure paths
    base_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all'
    ansd_dir = os.path.join(base_dir, 'ABR_SELECT/ansd_silence')
    normal_dir = os.path.join(base_dir, 'ABR_SELECT/healthy_silence')
    output_dir = os.path.join(base_dir, 'ABR_SELECT/STAT_TESTS')
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Log file for recording analysis details
    log_file = os.path.join(output_dir, 'analysis_log.txt')
    
    # Set up logging
    with open(log_file, 'w') as f:
        f.write(f"ABR Statistical Analysis\n")
        f.write(f"Run at: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    
    # Step 1: Load normal ABR data
    print("Loading normal ABR data...")
    normal_results = load_normal_abr_data(normal_dir)
    
    if not normal_results:
        print("Error: No normal ABR data could be loaded. Analysis cannot continue.")
        with open(log_file, 'a') as f:
            f.write("Error: No normal ABR data could be loaded. Analysis terminated.\n")
        return
    
    print(f"Loaded {len(normal_results)} normal ABR categories")
    with open(log_file, 'a') as f:
        f.write(f"Loaded {len(normal_results)} normal ABR categories\n")
        for category in sorted(normal_results.keys()):
            f.write(f"  - {category}\n")
    
    # Step 2: Load perturbed ABR data
    print("\nLoading perturbed (ANSD) ABR data...")
    perturbation_results = load_perturbed_abr_data(ansd_dir)
    
    if not perturbation_results:
        print("Error: No perturbed ABR data could be loaded. Analysis cannot continue.")
        with open(log_file, 'a') as f:
            f.write("Error: No perturbed ABR data could be loaded. Analysis terminated.\n")
        return
    
    print(f"Loaded {len(perturbation_results)} perturbation types")
    with open(log_file, 'a') as f:
        f.write(f"\nLoaded {len(perturbation_results)} perturbation types\n")
        for pert_type, categories in sorted(perturbation_results.items()):
            f.write(f"  - {pert_type}: {len(categories)} categories\n")
    
    # Step 3: Run point estimate tests (amplitude and latency differences)
    print("\nRunning point estimate tests...")
    point_df = run_point_estimate_tests(normal_results, perturbation_results)
    
    # Save point estimate results
    if not point_df.empty:
        point_df.to_csv(os.path.join(output_dir, 'point_estimate_tests.csv'), index=False)
        print(f"Saved point estimate test results ({len(point_df)} comparisons)")
        with open(log_file, 'a') as f:
            f.write(f"\nCompleted point estimate analysis: {len(point_df)} comparisons\n")
    else:
        print("Warning: No point estimate test results were generated.")
        with open(log_file, 'a') as f:
            f.write("\nWarning: No point estimate test results were generated.\n")
    
    # Step 4: Run MMD tests
    print("\nRunning MMD tests with permutation testing...")
    mmd_df = run_mmd_tests(normal_results, perturbation_results, n_permutations=1000)
    
    # Save MMD results
    if not mmd_df.empty:
        mmd_df.to_csv(os.path.join(output_dir, 'mmd_tests.csv'), index=False)
        print(f"Saved MMD test results ({len(mmd_df)} comparisons)")
        with open(log_file, 'a') as f:
            f.write(f"\nCompleted MMD waveform analysis: {len(mmd_df)} comparisons\n")
            
            # Log significant findings
            if 'MMD_significant' in mmd_df.columns:
                significant_tests = mmd_df[mmd_df['MMD_significant'] == True]
                f.write(f"Found {len(significant_tests)} significant MMD differences after correction\n")
                for _, row in significant_tests.iterrows():
                    f.write(f"  - {row['Category']}, {row['Perturbation']}: MMD={row['MMD']:.4f}, p={row['MMD_p_value']:.4f}, adj_p={row['MMD_p_adjusted']:.4f}\n")
    else:
        print("Warning: No MMD test results were generated.")
        with open(log_file, 'a') as f:
            f.write("\nWarning: No MMD test results were generated.\n")
    
    # Step 5: Create visualizations
    print("\nCreating visualization plots...")
    
    # Point estimate plots
    if not point_df.empty:
        plot_point_estimate_results(point_df, output_dir)
        print("Created point estimate visualizations")
    
    # MMD plots
    if not mmd_df.empty:
        plot_mmd_results(mmd_df, output_dir)
        print("Created MMD visualizations")
    
    # Combined visualization
    if not point_df.empty:
        create_combined_visualization(point_df, mmd_df, output_dir)
        print("Created combined statistical summary")
    
    print("\nStatistical analysis complete!")
    print(f"Results saved to: {output_dir}")
    
    with open(log_file, 'a') as f:
        f.write(f"\nAnalysis complete at {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Results saved to: {output_dir}\n")
    
    return point_df, mmd_df
# %% 
if __name__ == "__main__":
    main_statistical_analysis()
# %%    