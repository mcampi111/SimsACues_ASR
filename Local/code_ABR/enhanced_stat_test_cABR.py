#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Statistical Analysis for ABR comparisons between normal and ANSD conditions.
Analyzes both point estimates (amplitude, latency) and waveform shapes (MMD).
Enhanced with phoneme-focused visualizations and additional statistical analyses.
"""
# %%
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
# %%
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
        
        # Find Wave I in normal (typically around 1-2ms)
        wave_i_region = (normal_time[normal_valid_time] >= 1) & (normal_time[normal_valid_time] <= 2)
        if np.any(wave_i_region):
            normal_wave_i_idx = np.argmax(normal_waveform[wave_i_region]) + np.where(wave_i_region)[0][0]
            normal_wave_i_amplitude = normal_waveform[normal_wave_i_idx]
            normal_wave_i_latency = normal_time[normal_valid_time][normal_wave_i_idx]
        else:
            normal_wave_i_amplitude = None
            normal_wave_i_latency = None
        
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
            
            # Find Wave I in perturbed data
            ansd_wave_i_amplitude = None
            ansd_wave_i_latency = None
            
            if normal_wave_i_latency is not None:
                # Search in a window around where normal Wave I is found
                search_window = (pert_time[pert_valid_time] >= normal_wave_i_latency - 0.5) & (pert_time[pert_valid_time] <= normal_wave_i_latency + 0.5)
                if np.any(search_window):
                    ansd_wave_i_idx = np.argmax(pert_waveform[search_window]) + np.where(search_window)[0][0]
                    ansd_wave_i_amplitude = pert_waveform[ansd_wave_i_idx]
                    ansd_wave_i_latency = pert_time[pert_valid_time][ansd_wave_i_idx]
            
            # Calculate differences
            amplitude_diff = pert_peak_amplitude - normal_peak_amplitude
            latency_diff = pert_peak_latency - normal_peak_latency
            
            if normal_wave_i_amplitude is not None and ansd_wave_i_amplitude is not None:
                wave_i_amplitude_diff = ansd_wave_i_amplitude - normal_wave_i_amplitude
                wave_i_latency_diff = ansd_wave_i_latency - normal_wave_i_latency
            else:
                wave_i_amplitude_diff = None
                wave_i_latency_diff = None
            
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
                'Normal_WaveI_Amplitude': normal_wave_i_amplitude,
                'ANSD_WaveI_Amplitude': ansd_wave_i_amplitude,
                'WaveI_Amplitude_Diff': wave_i_amplitude_diff,
                'Normal_WaveI_Latency': normal_wave_i_latency,
                'ANSD_WaveI_Latency': ansd_wave_i_latency,
                'WaveI_Latency_Diff': wave_i_latency_diff,
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

def create_phoneme_focused_visualization(point_df, mmd_df, output_dir):
    """
    Create visualizations that focus on phoneme categories rather than perturbation types.
    
    Parameters:
    -----------
    point_df : pd.DataFrame
        DataFrame with point estimate test results
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    output_dir : str
        Directory to save the visualizations
    """
    # Create plots directory
    plots_dir = os.path.join(output_dir, 'plots_by_phoneme')
    os.makedirs(plots_dir, exist_ok=True)
    
    # Check if DataFrames are empty
    if point_df.empty:
        print("No point estimate data available for phoneme visualization")
        return
    
    # Apply modern styling - fixed to work with newer versions
    import seaborn as sns
    sns.set_style("whitegrid")
    
    # Get unique categories and perturbations
    categories = sorted(point_df['Category'].unique())
    perturbations = sorted(point_df['Perturbation'].unique())
    
    # Define color palette for perturbations
    colors = {
        'jitter': 'red',
        'scattered_jitter': 'orange',
        'loss': 'green',
        'truncation': 'purple',
        'unknown': 'gray'
    }
    
    # Color map for consistent category coloring
    category_colors = dict(zip(categories, plt.cm.tab20.colors[:len(categories)]))
    
    # 1. For each phoneme category, create a comprehensive plot
    for category in categories:
        # Filter data for this category
        cat_point_data = point_df[point_df['Category'] == category]
        
        if not cat_point_data.empty:
            # Create figure with multiple subplots
            fig = plt.figure(figsize=(15, 12))
            fig.suptitle(f'ABR Analysis for Phoneme Category: {category}', fontsize=16, fontweight='bold')
            
            # Plot 1: Bar chart of peak amplitude differences by perturbation
            ax1 = plt.subplot(2, 2, 1)
            sns.barplot(
                data=cat_point_data, 
                x='Perturbation', 
                y='Peak_Amplitude_Diff', 
                ax=ax1,
                palette=colors
            )
            ax1.set_title('Peak Amplitude Difference by Perturbation', fontweight='bold')
            ax1.set_xlabel('Perturbation Type')
            ax1.set_ylabel('Amplitude Difference (μV)')
            ax1.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            
            # Plot 2: Bar chart of standardized effect sizes
            ax2 = plt.subplot(2, 2, 2)
            if 'Standardized_Peak_Diff' in cat_point_data.columns:
                sns.barplot(
                    data=cat_point_data, 
                    x='Perturbation', 
                    y='Standardized_Peak_Diff', 
                    ax=ax2,
                    palette=colors
                )
                ax2.set_title('Standardized Effect Size by Perturbation', fontweight='bold')
                ax2.set_xlabel('Perturbation Type')
                ax2.set_ylabel('Effect Size (std units)')
                ax2.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            else:
                ax2.text(0.5, 0.5, 'Standardized data not available', 
                        horizontalalignment='center',
                        verticalalignment='center',
                        transform=ax2.transAxes)
            
            # Plot 3: Peak latency differences
            ax3 = plt.subplot(2, 2, 3)
            sns.barplot(
                data=cat_point_data, 
                x='Perturbation', 
                y='Peak_Latency_Diff', 
                ax=ax3,
                palette=colors
            )
            ax3.set_title('Peak Latency Difference by Perturbation', fontweight='bold')
            ax3.set_xlabel('Perturbation Type')
            ax3.set_ylabel('Latency Difference (ms)')
            ax3.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            
            # Plot 4: MMD values if available
            ax4 = plt.subplot(2, 2, 4)
            if not mmd_df.empty:
                cat_mmd_data = mmd_df[mmd_df['Category'] == category]
                if not cat_mmd_data.empty and 'MMD' in cat_mmd_data.columns:
                    sns.barplot(
                        data=cat_mmd_data, 
                        x='Perturbation', 
                        y='MMD', 
                        ax=ax4,
                        palette=colors
                    )
                    ax4.set_title('Maximum Mean Discrepancy (MMD) by Perturbation', fontweight='bold')
                    ax4.set_xlabel('Perturbation Type')
                    ax4.set_ylabel('MMD Value')
                    
                    # Add significance markers if available
                    if 'MMD_significant' in cat_mmd_data.columns:
                        for i, row in enumerate(cat_mmd_data.itertuples()):
                            if hasattr(row, 'MMD_significant') and row.MMD_significant:
                                ax4.text(i, row.MMD + 0.01 * ax4.get_ylim()[1], '*', 
                                       fontsize=16, ha='center', fontweight='bold')
                else:
                    ax4.text(0.5, 0.5, 'MMD data not available for this category', 
                            horizontalalignment='center',
                            verticalalignment='center',
                            transform=ax4.transAxes)
            else:
                ax4.text(0.5, 0.5, 'MMD data not available', 
                        horizontalalignment='center',
                        verticalalignment='center',
                        transform=ax4.transAxes)
            
            plt.tight_layout(rect=[0, 0, 1, 0.95])  # Make room for suptitle
            plt.savefig(os.path.join(plots_dir, f'summary_{category.replace(" ", "_")}.pdf'), dpi=300)
            plt.close()
    
    # 2. Create comparative plots across phoneme categories
    
    # Create side-by-side MMD bar plots for each perturbation
    for perturbation in perturbations:
        if not mmd_df.empty:
            pert_mmd_data = mmd_df[mmd_df['Perturbation'] == perturbation]
            
            if not pert_mmd_data.empty:
                plt.figure(figsize=(14, 8))
                sns.barplot(
                    data=pert_mmd_data,
                    x='Category',
                    y='MMD',
                    color=colors.get(perturbation, 'blue')
                )
                plt.title(f'MMD Values by Phoneme Category for {perturbation} Perturbation', 
                         fontsize=14, fontweight='bold')
                plt.xlabel('Phoneme Category')
                plt.ylabel('MMD Value')
                plt.xticks(rotation=45, ha='right')
                
                # Add significance markers if available
                if 'MMD_significant' in pert_mmd_data.columns:
                    for i, row in enumerate(pert_mmd_data.itertuples()):
                        if hasattr(row, 'MMD_significant') and row.MMD_significant:
                            plt.text(i, row.MMD + 0.01 * plt.ylim()[1], '*', 
                                   fontsize=16, ha='center', fontweight='bold')
                
                plt.tight_layout()
                plt.savefig(os.path.join(plots_dir, f'mmd_by_phoneme_{perturbation}.pdf'), dpi=300)
                plt.close()
    
    # Side-by-side standardized effect size bar plots for each perturbation
    for perturbation in perturbations:
        pert_point_data = point_df[point_df['Perturbation'] == perturbation]
        
        if not pert_point_data.empty and 'Standardized_Peak_Diff' in pert_point_data.columns:
            plt.figure(figsize=(14, 8))
            sns.barplot(
                data=pert_point_data,
                x='Category',
                y='Standardized_Peak_Diff',
                color=colors.get(perturbation, 'blue')
            )
            plt.title(f'Standardized Effect Size by Phoneme Category for {perturbation} Perturbation',
                     fontsize=14, fontweight='bold')
            plt.xlabel('Phoneme Category')
            plt.ylabel('Effect Size (std units)')
            plt.xticks(rotation=45, ha='right')
            plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            plt.tight_layout()
            plt.savefig(os.path.join(plots_dir, f'effect_size_by_phoneme_{perturbation}.pdf'), dpi=300)
            plt.close()
    
    # 3. New - Comprehensive cross-phoneme comparison plots
    # ---------------------------------------------------------
    
    # 3.1. Create a comprehensive standardized effect size plot across all phonemes and perturbations
    if 'Standardized_Peak_Diff' in point_df.columns:
        # For grouped bar chart, we need to use factorplot/catplot in a different way
        plt.figure(figsize=(18, 10))
        
        # Create the grouped bar plot
        sns.barplot(
            data=point_df,
            x='Perturbation',
            y='Standardized_Peak_Diff',
            hue='Category',
            palette=category_colors
        )
        
        plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        plt.title('Standardized Effect Size Comparison Across All Phoneme Categories', 
                 fontsize=16, fontweight='bold')
        plt.xlabel('Perturbation Type', fontsize=12, fontweight='bold')
        plt.ylabel('Effect Size (std units)', fontsize=12, fontweight='bold')
        
        # Create a custom legend with better spacing and positioning
        plt.legend(title='Phoneme Category', 
                  title_fontsize=12,
                  fontsize=10,
                  bbox_to_anchor=(1.05, 1), 
                  loc='upper left')
        
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'cross_phoneme_effect_size_comparison.pdf'), dpi=300)
        plt.close()
    
    # 3.2. Create a heat ranking plot showing the most affected phonemes by perturbation
    if 'Standardized_Peak_Diff' in point_df.columns:
        # Absolute effect size for ranking (which phonemes are most affected regardless of direction)
        point_df['Abs_Effect_Size'] = point_df['Standardized_Peak_Diff'].abs()
        
        # Create pivot table with categories as rows and perturbations as columns
        pivot_abs_effect = point_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='Abs_Effect_Size',
            aggfunc='mean'
        )
        
        # Add a column showing overall effect across all perturbations
        pivot_abs_effect['Overall'] = pivot_abs_effect.mean(axis=1)
        
        # Sort by overall effect size (most affected first)
        pivot_abs_effect = pivot_abs_effect.sort_values('Overall', ascending=False)
        
        # Plot heatmap with categories sorted by overall effect
        plt.figure(figsize=(12, 10))
        sns.heatmap(
            pivot_abs_effect, 
            annot=True, 
            cmap='YlOrRd',  # Yellow-Orange-Red for intensity
            linewidths=.8,
            fmt='.2f',
            cbar_kws={
                'label': 'Absolute Effect Size', 
                'shrink': 0.8
            }
        )
        plt.title('Phoneme Categories Ranked by Magnitude of Effect', 
                 fontsize=16, fontweight='bold')
        plt.xlabel('Perturbation Type', fontsize=12, fontweight='bold')
        plt.ylabel('Phoneme Category (most affected at top)', 
                  fontsize=12, fontweight='bold')
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'phoneme_effect_ranking.pdf'), dpi=300)
        plt.close()
        
    # 3.3. Create a radar/spider plot for the most affected phoneme categories
    if 'Standardized_Peak_Diff' in point_df.columns and len(categories) > 3:
        # Get the top categories (most affected)
        top_categories = pivot_abs_effect.index[:min(8, len(categories))].tolist()
        
        # Filter data for top categories
        top_cat_data = point_df[point_df['Category'].isin(top_categories)]
        
        # Create a radar plot
        # Number of variables to plot
        N = len(perturbations)
        
        # Create figure
        fig = plt.figure(figsize=(12, 10))
        
        # Calculate angles for plot 
        angles = [n / float(N) * 2 * np.pi for n in range(N)]
        angles += angles[:1]  # Close the loop
        
        # Initialize the subplot as polar
        ax = fig.add_subplot(111, polar=True)
        
        # Draw one axis per variable and add labels
        plt.xticks(angles[:-1], perturbations, fontsize=12)
        
        # Draw the category lines
        for category in top_categories:
            # Get standardized effect data for this category across perturbations
            values = []
            for pert in perturbations:
                val = top_cat_data[(top_cat_data['Category'] == category) & 
                                  (top_cat_data['Perturbation'] == pert)]['Standardized_Peak_Diff'].values
                if len(val) > 0:
                    values.append(val[0])
                else:
                    values.append(0)
            
            # Close the loop
            values += values[:1]
            
            # Plot the category line
            ax.plot(angles, values, 'o-', linewidth=2, label=category, 
                   color=category_colors.get(category, 'blue'))
            ax.fill(angles, values, alpha=0.1, 
                   color=category_colors.get(category, 'blue'))
        
        # Add legend
        plt.legend(loc='upper right', bbox_to_anchor=(0.1, 0.1))
        
        plt.title('Perturbation Effects Across Top Phoneme Categories', 
                 fontsize=16, fontweight='bold', y=1.08)
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'top_phonemes_radar_plot.pdf'), dpi=300)
        plt.close()
    
    # 3.4. Create a faceted grid showing detailed effects across all phonemes and perturbations
    if 'Standardized_Peak_Diff' in point_df.columns and len(categories) > 1:
        # Use FacetGrid to create a matrix of small plots
        g = sns.FacetGrid(
            point_df, 
            col='Perturbation', 
            row='Category', 
            height=2.5, 
            aspect=1.2,
            sharex=False,
            sharey=True,
            margin_titles=True
        )
        
        # Map a simple bar plot to each cell, colored by perturbation
        def _draw_barplot(data, **kwargs):
            ax = plt.gca()
            sns.barplot(
                data=data, 
                x='Perturbation', 
                y='Standardized_Peak_Diff',
                palette=colors,
                ax=ax
            )
            ax.axhline(y=0, ls='--', c='black', alpha=0.5)
            
        g.map_dataframe(_draw_barplot)
        
        # Improve titles and labels
        g.fig.subplots_adjust(top=0.9)
        g.fig.suptitle('Detailed Comparison of Standardized Effect Sizes', 
                      fontsize=16, fontweight='bold')
        
        # Set axis labels only on the leftmost and bottom plots
        g.set_axis_labels("", "Effect Size")
        
        # Rotate x-axis labels
        for ax in g.axes.flat:
            if ax.get_xticklabels():
                ax.set_xticklabels(ax.get_xticklabels(), rotation=45, ha='right')
            # Remove x-label from all subplots for cleaner look
            ax.set_xlabel('')
        
        plt.tight_layout()
        plt.savefig(os.path.join(plots_dir, 'detailed_facet_grid.pdf'), dpi=300)
        plt.close()


# Add these functions to complete your ABR analysis script

def create_enhanced_heatmaps(point_df, mmd_df, output_dir):
    """
    Create improved heatmap visualizations focusing on MMD values and standardized effect sizes.
    
    Parameters:
    -----------
    point_df : pd.DataFrame
        DataFrame with point estimate test results
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    output_dir : str
        Directory to save the visualizations
    """
    # Create heatmaps directory
    heatmaps_dir = os.path.join(output_dir, 'enhanced_heatmaps')
    os.makedirs(heatmaps_dir, exist_ok=True)
    
    # Apply some styling to make plots fancier
    import seaborn as sns
    sns.set_style("whitegrid")
    
    # 1. Enhanced MMD value heatmap
    if not mmd_df.empty and 'MMD' in mmd_df.columns and len(mmd_df) > 3:
        pivot_mmd = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD'
        )
        
        if not pivot_mmd.empty:
            plt.figure(figsize=(12, 10))
            cmap = sns.diverging_palette(220, 10, as_cmap=True)
            
            # Plot the heatmap with improved aesthetics
            ax = sns.heatmap(
                pivot_mmd, 
                annot=True, 
                cmap=cmap, 
                linewidths=.5,
                fmt='.3f',
                cbar_kws={
                    'label': 'MMD Value',
                    'shrink': 0.8,
                    'pad': 0.05
                }
            )
            
            # Add significance markers if available with better positioning
            if not mmd_df.empty and 'MMD_significant' in mmd_df.columns:
                pivot_sig = mmd_df.pivot_table(
                    index='Category',
                    columns='Perturbation',
                    values='MMD_significant',
                    aggfunc=lambda x: x.any()  # Use any() for boolean values
                )
                
                # Add stars for significant differences - positioned away from values
                for i in range(pivot_mmd.shape[0]):
                    for j in range(pivot_mmd.shape[1]):
                        if i < pivot_sig.shape[0] and j < pivot_sig.shape[1]:
                            if pivot_sig.iloc[i, j]:
                                plt.text(j + 0.8, i + 0.2, '*', 
                                        ha='center', va='center', color='black', fontsize=16, fontweight='bold')
            
            plt.title('Maximum Mean Discrepancy (MMD) by Phoneme Category and Perturbation Type', 
                     fontsize=16, fontweight='bold', pad=20)
            plt.xlabel('Perturbation Type', fontsize=12, fontweight='bold')
            plt.ylabel('Phoneme Category', fontsize=12, fontweight='bold')
            plt.tight_layout()
            plt.savefig(os.path.join(heatmaps_dir, 'enhanced_mmd_heatmap.pdf'), dpi=300)
            plt.close()
    
    # 2. Standalone standardized effect size heatmap (added as requested)
    if 'Standardized_Peak_Diff' in point_df.columns and len(point_df) > 3:
        pivot_effect = point_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='Standardized_Peak_Diff'
        )
        
        if not pivot_effect.empty:
            plt.figure(figsize=(12, 10))
            
            # Plot the heatmap with improved aesthetics
            ax = sns.heatmap(
                pivot_effect, 
                annot=True, 
                cmap='RdBu_r',  # Red-Blue diverging colormap, centered at 0
                linewidths=.8,
                fmt='.2f',
                center=0,  # Center colormap at 0
                annot_kws={"fontsize": 10},
                cbar_kws={
                    'label': 'Standardized Effect Size',
                    'shrink': 0.8,
                    'orientation': 'horizontal',
                    'pad': 0.05
                }
            )
            
            plt.title('Standardized Effect Size by Phoneme Category and Perturbation Type', 
                     fontsize=16, fontweight='bold', pad=20)
            plt.xlabel('Perturbation Type', fontsize=12, fontweight='bold')
            plt.ylabel('Phoneme Category', fontsize=12, fontweight='bold')
            
            # Add a border around the heatmap
            for _, spine in ax.spines.items():
                spine.set_visible(True)
                spine.set_linewidth(2)
            
            plt.tight_layout()
            plt.savefig(os.path.join(heatmaps_dir, 'standardized_effect_heatmap.pdf'), dpi=300)
            plt.close()
    
    # 3. Combined standardized effect size and MMD heatmaps (keep this for backward compatibility)
    if 'Standardized_Peak_Diff' in point_df.columns and len(point_df) > 3 and not mmd_df.empty and 'MMD' in mmd_df.columns:
        pivot_effect = point_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='Standardized_Peak_Diff'
        )
        
        pivot_mmd = mmd_df.pivot_table(
            index='Category',
            columns='Perturbation',
            values='MMD'
        )
        
        if not pivot_effect.empty and not pivot_mmd.empty:
            # Create a figure with two side-by-side heatmaps
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 10))
            
            # Plot 1: Standardized effect size heatmap
            sns.heatmap(
                pivot_effect, 
                ax=ax1,
                annot=True, 
                cmap='RdBu_r',
                linewidths=.8,
                fmt='.2f',
                center=0,
                annot_kws={"fontsize": 10},
                cbar_kws={'label': 'Standardized Effect Size', 'shrink': 0.8}
            )
            ax1.set_title('Standardized Effect Size', fontsize=16, fontweight='bold', pad=20)
            ax1.set_xlabel('Perturbation Type', fontsize=12, fontweight='bold')
            ax1.set_ylabel('Phoneme Category', fontsize=12, fontweight='bold')
            
            # Plot 2: MMD heatmap
            cmap = sns.cubehelix_palette(start=2, rot=0, dark=0, light=.95, reverse=False, as_cmap=True)
            sns.heatmap(
                pivot_mmd, 
                ax=ax2,
                annot=True, 
                cmap=cmap,
                linewidths=.8,
                fmt='.3f',
                annot_kws={"fontsize": 10},
                cbar_kws={'label': 'MMD Value', 'shrink': 0.8}
            )
            
            # Add significance markers if available with better positioning
            if 'MMD_significant' in mmd_df.columns:
                pivot_sig = mmd_df.pivot_table(
                    index='Category',
                    columns='Perturbation',
                    values='MMD_significant',
                    aggfunc=lambda x: x.any()
                )
                
                # Add stars for significant differences - positioned away from values
                for i in range(pivot_mmd.shape[0]):
                    for j in range(pivot_mmd.shape[1]):
                        if i < pivot_sig.shape[0] and j < pivot_sig.shape[1]:
                            if pivot_sig.iloc[i, j]:
                                ax2.text(j + 0.8, i + 0.2, '*', 
                                        ha='center', va='center', color='black', fontsize=16, fontweight='bold')
            
            ax2.set_title('Maximum Mean Discrepancy (MMD)', fontsize=16, fontweight='bold', pad=20)
            ax2.set_xlabel('Perturbation Type', fontsize=12, fontweight='bold')
            ax2.set_ylabel('Phoneme Category', fontsize=12, fontweight='bold')
            
            plt.suptitle('Comparison of Effect Size and MMD by Phoneme Category and Perturbation Type', 
                        fontsize=18, fontweight='bold', y=1.02)
            plt.tight_layout()
            plt.savefig(os.path.join(heatmaps_dir, 'combined_heatmaps.pdf'), dpi=300)
            plt.close()
    
    # 4. Modified individual measure heatmaps with fancier styling
    for measure, title in [
        ('Peak_Amplitude_Diff', 'Peak Amplitude Difference (μV)'),
        ('Peak_Latency_Diff', 'Peak Latency Difference (ms)'),
        ('WaveI_Amplitude_Diff', 'Wave I Amplitude Difference (μV)'),  # Changed from V to I
        ('WaveI_Latency_Diff', 'Wave I Latency Difference (ms)')       # Changed from V to I
    ]:
        if measure in point_df.columns and not point_df[measure].isna().all():
            pivot_data = point_df.pivot_table(
                index='Category',
                columns='Perturbation',
                values=measure
            )
            
            if not pivot_data.empty:
                plt.figure(figsize=(12, 10))
                
                # Use appropriate colormap for each measure
                if 'Amplitude' in measure:
                    cmap = 'RdBu_r'  # Red-Blue for amplitudes
                    center = 0
                elif 'Latency' in measure:
                    cmap = 'PiYG'  # Purple-Yellow-Green for latencies
                    center = 0
                else:
                    cmap = 'viridis'
                    center = None
                
                ax = sns.heatmap(
                    pivot_data, 
                    annot=True, 
                    cmap=cmap, 
                    linewidths=.8,
                    fmt='.3f',
                    center=center,
                    annot_kws={"fontsize": 10},
                    cbar_kws={
                        'label': title,
                        'shrink': 0.8,
                        'orientation': 'horizontal',
                        'pad': 0.05
                    }
                )
                
                # Add a border around the heatmap
                for _, spine in ax.spines.items():
                    spine.set_visible(True)
                    spine.set_linewidth(2)
                
                plt.title(f'{title} by Phoneme Category and Perturbation Type', 
                         fontsize=16, fontweight='bold', pad=20)
                plt.xlabel('Perturbation Type', fontsize=12, fontweight='bold')
                plt.ylabel('Phoneme Category', fontsize=12, fontweight='bold')
                plt.tight_layout()
                plt.savefig(os.path.join(heatmaps_dir, f'{measure.lower()}_heatmap.pdf'), dpi=300)
                plt.close()

def run_additional_analyses(point_df, mmd_df, normal_results, perturbation_results, output_dir):
    """
    Run additional statistical analyses on the ABR data.
    
    Parameters:
    -----------
    point_df : pd.DataFrame
        DataFrame with point estimate test results
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    normal_results : dict
        Dictionary with category as key and ABR results as value for normal ABRs
    perturbation_results : dict
        Dictionary with perturbation type as key and dict of category results as value
    output_dir : str
        Directory to save results
    """
    # Create directory for additional analyses
    addl_dir = os.path.join(output_dir, 'additional_analyses')
    os.makedirs(addl_dir, exist_ok=True)
    
    # 1. Correlation analysis between MMD and point estimates
    if not mmd_df.empty and not point_df.empty:
        # Merge the two dataframes on Category and Perturbation
        merged_df = pd.merge(
            mmd_df, 
            point_df,
            on=['Category', 'Perturbation'],
            suffixes=('_mmd', '_point')
        )
        
        if not merged_df.empty:
            # Calculate correlations
            corr_cols = ['MMD', 'Peak_Amplitude_Diff', 'Peak_Latency_Diff']
            if all(col in merged_df.columns for col in corr_cols):
                corr_df = merged_df[corr_cols].corr()
                
                # Create correlation heatmap
                plt.figure(figsize=(10, 8))
                sns.heatmap(
                    corr_df,
                    annot=True,
                    cmap='coolwarm',
                    vmin=-1, vmax=1,
                    linewidths=.5,
                    fmt='.3f'
                )
                plt.title('Correlation Between MMD and Point Estimates', fontsize=14)
                plt.tight_layout()
                plt.savefig(os.path.join(addl_dir, 'correlation_heatmap.pdf'), dpi=300)
                plt.close()
                
                # Save correlation results
                corr_df.to_csv(os.path.join(addl_dir, 'correlation_results.csv'))
    
    # 2. Analysis by phoneme characteristics
    # Group phonemes by linguistic features
    phoneme_groups = {
        'Vowels': ['Vowel'],
        'Consonants_Stops': ['Stop', 'Affricate'],
        'Consonants_Fricatives': ['Fricative'],
        'Consonants_Sonorants': ['Nasal', 'Liquid', 'Glide'],
        'Other': ['Flap', 'Glottal Stop', 'Epenthetic', 'Silence', 'Syllabic Consonant']
    }
    
    # Add phoneme group column to dataframes
    if not point_df.empty:
        point_df['PhonemeGroup'] = point_df['Category'].apply(
            lambda cat: next((group for group, cats in phoneme_groups.items() if cat in cats), 'Other')
        )
        
        # Calculate mean values by phoneme group and perturbation
        group_stats = point_df.groupby(['PhonemeGroup', 'Perturbation']).agg({
            'Peak_Amplitude_Diff': ['mean', 'std'],
            'Peak_Latency_Diff': ['mean', 'std'],
            'Standardized_Peak_Diff': ['mean', 'std'] if 'Standardized_Peak_Diff' in point_df.columns else None
        }).reset_index()
        
        # Plot group stats
        for measure in ['Peak_Amplitude_Diff', 'Peak_Latency_Diff']:
            plt.figure(figsize=(12, 8))
            sns.barplot(
                data=point_df,
                x='PhonemeGroup',
                y=measure,
                hue='Perturbation'
            )
            plt.title(f'{measure} by Phoneme Group and Perturbation Type', fontsize=14)
            plt.xlabel('Phoneme Group')
            plt.ylabel(measure)
            plt.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            plt.tight_layout()
            plt.savefig(os.path.join(addl_dir, f'{measure.lower()}_by_group.pdf'), dpi=300)
            plt.close()
    
    # 3. MMD by phoneme group
    if not mmd_df.empty:
        mmd_df['PhonemeGroup'] = mmd_df['Category'].apply(
            lambda cat: next((group for group, cats in phoneme_groups.items() if cat in cats), 'Other')
        )
        
        # Calculate mean MMD by phoneme group and perturbation
        group_mmd = mmd_df.groupby(['PhonemeGroup', 'Perturbation']).agg({
            'MMD': ['mean', 'std', 'count'],
            'MMD_p_value': ['mean', 'min']
        }).reset_index()
        
        # Plot MMD by group
        plt.figure(figsize=(12, 8))
        sns.barplot(
            data=mmd_df,
            x='PhonemeGroup',
            y='MMD',
            hue='Perturbation'
        )
        plt.title('MMD by Phoneme Group and Perturbation Type', fontsize=14)
        plt.xlabel('Phoneme Group')
        plt.ylabel('MMD Value')
        plt.tight_layout()
        plt.savefig(os.path.join(addl_dir, 'mmd_by_group.pdf'), dpi=300)
        plt.close()

def create_comprehensive_summary(point_df, mmd_df, output_dir):
    """
    Create a comprehensive summary visualization showing key metrics for each phoneme category across perturbations.
    
    Parameters:
    -----------
    point_df : pd.DataFrame
        DataFrame with point estimate test results
    mmd_df : pd.DataFrame
        DataFrame with MMD test results
    output_dir : str
        Directory to save the visualization
    """
    # Create summary directory
    summary_dir = os.path.join(output_dir, 'comprehensive_summary')
    os.makedirs(summary_dir, exist_ok=True)
    
    if point_df.empty:
        print("No point estimate data available for summary visualization")
        return
    
    # Get unique categories and perturbations
    categories = sorted(point_df['Category'].unique())
    perturbations = sorted(point_df['Perturbation'].unique())
    
    # Create a multi-panel figure showing key metrics for all categories
    n_categories = len(categories)
    n_perturbations = len(perturbations)
    
    # Define a consistent color palette
    color_palette = sns.color_palette("viridis", n_perturbations)
    perturbation_colors = dict(zip(perturbations, color_palette))
    
    # Create a large multi-panel figure
    fig = plt.figure(figsize=(20, n_categories * 3.5))
    gs = fig.add_gridspec(n_categories, 3)
    
    # Create a subplot for each category
    for i, category in enumerate(categories):
        # Filter data for this category
        cat_point_data = point_df[point_df['Category'] == category]
        
        if not cat_point_data.empty:
            # Plot 1: Peak amplitude differences
            ax1 = fig.add_subplot(gs[i, 0])
            
            # Create custom bar colors based on perturbation
            bar_colors = [perturbation_colors[p] for p in cat_point_data['Perturbation']]
            
            sns.barplot(
                data=cat_point_data, 
                x='Perturbation', 
                y='Peak_Amplitude_Diff', 
                ax=ax1,
                palette=perturbation_colors
            )
            ax1.set_title(f'{category}: Peak Amplitude Diff (μV)')
            ax1.set_xlabel('')
            if i == 0:
                ax1.set_title(f'Peak Amplitude Diff (μV)\n{category}')
            else:
                ax1.set_title(category)
            
            # Only show y-label for leftmost plots
            if i == n_categories // 2:
                ax1.set_ylabel('Amplitude Diff (μV)')
            else:
                ax1.set_ylabel('')
                
            ax1.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            
            # Plot 2: Standardized effect size
            ax2 = fig.add_subplot(gs[i, 1])
            if 'Standardized_Peak_Diff' in cat_point_data.columns:
                sns.barplot(
                    data=cat_point_data, 
                    x='Perturbation', 
                    y='Standardized_Peak_Diff', 
                    ax=ax2,
                    palette=perturbation_colors
                )
                if i == 0:
                    ax2.set_title('Standardized Effect Size')
                ax2.set_xlabel('')
                if i == n_categories // 2:
                    ax2.set_ylabel('Effect Size (std units)')
                else:
                    ax2.set_ylabel('')
                ax2.axhline(y=0, color='black', linestyle='--', alpha=0.5)
            else:
                ax2.text(0.5, 0.5, 'Standardized data not available', 
                        horizontalalignment='center',
                        verticalalignment='center',
                        transform=ax2.transAxes)
            
            # Plot 3: MMD values if available
            ax3 = fig.add_subplot(gs[i, 2])
            if not mmd_df.empty:
                cat_mmd_data = mmd_df[(mmd_df['Category'] == category)]
                if not cat_mmd_data.empty and 'MMD' in cat_mmd_data.columns:
                    sns.barplot(
                        data=cat_mmd_data, 
                        x='Perturbation', 
                        y='MMD', 
                        ax=ax3,
                        palette=perturbation_colors
                    )
                    if i == 0:
                        ax3.set_title('MMD Value')
                    ax3.set_xlabel('')
                    if i == n_categories // 2:
                        ax3.set_ylabel('MMD Value')
                    else:
                        ax3.set_ylabel('')
                    
                    # Add significance markers if available
                    if 'MMD_significant' in cat_mmd_data.columns:
                        for j, row in enumerate(cat_mmd_data.itertuples()):
                            if hasattr(row, 'MMD_significant') and row.MMD_significant:
                                ax3.text(j, row.MMD, '*', fontsize=16, ha='center')
                else:
                    ax3.text(0.5, 0.5, 'MMD data not available', 
                            horizontalalignment='center',
                            verticalalignment='center',
                            transform=ax3.transAxes)
            else:
                ax3.text(0.5, 0.5, 'MMD data not available', 
                        horizontalalignment='center',
                        verticalalignment='center',
                        transform=ax3.transAxes)
    
    # Add common x-axis label at the bottom
    plt.figtext(0.5, 0.01, 'Perturbation Type', ha='center', fontsize=14)
    
    # Add a legend at the top of the figure
    handles = [plt.Rectangle((0,0),1,1, color=perturbation_colors[p]) for p in perturbations]
    plt.figlegend(handles, perturbations, loc='upper center', bbox_to_anchor=(0.5, 0.98), ncol=n_perturbations)
    
    plt.tight_layout(rect=[0, 0.02, 1, 0.96])  # Make room for common labels
    plt.savefig(os.path.join(summary_dir, 'all_categories_summary.pdf'), dpi=300)
    plt.close()

    # Create detailed statistical summary tables
    # 1. Summary table by phoneme category
    if not point_df.empty:
        # Compute category-level statistics
        cat_summary = []
        for category in categories:
            cat_data = point_df[point_df['Category'] == category]
            mmd_cat_data = mmd_df[mmd_df['Category'] == category] if not mmd_df.empty else pd.DataFrame()
            
            for perturbation in perturbations:
                pert_data = cat_data[cat_data['Perturbation'] == perturbation]
                mmd_pert_data = mmd_cat_data[mmd_cat_data['Perturbation'] == perturbation] if not mmd_df.empty else pd.DataFrame()
                
                if not pert_data.empty:
                    entry = {
                        'Category': category,
                        'Perturbation': perturbation,
                        'Amplitude_Diff': pert_data['Peak_Amplitude_Diff'].mean() if 'Peak_Amplitude_Diff' in pert_data else None,
                        'Latency_Diff': pert_data['Peak_Latency_Diff'].mean() if 'Peak_Latency_Diff' in pert_data else None,
                        'Effect_Size': pert_data['Standardized_Peak_Diff'].mean() if 'Standardized_Peak_Diff' in pert_data else None,
                        'MMD': mmd_pert_data['MMD'].mean() if not mmd_pert_data.empty and 'MMD' in mmd_pert_data else None,
                        'MMD_p_value': mmd_pert_data['MMD_p_value'].mean() if not mmd_pert_data.empty and 'MMD_p_value' in mmd_pert_data else None,
                        'MMD_significant': mmd_pert_data['MMD_significant'].any() if not mmd_pert_data.empty and 'MMD_significant' in mmd_pert_data else None
                    }
                    cat_summary.append(entry)
        
        # Create summary DataFrame
        summary_df = pd.DataFrame(cat_summary)
        
        # Save summary table
        if not summary_df.empty:
            summary_df.to_csv(os.path.join(summary_dir, 'category_perturbation_summary.csv'), index=False)
            
            # Create formatted HTML version with highlighted significant results
            try:
                import numpy as np
                from IPython.display import HTML
                
                # Function to highlight significant results
                def highlight_significant(val, column):
                    if isinstance(val, bool) and val:
                        return 'background-color: yellow'
                    elif isinstance(val, (int, float)) and not np.isnan(val):
                        if 'p_value' in column and val < 0.05:
                            return 'background-color: lightgreen'
                        elif 'Effect_Size' in column and abs(val) > 1.0:
                            return 'background-color: lightblue'
                    return ''
                
                # Apply styling to each column
                styled_df = summary_df.style
                for column in summary_df.columns:
                    styled_df = styled_df.applymap(lambda val: highlight_significant(val, column), subset=[column])
                
                # Save as HTML
                with open(os.path.join(summary_dir, 'summary_table.html'), 'w') as f:
                    f.write('<html><head><style>')
                    f.write('table { border-collapse: collapse; }')
                    f.write('th, td { border: 1px solid black; padding: 8px; text-align: center; }')
                    f.write('th { background-color: #f2f2f2; }')
                    f.write('</style></head><body>')
                    f.write('<h2>ABR Analysis Summary by Category and Perturbation</h2>')
                    f.write(styled_df.to_html())
                    f.write('<p><strong>Notes:</strong></p>')
                    f.write('<ul>')
                    f.write('<li>Amplitude differences in μV</li>')
                    f.write('<li>Latency differences in ms</li>')
                    f.write('<li>Effect size > 1.0 indicates a large effect</li>')
                    f.write('<li>Yellow highlighting indicates statistically significant MMD (p < 0.05 after correction)</li>')
                    f.write('</ul>')
                    f.write('</body></html>')
            except Exception as e:
                print(f"Could not create HTML summary table: {e}")

def main_statistical_analysis_enhanced():
    """
    Enhanced main function to run the statistical analysis pipeline with improved visualizations.
    """
    # Configure paths (keep your existing paths)
    base_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all'
    ansd_dir = os.path.join(base_dir, 'ABR_SELECT/ansd_silence')
    normal_dir = os.path.join(base_dir, 'ABR_SELECT/healthy_silence')
    output_dir = os.path.join(base_dir, 'ABR_SELECT/ENHANCED_STAT_TESTS')
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Log file for recording analysis details
    log_file = os.path.join(output_dir, 'enhanced_analysis_log.txt')
    
    # Set up logging
    with open(log_file, 'w') as f:
        f.write(f"Enhanced ABR Statistical Analysis\n")
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
    
    # Step 3: Run point estimate tests
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
    
    # Step 5: Create enhanced visualizations
    print("\nCreating enhanced visualizations...")
    
    # 5.1: Create phoneme-focused visualizations
    create_phoneme_focused_visualization(point_df, mmd_df, output_dir)
    print("Created phoneme-focused visualizations")
    
    # 5.2: Create enhanced heatmaps
    create_enhanced_heatmaps(point_df, mmd_df, output_dir)
    print("Created enhanced heatmaps")
    
    # Step 6: Run additional analyses
    print("\nRunning additional statistical analyses...")
    run_additional_analyses(point_df, mmd_df, normal_results, perturbation_results, output_dir)
    print("Completed additional analyses")
    
    # Step 7: Create comprehensive summary
    print("\nCreating comprehensive summary...")
    create_comprehensive_summary(point_df, mmd_df, output_dir)
    print("Created comprehensive summary")
    
    # Summary
    print("\nEnhanced statistical analysis complete!")
    print(f"Results saved to: {output_dir}")
    
    with open(log_file, 'a') as f:
        f.write(f"\nEnhanced analysis complete at {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Results saved to: {output_dir}\n")
    
    return point_df, mmd_df
# %%
# If you run this script as main, use the enhanced version
if __name__ == "__main__":
    point_df, mmd_df = main_statistical_analysis_enhanced()
    
    print("\nAnalysis complete! Visualizations and results are available in the output directory.")
# %%
