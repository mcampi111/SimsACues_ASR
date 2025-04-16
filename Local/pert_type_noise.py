# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.io import loadmat
from pathlib import Path
import re
# %%
# Define base path
base_path = Path('/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all')
output_path = Path('./perturbation_analysis_comprehensive')
output_path.mkdir(exist_ok=True)

# Define paths for different datasets
neurogram_paths = {
    "healthy_silence": base_path / "SELECT_Neurograms" / "TEST",
    "healthy_noise": base_path / "SELECT_Neurograms_WithNoise" / "TEST",
    "ansd_silence": base_path / "SELECT_Neurograms_ANSD" / "TEST",
    "ansd_noise": base_path / "SELECT_Neurograms_ANSD_WithNoise" / "TEST"
}

# Phoneme category map
PHONEME_CATEGORY_MAP = {
    'm': 'Nasal', 'n': 'Nasal', 'ng': 'Nasal', 'em': 'Nasal', 'en': 'Nasal', 'nx': 'Nasal',
    'iy': 'Vowel', 'ih': 'Vowel', 'ix': 'Vowel', 'ey': 'Vowel', 'eh': 'Vowel', 'ae': 'Vowel',
    'aa': 'Vowel', 'aw': 'Vowel', 'ay': 'Vowel', 'ah': 'Vowel', 'ax': 'Vowel', 'ax-h': 'Vowel',
    'ao': 'Vowel', 'oy': 'Vowel', 'ow': 'Vowel', 'uh': 'Vowel', 'uw': 'Vowel', 'ux': 'Vowel',
    'er': 'Vowel', 'axr': 'Vowel',
    
    'l': 'Liquid', 'r': 'Liquid',
    'w': 'Glide', 'y': 'Glide',
    's': 'Fricative', 'z': 'Fricative', 'f': 'Fricative', 'v': 'Fricative', 'th': 'Fricative',
    'dh': 'Fricative', 'sh': 'Fricative', 'hh': 'Fricative', 'hv': 'Fricative',
    't': 'Stop', 'd': 'Stop', 'p': 'Stop', 'b': 'Stop', 'k': 'Stop', 'g': 'Stop',
    'tcl': 'Stop', 'dcl': 'Stop', 'pcl': 'Stop', 'bcl': 'Stop', 'kcl': 'Stop', 'gcl': 'Stop',
    'ch': 'Affricate', 'jh': 'Affricate',
    'dx': 'Flap',
    'q': 'Glottal Stop',
    'epi': 'Epenthetic',
    'h#': 'Silence',
    'el': 'Syllabic Consonant'
}

# Main phoneme categories for analysis
MAIN_CATEGORIES = ["Vowel", "Stop", "Fricative", "Nasal", "Liquid", "Glide", "Silence", "Affricate"]

# Define noise conditions to look for in filenames
NOISE_CONDITIONS = [
    {"pattern": "snr-5.0", "display": "-5 dB", "name": "SNR -5"},
    {"pattern": "snr0.0", "display": "0 dB", "name": "SNR 0"},
    {"pattern": "snr5.0", "display": "5 dB", "name": "SNR 5"},
    {"pattern": "snr10.0", "display": "10 dB", "name": "SNR 10"},
    {"pattern": "snr15.0", "display": "15 dB", "name": "SNR 15"},
  #  {"pattern": "with_noise_random", "display": "Random Noise", "name": "Random Noise"},
    {"pattern": "with_noise", "display": "Default Noise", "name": "Default Noise"},
    # The silence condition is handled specially in the extract_noise_condition function
]

# Define frequency bands with column indices for the 150-column neurogram
FREQUENCY_BANDS = [
    {"name": "Low", "start_idx": 0, "end_idx": 50, "min": 125, "max": 1000},        # First ~1/3 of columns (low frequencies)
    {"name": "Medium", "start_idx": 50, "end_idx": 100, "min": 1000, "max": 4000},   # Middle ~1/3 of columns (medium frequencies)
    {"name": "High", "start_idx": 100, "end_idx": 150, "min": 4000, "max": 10000}     # Last ~1/3 of columns (high frequencies)
]
# %%
def extract_phoneme_from_filename(filename):
    """Extract phoneme from filename."""
    parts = filename.split('_')
    if len(parts) > 1:
        return parts[1]  # Typically the second part is the phoneme
    return None

def extract_noise_condition(filename):
    """Determine noise condition from filename."""
    # Handle silence case (no noise pattern in filename)
    if ("with_noise" not in filename and 
        "snr" not in filename and 
        ("neurogram.mat" in filename or "neurogram_ansd.mat" in filename)):
        return {"pattern": "silence", "display": "Silence", "name": "Silence"}
    
    # Handle other noise conditions - order matters here
    # Check "with_noise_random" before "with_noise" because it's more specific
    #if "with_noise_random" in filename:
    #    return {"pattern": "with_noise_random", "display": "Random Noise", "name": "Random Noise"}
    
    if "with_noise.mat" in filename:
        return {"pattern": "with_noise", "display": "Default Noise", "name": "Default Noise"}
    
    # Check SNR conditions
    for condition in NOISE_CONDITIONS:
        if condition["pattern"] in filename:
            return condition
    
    return None

def determine_auditory_condition(filename, source_type):
    """Determine if the file is from a healthy or ANSD condition."""
    if source_type.startswith("ansd"):
        return "ANSD"
    else:
        return "Healthy"

def collect_neurogram_data():
    """Scan through neurogram files from all sources to build analysis dataset."""
    print("Collecting data from neurogram files across all conditions...")
    
    data_records = []
    processed_count = 0
    
    for source_type, source_path in neurogram_paths.items():
        print(f"Processing neurograms from: {source_type}")
        
        if not os.path.exists(source_path):
            print(f"Warning: Path {source_path} does not exist. Skipping.")
            continue
        
        # Walk through the directory structure
        for root, dirs, files in os.walk(source_path):
            for file in files:
                if file.endswith('.mat'):
                    file_path = os.path.join(root, file)
                    
                    # Extract phoneme from filename
                    phoneme = extract_phoneme_from_filename(file)
                    if phoneme is None:
                        continue
                    
                    # Determine phoneme category
                    category = PHONEME_CATEGORY_MAP.get(phoneme, 'Other')
                    if category not in MAIN_CATEGORIES:
                        continue
                    
                    # Determine noise condition
                    noise_condition = extract_noise_condition(file)
                    if noise_condition is None:
                        continue
                    
                    # Determine auditory condition (Healthy or ANSD)
                    auditory_condition = determine_auditory_condition(file, source_type)
                    
                    try:
                        # Load the MAT file with scipy
                        mat_data = loadmat(file_path)
                        
                        perturbation_type = None
                        
                        # Check for perturbation_type (for ANSD_WithNoise)
                        if 'perturbation_type' in mat_data:
                            pert_type = mat_data['perturbation_type']
                            
                            # Convert to string if it's an array
                            if isinstance(pert_type, np.ndarray):
                                if pert_type.dtype.kind in ['S', 'U']:  # String types
                                    pert_type = str(pert_type[0])
                                else:
                                    pert_type = str(pert_type)
                            
                            perturbation_type = pert_type
                        
                        # Get neurogram data
                        if 'r_mean_downsampled' in mat_data:
                            neurogram = mat_data['r_mean_downsampled']
                            
                            # Get center frequencies if available
                            center_freqs = None
                            if 'center_frequencies' in mat_data:
                                center_freqs = mat_data['center_frequencies'].flatten()
                            
                            # Calculate mean energy
                            mean_energy = np.mean(neurogram)
                            
                            # Replace the existing band_energies calculation with:
                            band_energies = {
                                'low_freq_energy': np.mean(neurogram[:, FREQUENCY_BANDS[0]["start_idx"]:FREQUENCY_BANDS[0]["end_idx"]]),
                                'mid_freq_energy': np.mean(neurogram[:, FREQUENCY_BANDS[1]["start_idx"]:FREQUENCY_BANDS[1]["end_idx"]]),
                                'high_freq_energy': np.mean(neurogram[:, FREQUENCY_BANDS[2]["start_idx"]:FREQUENCY_BANDS[2]["end_idx"]])
                            }

                            # The frequency range verification can remain as is or be simplified:
                            if center_freqs is not None and len(center_freqs) > 0:
                                low_idx = np.where((center_freqs >= FREQUENCY_BANDS[0]["min"]) & 
                                                (center_freqs <= FREQUENCY_BANDS[0]["max"]))[0]
                                mid_idx = np.where((center_freqs >= FREQUENCY_BANDS[1]["min"]) & 
                                                (center_freqs <= FREQUENCY_BANDS[1]["max"]))[0]
                                high_idx = np.where((center_freqs >= FREQUENCY_BANDS[2]["min"]) & 
                                                    (center_freqs <= FREQUENCY_BANDS[2]["max"]))[0]
                                
                                # Optional: Add print statements for debugging
                                print(f"Low frequency indices: {low_idx}")
                                print(f"Mid frequency indices: {mid_idx}")
                                print(f"High frequency indices: {high_idx}")
                                
                                # Override band energies if needed
                                if len(low_idx) > 0:
                                    band_energies['low_freq_energy'] = np.mean(neurogram[:, low_idx])
                                if len(mid_idx) > 0:
                                    band_energies['mid_freq_energy'] = np.mean(neurogram[:, mid_idx])
                                if len(high_idx) > 0:
                                    band_energies['high_freq_energy'] = np.mean(neurogram[:, high_idx])
                            
                            # Add to records
                            record = {
                                'file': file,
                                'source': source_type,
                                'phoneme': phoneme,
                                'category': category,
                                'auditory_condition': auditory_condition,
                                'noise_condition': noise_condition["name"],
                                'noise_display': noise_condition["display"],
                                'noise_pattern': noise_condition["pattern"],
                                'mean_energy': mean_energy,
                                'low_freq_energy': band_energies['low_freq_energy'],
                                'mid_freq_energy': band_energies['mid_freq_energy'],
                                'high_freq_energy': band_energies['high_freq_energy']
                            }
                            
                            # Add perturbation type if available
                            if perturbation_type:
                                record['perturbation_type'] = perturbation_type
                            
                            data_records.append(record)
                            
                            processed_count += 1
                            if processed_count % 100 == 0:
                                print(f"Processed {processed_count} neurogram files...")
                    
                    except Exception as e:
                        print(f"Error processing {file}: {e}")
                        continue
    
    print(f"Successfully collected data from {processed_count} neurogram files")
    
    # Convert to DataFrame
    if data_records:
        df = pd.DataFrame(data_records)
        
        # Handle missing perturbation_type column
        if 'perturbation_type' not in df.columns:
            df['perturbation_type'] = np.nan
        
        df.to_csv(output_path / "all_neurogram_data_comprehensive.csv", index=False)
        print(f"Saved complete dataset to {output_path}/all_neurogram_data_comprehensive.csv")
        return df
    else:
        print("No data collected. Check if paths are correct.")
        return None


def analyze_by_auditory_and_noise_condition(df):
    """Improved visualization of neurograms by auditory condition and noise condition."""
    if df is None or df.empty:
        print("No data available for analysis.")
        return
    
    print("\nAnalyzing data by auditory condition and noise condition...")
    
    # Global plot styling
    plt.style.use('default')
    
    # 1. Heatmap of phoneme category × noise condition
    for auditory_condition in df['auditory_condition'].unique():
        # Filter for this auditory condition
        cond_df = df[df['auditory_condition'] == auditory_condition]
        
        # Create pivot table
        pivot_df = cond_df.pivot_table(
            index='category',
            columns='noise_display',
            values='mean_energy',
            aggfunc='mean'
        )
        
        # Reorder rows to match MAIN_CATEGORIES order
        ordered_rows = [cat for cat in MAIN_CATEGORIES if cat in pivot_df.index]
        pivot_df = pivot_df.reindex(ordered_rows)
        
        # Try to order columns by SNR level
        try:
            ordered_cols = [c["display"] for c in NOISE_CONDITIONS]
            pivot_df = pivot_df[[col for col in ordered_cols if col in pivot_df.columns]]
        except:
            pass
        
        # Create heatmap with improved aesthetics
        plt.figure(figsize=(16, 10))
        ax = sns.heatmap(
            pivot_df,
            cmap='YlGnBu',  # More color-blind friendly colormap
            annot=True,
            fmt='.2f',
            linewidths=0.5,
            cbar_kws={
                'label': 'Mean Energy',
                'shrink': 0.8
            },
            square=True  # Make cells square
        )
        plt.title(f"Mean Energy by Phoneme Category and Noise Condition\n{auditory_condition} Condition", 
                  fontsize=16, fontweight='bold', pad=20)
        plt.xlabel("Noise Condition", fontsize=12, labelpad=10)
        plt.ylabel("Phoneme Category", fontsize=12, labelpad=10)
        plt.tight_layout()
        plt.savefig(output_path / f"category_noise_{auditory_condition}.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Created heatmap for auditory condition: {auditory_condition}")
    
    # 2. Boxplots comparing Healthy vs ANSD for each noise condition
    for noise_cond in df['noise_display'].unique():
        # Filter for this noise condition
        noise_df = df[df['noise_display'] == noise_cond]
        
        plt.figure(figsize=(16, 10))
        ax = sns.boxplot(
            data=noise_df,
            x='category',
            y='mean_energy',
            hue='auditory_condition',
            palette='Set2',
            width=0.7
        )
        
        plt.title(f"Mean Energy by Phoneme Category - {noise_cond}", fontsize=16, fontweight='bold', pad=20)
        plt.xlabel("Phoneme Category", fontsize=12, labelpad=10)
        plt.ylabel("Mean Energy", fontsize=12, labelpad=10)
        plt.xticks(rotation=45, ha='right')
        
        # Improve legend
        plt.legend(
            title="Auditory Condition", 
            title_fontsize=12, 
            loc='best', 
            frameon=True, 
            framealpha=0.7
        )
        
        plt.tight_layout()
        plt.savefig(output_path / f"auditory_comparison_{noise_cond.replace(' ', '_')}.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Created boxplot comparing auditory conditions for noise: {noise_cond}")
    
    # 3. Facet grid showing noise effects
    plt.figure(figsize=(20, 15))
    g = sns.FacetGrid(
        df, 
        col="auditory_condition", 
        row="category", 
        height=4, 
        aspect=1.5, 
        margin_titles=True,
        despine=False
    )
    
    # Custom boxplot with improved aesthetics
    def custom_boxplot(x, y, **kwargs):
        sns.boxplot(x=x, y=y, **kwargs)
    
    g.map_dataframe(
        custom_boxplot, 
        x="noise_display", 
        y="mean_energy", 
        palette="Set2", 
        width=0.7
    )
    
    # Customize the plot
    g.set_xticklabels(rotation=45, ha='right')
    g.set_axis_labels("Noise Condition", "Mean Energy")
    g.fig.suptitle("Effect of Noise Conditions Across Phoneme Categories", y=1.02, fontsize=16)
    
    # Add a tight legend
    g.add_legend(title="Noise Condition", bbox_to_anchor=(1.05, 1), loc='upper left')
    
    plt.tight_layout()
    plt.savefig(output_path / "facet_noise_category_auditory.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    print("Created improved facet grid for noise effects")
    
    # 4. Frequency band analysis with improved aesthetics
    for band in ['low_freq_energy', 'mid_freq_energy', 'high_freq_energy']:
        plt.figure(figsize=(18, 10))
        ax = sns.boxplot(
            data=df, 
            x="noise_display", 
            y=band, 
            hue="auditory_condition", 
            palette="Set2",
            width=0.7
        )
        
        band_name = band.replace('_freq_energy', '').capitalize() + ' Frequency'
        plt.title(f"{band_name} Band Energy Across Conditions", fontsize=16, fontweight='bold', pad=20)
        plt.xlabel("Noise Condition", fontsize=12, labelpad=10)
        plt.ylabel(f"{band_name} Energy", fontsize=12, labelpad=10)
        plt.xticks(rotation=45, ha='right')
        
        # Improved legend
        plt.legend(
            title="Auditory Condition", 
            title_fontsize=12, 
            loc='best', 
            frameon=True, 
            framealpha=0.7
        )
        
        plt.tight_layout()
        plt.savefig(output_path / f"{band}_by_auditory.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Created {band_name} band comparison")

def analyze_by_perturbation_type(df):
    """
    Comprehensive analysis of ANSD perturbation types 
    Compares healthy and ANSD conditions across different noise levels and perturbation types
    """
    # Check if perturbation_type column exists and has data
    if 'perturbation_type' not in df.columns or df['perturbation_type'].isna().all():
        print("No perturbation type data available for analysis.")
        return
    
    # Get unique noise conditions
    noise_conditions = df['noise_display'].unique()
    
    # Separate ANSD dataframe for specific analyses
    ansd_df = df[df['auditory_condition'] == 'ANSD']
    
    # 1. Comprehensive Comparison Boxplots
    plt.figure(figsize=(20, 15))
    
    # Create a grid of subplots for each noise condition
    for i, noise_cond in enumerate(noise_conditions, 1):
        plt.subplot(len(noise_conditions), 1, i)
        
        # Prepare data for this noise condition
        noise_df = df[df['noise_display'] == noise_cond]
        
        # Create boxplot using matplotlib directly
        plt.boxplot(
            [noise_df[noise_df['auditory_condition'] == condition]['mean_energy'] 
             for condition in ['Healthy', 'ANSD']],
            labels=['Healthy', 'ANSD']
        )
        
        plt.title(f'Mean Energy Comparison - {noise_cond}')
        plt.xlabel('Auditory Condition')
        plt.ylabel('Mean Energy')
    
    plt.tight_layout()
    plt.savefig(output_path / 'comprehensive_perturbation_comparison.png', dpi=300)
    plt.close()
    
    # 2. Detailed Phoneme Category Analysis
    plt.figure(figsize=(20, 15))
    
    # Unique phoneme categories
    categories = df['category'].unique()
    
    for i, category in enumerate(categories, 1):
        plt.subplot(len(categories), 1, i)
        
        # Filter for specific category in ANSD
        cat_df = ansd_df[ansd_df['category'] == category]
        
        # Boxplot of perturbation types
        sns.boxplot(
            x='perturbation_type', 
            y='mean_energy', 
            data=cat_df,
            palette='viridis'
        )
        
        plt.title(f'Perturbation Effects on {category} Phonemes')
        plt.xlabel('Perturbation Type')
        plt.ylabel('Mean Energy')
        plt.xticks(rotation=45)
    
    plt.tight_layout()
    plt.savefig(output_path / 'phoneme_category_perturbation.png', dpi=300)
    plt.close()
    
    # 3. Frequency Band Analysis for Perturbations
    freq_bands = ['low_freq_energy', 'mid_freq_energy', 'high_freq_energy']
    
    for band in freq_bands:
        plt.figure(figsize=(15, 10))
        
        # Boxplot of frequency band energy across perturbation types
        sns.boxplot(
            x='perturbation_type', 
            y=band, 
            data=ansd_df,
            palette='Set2'
        )
        
        plt.title(f'{band.replace("_", " ").title()} Energy by Perturbation Type')
        plt.xlabel('Perturbation Type')
        plt.ylabel('Frequency Band Energy')
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.savefig(output_path / f'{band}_perturbation_analysis.png', dpi=300)
        plt.close()
    
    # 4. Statistical Summary
    # Create a comprehensive summary of perturbation effects
    summary_stats = []
    
    for noise_cond in noise_conditions:
        for perturbation in ansd_df['perturbation_type'].unique():
            # Filter data
            pert_noise_df = ansd_df[
                (ansd_df['noise_display'] == noise_cond) & 
                (ansd_df['perturbation_type'] == perturbation)
            ]
            
            # Calculate summary statistics
            summary = {
                'Noise Condition': noise_cond,
                'Perturbation Type': perturbation,
                'Mean Energy': pert_noise_df['mean_energy'].mean(),
                'Std Energy': pert_noise_df['mean_energy'].std(),
                'Median Energy': pert_noise_df['mean_energy'].median()
            }
            
            # Add category-wise breakdown
            for category in categories:
                cat_df = pert_noise_df[pert_noise_df['category'] == category]
                summary[f'{category}_Mean'] = cat_df['mean_energy'].mean()
            
            summary_stats.append(summary)
    
    # Convert to DataFrame and save
    summary_df = pd.DataFrame(summary_stats)
    summary_df.to_csv(output_path / 'perturbation_summary_statistics.csv', index=False)
    
    print("Completed comprehensive perturbation type analysis")

def create_summary_statistics(df):
    """Create summary statistics for the whole dataset."""
    if df is None or df.empty:
        print("No data available for summary statistics.")
        return
    
    print("\nGenerating summary statistics...")
    
    # 1. Create summary by auditory condition and noise condition
    summary_by_cond = df.groupby(['auditory_condition', 'noise_display'])['mean_energy'].agg(
        ['mean', 'std', 'min', 'max', 'count']).reset_index()
    summary_by_cond.to_csv(output_path / "summary_by_condition.csv", index=False)
    
    # 2. Create summary by phoneme category
    summary_by_category = df.groupby(['auditory_condition', 'category'])['mean_energy'].agg(
        ['mean', 'std', 'min', 'max', 'count']).reset_index()
    summary_by_category.to_csv(output_path / "summary_by_category.csv", index=False)
    
    # 3. Create frequency band summary
    freq_bands = ['low_freq_energy', 'mid_freq_energy', 'high_freq_energy']
    summary_by_freq = pd.DataFrame()
    
    for band in freq_bands:
        band_summary = df.groupby(['auditory_condition', 'noise_display'])[band].agg(
            ['mean', 'std']).reset_index()
        band_summary['frequency_band'] = band.replace('_freq_energy', '')
        summary_by_freq = pd.concat([summary_by_freq, band_summary])
    
    summary_by_freq.to_csv(output_path / "summary_by_frequency.csv", index=False)
    
    # 4. Calculate differences between healthy and ANSD
    healthy_df = df[df['auditory_condition'] == 'Healthy']
    ansd_df = df[df['auditory_condition'] == 'ANSD']
    
    # Create pivot tables for healthy and ANSD
    healthy_pivot = healthy_df.pivot_table(
        index='category',
        columns='noise_display',
        values='mean_energy',
        aggfunc='mean'
    ).fillna(0)  # Replace NaN with 0
    
    ansd_pivot = ansd_df.pivot_table(
        index='category',
        columns='noise_display',
        values='mean_energy',
        aggfunc='mean'
    ).fillna(0)  # Replace NaN with 0
    
    # Calculate differences where categories and noise conditions match
    common_categories = list(set(healthy_pivot.index) & set(ansd_pivot.index))
    common_noise = list(set(healthy_pivot.columns) & set(ansd_pivot.columns))
    
    if common_categories and common_noise:
        # Create difference pivot table with numeric data
        diff_pivot = pd.DataFrame(index=common_categories, columns=common_noise, dtype=float)
        
        for cat in common_categories:
            for noise in common_noise:
                healthy_val = healthy_pivot.loc[cat, noise]
                ansd_val = ansd_pivot.loc[cat, noise]
                diff_pivot.loc[cat, noise] = float(ansd_val - healthy_val)
        
        # Calculate percentage differences
        pct_diff_pivot = pd.DataFrame(index=common_categories, columns=common_noise, dtype=float)
        
        for cat in common_categories:
            for noise in common_noise:
                healthy_val = healthy_pivot.loc[cat, noise]
                if healthy_val != 0:
                    diff_val = diff_pivot.loc[cat, noise]
                    pct_diff_pivot.loc[cat, noise] = float((diff_val / healthy_val) * 100)
                else:
                    pct_diff_pivot.loc[cat, noise] = 0.0
        
        # Save difference tables
        diff_pivot.to_csv(output_path / "difference_healthy_ansd.csv")
        pct_diff_pivot.to_csv(output_path / "percent_difference_healthy_ansd.csv")
        
        # Create improved heatmap of differences
        plt.figure(figsize=(16, 10))
        sns.heatmap(
            diff_pivot,
            cmap='RdBu_r',
            annot=True,
            fmt='.2f',
            center=0,
            cbar_kws={'label': 'Mean Energy Difference (ANSD - Healthy)'},
            square=True,
            linewidths=0.5,
            cbar=True
        )
        plt.title("Mean Energy Difference: ANSD vs Healthy", fontsize=16, fontweight='bold')
        plt.xlabel("Noise Condition", fontsize=12)
        plt.ylabel("Phoneme Category", fontsize=12)
        plt.tight_layout()
        plt.savefig(output_path / "heatmap_difference.png", dpi=300, bbox_inches='tight')
        plt.close()
        
        # Create improved heatmap of percentage differences
        plt.figure(figsize=(16, 10))
        sns.heatmap(
            pct_diff_pivot,
            cmap='RdBu_r',
            annot=True,
            fmt='.2f',
            center=0,
            cbar_kws={'label': 'Percent Difference (%)'},
            square=True,
            linewidths=0.5,
            cbar=True
        )
        plt.title("Percent Difference in Mean Energy: ANSD vs Healthy", fontsize=16, fontweight='bold')
        plt.xlabel("Noise Condition", fontsize=12)
        plt.ylabel("Phoneme Category", fontsize=12)
        plt.tight_layout()
        plt.savefig(output_path / "heatmap_percent_difference.png", dpi=300, bbox_inches='tight')
        plt.close()
    
    print("Generated summary statistics")

def main():
    print("Starting comprehensive neurogram analysis...")
    
    # Collect data from all neurogram files
    neurogram_data = collect_neurogram_data()
    
    if neurogram_data is not None and not neurogram_data.empty:
        # Analyze by auditory and noise condition
        analyze_by_auditory_and_noise_condition(neurogram_data)
        
        # Analyze by perturbation type (for ANSD with noise data)
        analyze_by_perturbation_type(neurogram_data)
        
        # Create summary statistics
        create_summary_statistics(neurogram_data)
        
        print(f"\nAnalysis complete! Results saved to {output_path}")
    else:
        print("No data available for analysis. Check if paths are correct.")
# %%
if __name__ == "__main__":
    main()

# %%    