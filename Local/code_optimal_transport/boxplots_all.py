# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import pickle
from pathlib import Path
from matplotlib.gridspec import GridSpec
# %%
# Set the style for plots
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_context("paper", font_scale=1.4)

# Define paths to the results folders
base_path = Path("/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/OT_SELECT")
result_folders = {
    "Healthy": base_path / "SELECT_F_vs_Neuro_Results",
    "Healthy_Noise": base_path / "SELECT_F_vs_Neuro_Noise_Results",
    "ANSD": base_path / "SELECT_F_vs_Neuro_ANSD_Results",
    "ANSD_Noise": base_path / "SELECT_F_vs_Neuro_ANSD_Noise_Results"
}

# Define output path for new visualizations
output_path = base_path / "Boxplot_Comparisons"
os.makedirs(output_path, exist_ok=True)

# Define common phoneme categories to analyze
phoneme_categories = ["Vowel", "Fricative", "Stop", "Nasal", "Liquid", "Glide", "Affricate"]

# Define formants to analyze
formants = ["F1", "F2", "F3"]

# Define SNR levels to look for
snr_levels = ["snr-5.0", "snr0.0", "snr5.0", "snr10.0", "snr15.0", "default", "random"]
# %%
# Function to load pickle files
def load_pickle(file_path):
    try:
        with open(file_path, 'rb') as f:
            return pickle.load(f)
    except Exception as e:
        print(f"Error loading {file_path}: {e}")
        return None

# Function to load all distance data from a condition folder
def load_condition_data(folder_path, condition_name):
    all_data = []
    
    # For healthy with noise and ANSD with noise, we need to handle multiple noise types
    if "Noise" in condition_name:
        # First check for individual SNR level files
        main_group = "Healthy" if "Healthy" in condition_name else "ANSD"
        
        for snr in snr_levels:
            # Try different possible file naming patterns
            possible_files = [
                folder_path / f"formant_cf_distances_{snr}_noisy.pkl",
                folder_path / f"formant_cf_distances_{snr}_ansd.pkl",
                folder_path / f"formant_cf_distances_{snr}.pkl"
            ]
            
            for file_path in possible_files:
                if file_path.exists():
                    print(f"  - Found file: {file_path}")
                    data = load_pickle(file_path)
                    if data is not None:
                        # Add condition and group info
                        data["Group"] = main_group
                        data["NoiseLevel"] = snr
                        # Save the original condition name to preserve it
                        data["OriginalCondition"] = snr
                        data["Condition"] = f"{main_group} {snr}"
                        all_data.append(data)
                        print(f"  - Loaded {len(data)} rows with NoiseLevel={snr}")
                    break  # Found a matching file, move to next SNR
        
        # If no individual files found, try the combined file
        if not all_data:
            combined_files = [
                folder_path / "formant_cf_distances_all_combined.pkl",
                folder_path / "formant_cf_distances_all_combined_ansd.pkl",
                folder_path / "formant_cf_distances_all_noisy.pkl",
                folder_path / "formant_cf_distances_all_ansd.pkl"
            ]
            
            for file_path in combined_files:
                if file_path.exists():
                    print(f"  - Found combined file: {file_path}")
                    data = load_pickle(file_path)
                    if data is not None:
                        # Add group info
                        data["Group"] = main_group
                        
                        # Extract noise level if available
                        if "NoiseType" in data.columns:
                            # Use existing NoiseType column
                            data["NoiseLevel"] = data["NoiseType"]
                            # Save the original condition name
                            data["OriginalCondition"] = data["NoiseType"]
                        else:
                            # Default to "combined" if no noise level info
                            data["NoiseLevel"] = "combined"
                            data["OriginalCondition"] = "combined"
                        
                        data["Condition"] = data.apply(
                            lambda row: f"{main_group} {row['NoiseLevel']}", axis=1
                        )
                        all_data.append(data)
                    break  # Found a matching file
    else:
        # For conditions without noise (silence)
        main_group = "Healthy" if "Healthy" in condition_name else "ANSD"
        
        # Try different file naming patterns
        possible_files = [
            folder_path / "formant_cf_distances.pkl",
            folder_path / "formant_cf_distances_ansd.pkl"
        ]
        
        for file_path in possible_files:
            if file_path.exists():
                print(f"  - Found file: {file_path}")
                data = load_pickle(file_path)
                if data is not None:
                    # Add condition and group info
                    data["Group"] = main_group
                    data["NoiseLevel"] = "Silence"
                    data["OriginalCondition"] = "Silence"
                    data["Condition"] = f"{main_group} Silence"
                    all_data.append(data)
                    break  # Found a matching file
    
    # Combine all data
    if all_data:
        combined_data = pd.concat(all_data, ignore_index=True)
        print(f"  - Combined data has {len(combined_data)} rows")
        return combined_data
    return None

# Load data from all conditions
print("Loading data from all conditions...")
all_conditions_data = []

for condition_name, folder_path in result_folders.items():
    print(f"Loading {condition_name} data from {folder_path}")
    condition_data = load_condition_data(folder_path, condition_name)
    if condition_data is not None and not condition_data.empty:
        all_conditions_data.append(condition_data)
        print(f"  - Loaded {len(condition_data)} data points")
    else:
        print(f"  - No data found or error loading data")

# Combine all data into a single DataFrame
if all_conditions_data:
    all_data = pd.concat(all_conditions_data, ignore_index=True)
    print(f"Combined dataset has {len(all_data)} rows")
    
    # Clean and standardize data
    # Extract CF numbers
    all_data['CF_Num'] = all_data['CF'].str.extract(r'CF(\d+)').astype(int)
    
    # Make sure SNR values are consistently formatted
def clean_snr(snr, group=None):
    """
    Clean and standardize the noise level labels, ensuring consistent naming
    for baseline conditions in both ANSD and Healthy cases.
    
    Parameters:
    snr (str): The noise level/type value
    group (str): The group (Healthy or ANSD) - helps with ambiguous noise types
    
    Returns:
    str: Standardized noise level name
    """
    if pd.isna(snr) or str(snr).lower() == 'silence':
        return "Silence"
        
    # Convert to lowercase string for comparison
    snr_str = str(snr).lower()
    
    # Handle the different baseline condition names - renamed to Random Noise
    if snr_str == 'default' or (snr_str == 'all' and group == 'ANSD'):
        return "Random Noise"  # Changed from "Baseline (ANSD)"
    if snr_str == 'random' or (snr_str == 'all' and group == 'Healthy'):
        return "Random Noise"  # Changed from "Baseline (Healthy)" 
    if snr_str == 'all' and group is None:
        # Without group info, can't determine which baseline
        return "Random Noise"  # Changed from "Baseline"
        
    if 'snr' in snr_str:
        # Extract just the numeric part if it's a full SNR string
        snr_val = snr_str.replace('snr', '')
        # Add prefix only if it doesn't already have it
        return f"SNR {snr_val}"
    
    return str(snr)

# Modified code for when all_data is loaded and standardized
# This should be inserted where you process the combined data
if all_conditions_data:
    all_data = pd.concat(all_conditions_data, ignore_index=True)
    print(f"Combined dataset has {len(all_data)} rows")
    
    # Print unique noise levels and conditions to debug
    print("Unique NoiseLevel values before cleaning:")
    print(all_data['NoiseLevel'].unique())
    
    # Clean and standardize data
    # Extract CF numbers
    all_data['CF_Num'] = all_data['CF'].str.extract(r'CF(\d+)').astype(int)
    
    # Save original condition before cleaning for reference
    if 'OriginalCondition' not in all_data.columns:
        all_data['OriginalCondition'] = all_data['NoiseLevel']
    
    # Standardize noise levels, passing group information to help disambiguate
    all_data['NoiseLevel'] = all_data.apply(
        lambda row: clean_snr(row['NoiseLevel'], row['Group']), axis=1
    )
    
    # Update Condition with standardized noise level
    all_data['Condition'] = all_data.apply(
        lambda row: f"{row['Group']} {row['NoiseLevel']}", axis=1
    )
    
    # Print unique values after cleaning to verify
    print("Unique NoiseLevel values after cleaning:")
    print(all_data['NoiseLevel'].unique())
    print("Unique Condition values:")
    print(all_data['Condition'].unique())
    
    # Order the noise levels from best to worst SNR
    snr_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
    all_data['NoiseLevel'] = pd.Categorical(
        all_data['NoiseLevel'],
        categories=snr_order,
        ordered=True
    )
    
    # Save the combined data for future use
    all_data.to_pickle(output_path / "all_ot_distances_combined.pkl")
else:
    print("No data loaded. Please check the file paths.")
    exit(1)

# Create compact visualization with all formants side by side
def create_compact_boxplots_by_formant():
    print("Creating compact boxplots by formant...")
    
    # Filter to include only the common categories and ensure we have all formants
    filtered_data = all_data[all_data['Category'].isin(phoneme_categories)]
    
    # Create a publication-quality figure layout with reduced height
    fig = plt.figure(figsize=(22, 16))  # Reduced height to minimize empty space
    
    # Create a special layout with less space for the legend at the bottom
    gs = GridSpec(4, 3, figure=fig, height_ratios=[10, 10, 10, 2], width_ratios=[1, 1, 1])
    
    # Define noise levels in order from most noisy to least noisy
    noise_levels = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
    
    # Special color scheme
    cmap = plt.cm.viridis
    noise_colors = cmap(np.linspace(0, 1, len(noise_levels)))
    
    # Create a noise palette mapping each noise level to a color
    noise_palette = {}
    for i, level in enumerate(noise_levels):
        noise_palette[level] = noise_colors[i]
    
    # Create a condition-to-color mapping to ensure consistent colors
    condition_palette = {}
    for condition in filtered_data['Condition'].unique():
        # Extract the noise level from the condition (after the group name)
        parts = condition.split(' ', 1)
        if len(parts) > 1:
            noise_level = parts[1]
            if noise_level in noise_palette:
                condition_palette[condition] = noise_palette[noise_level]
    
    # Force the ordering of conditions in the legend by group first
    # First all Healthy conditions in specified noise order, then all ANSD conditions
    condition_order = []
    
    # First add all Healthy conditions in the specified noise order
    for noise in noise_levels:
        condition = f"Healthy {noise}"
        if condition in filtered_data['Condition'].unique():
            condition_order.append(condition)
    
    # Then add all ANSD conditions in the specified noise order
    for noise in noise_levels:
        condition = f"ANSD {noise}"
        if condition in filtered_data['Condition'].unique():
            condition_order.append(condition)
    
    # Create separate panels for each formant in a 3x1 grid (vertical arrangement)
    for i, formant in enumerate(formants):
        # Create subplot in the ith row
        ax = fig.add_subplot(gs[i, :])
        
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        # Create enhanced box plot with publication-quality styling
        # Use hue_order to ensure consistent legend ordering
        box_plot = sns.boxplot(
            x='Category',
            y='GW_Distance',
            hue='Condition',
            hue_order=condition_order,  # Use our custom order - all Healthy then all ANSD
            data=formant_data,
            ax=ax,
            palette=condition_palette,  # Use our custom palette
            width=0.8,
            fliersize=2,
            linewidth=1.2,
            saturation=0.9,
            showmeans=True,
            meanprops={"marker":"o", "markerfacecolor":"white", "markeredgecolor":"black", "markersize":"4"}
        )
        
        # Add a subtle grid for better readability
        ax.grid(axis='y', linestyle='--', alpha=0.3, zorder=0)
        
        # Add a light background to the plot area for better contrast
        ax.set_facecolor('#f8f9fa')  # Very light gray
        
        # Customize the subplot with publication-ready styling
        ax.set_title(f'{formant} to CF Distances', fontsize=16, fontweight='bold')
        ax.set_xlabel('')  # Remove x-label as it will be shared
        ax.tick_params(axis='x', labelsize=12)
        ax.tick_params(axis='y', labelsize=12)
        
        # Properly set x-tick labels with rotation - avoid warnings
        ticks = ax.get_xticks()
        ax.set_xticks(ticks)  # Explicitly set the ticks to fix warning
        ax.set_xticklabels(ax.get_xticklabels(), rotation=45, ha='right')
        
        # Add y-label with clear formatting
        ax.set_ylabel('GW Distance', fontsize=14, fontweight='bold')
        
        # Remove legend from individual panels
        ax.get_legend().remove()
        
        # Add subtle border around the plot
        for spine in ax.spines.values():
            spine.set_linewidth(1.2)
            spine.set_color('#333333')
    
    # Add a shared x-axis label at the bottom, positioned much closer to the plot
    fig.text(0.5, 0.04, 'Phoneme Category', ha='center', fontsize=16, fontweight='bold')
    
    # Get the legend handles and labels from the last plot
    handles, labels = ax.get_legend_handles_labels()
    
    # Create a separate axis for the legend in the fourth row
    legend_ax = fig.add_subplot(gs[3, :])
    legend_ax.axis('off')  # Hide the axis
    
    # Calculate how many items per row - this is all noise levels for one group
    num_noise_per_group = sum(1 for c in filtered_data['Condition'].unique() if c.startswith('Healthy'))
    
    # Create a beautiful legend with custom styling at the bottom
    # Two rows: first all Healthy, then all ANSD
    legend = legend_ax.legend(
        handles, 
        labels, 
        loc='center', 
        ncol=num_noise_per_group,  # One column per noise level in a group
        title='Condition', 
        fontsize=13,
        title_fontsize=16,
        frameon=True,
        framealpha=0.95,
        fancybox=True,
        shadow=True,
        borderpad=1,
        labelspacing=1.2,
        handletextpad=0.8
    )
    
    # Add a subtle background to the entire figure
    fig.patch.set_facecolor('#ffffff')
    
    # Reduce the bottom margin
    plt.tight_layout()
    plt.subplots_adjust(bottom=0.15, hspace=0.4)  # Reduced bottom margin
    
    # Save as high-resolution image
    plt.savefig(output_path / 'compact_boxplots_by_formant.png', dpi=400, bbox_inches='tight')
    
    # Also save as PDF for publication purposes
    plt.savefig(output_path / 'compact_boxplots_by_formant.pdf', format='pdf', bbox_inches='tight')
    
    plt.close()

# Create a unified visualization comparing healthy vs ANSD across phoneme types
def create_health_vs_ansd_comparison():
    print("Creating Healthy vs ANSD comparison...")
    
    # Filter to include only the common categories
    filtered_data = all_data[all_data['Category'].isin(phoneme_categories)]
    
    # Create separate plots for silence and each noise level
    noise_levels = sorted(filtered_data['NoiseLevel'].unique())
    
    for noise_level in noise_levels:
        # Filter data for this noise level
        noise_data = filtered_data[filtered_data['NoiseLevel'] == noise_level]
        
        if len(noise_data) == 0:
            continue
            
        fig = plt.figure(figsize=(20, 15))
        gs = GridSpec(3, 1, figure=fig, height_ratios=[1, 1, 1])
        
        # Create a subplot for each formant
        for i, formant in enumerate(formants):
            ax = fig.add_subplot(gs[i, 0])
            
            formant_data = noise_data[noise_data['Formant'] == formant]
            
            # Create box plot
            sns.boxplot(
                x='Category',
                y='GW_Distance',
                hue='Group',
                data=formant_data,
                ax=ax,
                palette=['#1f77b4', '#ff7f0e'],  # Blue for Healthy, Orange for ANSD
                fliersize=2
            )
            
            # Customize the subplot
            ax.set_title(f'{formant} to CF Distances - {noise_level}', fontsize=14)
            ax.set_xlabel('Phoneme Category', fontsize=12)
            ax.set_xticklabels(ax.get_xticklabels(), rotation=45, ha='right')
            ax.set_ylabel('GW Distance', fontsize=12)
            
            # Add a legend
            handles, labels = ax.get_legend_handles_labels()
            ax.legend(handles, labels, title='Group', fontsize=12)
            
        plt.tight_layout()
        plt.savefig(output_path / f'health_vs_ansd_{noise_level.replace(" ", "_")}.png', dpi=300)
        plt.close()

# Create a visualization with CF on x-axis, comparing Healthy vs ANSD
def create_cf_comparison():
    print("Creating center frequency comparison...")
    
    # Filter to include only the common categories
    filtered_data = all_data[all_data['Category'].isin(phoneme_categories)]
    
    # Create separate plots for each phoneme category
    for category in phoneme_categories:
        category_data = filtered_data[filtered_data['Category'] == category]
        
        if len(category_data) == 0:
            continue
            
        # Create a figure with three panels (one for each formant)
        fig = plt.figure(figsize=(20, 15))
        gs = GridSpec(3, 1, figure=fig, height_ratios=[1, 1, 1])
        
        # Create a subplot for each formant
        for i, formant in enumerate(formants):
            ax = fig.add_subplot(gs[i, 0])
            
            formant_data = category_data[category_data['Formant'] == formant]
            
            # Create box plot with CFs on x-axis
            sns.boxplot(
                x='CF_Num',
                y='GW_Distance',
                hue='Group',
                data=formant_data,
                ax=ax,
                palette=['#1f77b4', '#ff7f0e'],  # Blue for Healthy, Orange for ANSD
                fliersize=2
            )
            
            # Customize the subplot
            ax.set_title(f'{formant} Distances by Center Frequency - {category}', fontsize=14)
            ax.set_xlabel('Center Frequency Number', fontsize=12)
            ax.set_ylabel('GW Distance', fontsize=12)
            
            # Add actual frequency values to the x-tick labels - fix the warning
            ticks = ax.get_xticks()  # Get the current tick locations
            if len(ticks) > 0:  # Only proceed if we have ticks
                # Get current tick positions and create labels for them
                cf_numbers = sorted(formant_data['CF_Num'].unique())
                
                if len(cf_numbers) > 0:  # Only proceed if we have data
                    # Set explicit tick positions and labels
                    ax.set_xticks(range(len(cf_numbers)))  # Set positions
                    
                    # Create labels with CF number and Hz value
                    cf_labels = []
                    for n in cf_numbers:
                        if n-1 < len(TARGET_FREQUENCIES):
                            cf_labels.append(f'CF{n}\n({TARGET_FREQUENCIES[n-1]} Hz)')
                        else:
                            cf_labels.append(f'CF{n}')
                    
                    # Apply the labels
                    ax.set_xticklabels(cf_labels)
            
            # Add a legend
            handles, labels = ax.get_legend_handles_labels()
            ax.legend(handles, labels, title='Group', fontsize=12)
            
        plt.tight_layout()
        plt.savefig(output_path / f'cf_comparison_{category}.png', dpi=300)
        plt.close()

# Create a comprehensive visualization with all conditions together
def create_comprehensive_visualization():
    print("Creating comprehensive visualization...")
    
    # Filter to include only the common categories
    filtered_data = all_data[all_data['Category'].isin(phoneme_categories)]
    
    # Create separate plots for each formant
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        # Create a single figure
        plt.figure(figsize=(18, 10))
        
        # Create box plot with all conditions
        g = sns.boxplot(
            x='Category',
            y='GW_Distance',
            hue='Condition',
            data=formant_data,
            palette='viridis',
            fliersize=1.5
        )
        
        # Customize the plot
        plt.title(f'{formant} GW Distances Across All Conditions', fontsize=16)
        plt.xlabel('Phoneme Category', fontsize=14)
        plt.ylabel('GW Distance', fontsize=14)
        plt.xticks(rotation=45, ha='right')
        
        # Adjust the legend (it will be large)
        plt.legend(title='Condition', bbox_to_anchor=(1.05, 1), loc='upper left')
        
        plt.tight_layout()
        plt.savefig(output_path / f'comprehensive_{formant}.png', dpi=300)
        plt.close()

# Create a noise effect visualization
def create_noise_effect_visualization():
    print("Creating noise effect visualization...")
    
    # Create a publication-quality figure with vertical arrangement
    fig = plt.figure(figsize=(20, 22))
    
    # Create a grid layout with dedicated space for the legend at the bottom
    gs = GridSpec(7, 2, figure=fig, height_ratios=[10, 10, 10, 10, 10, 10, 2.5], width_ratios=[1, 1])
    
    # Define a beautiful color palette for noise levels
    # Use a perceptually uniform colormap that's colorblind friendly
    noise_unique = sorted(all_data['NoiseLevel'].unique())
    
    # Special color scheme
    cmap = plt.cm.plasma
    noise_colors = cmap(np.linspace(0, 1, len(snr_order)))
    
    # Create a noise palette mapping each noise level to a color
    noise_palette = {}
    for i, level in enumerate(snr_order):
        if level in noise_unique:
            noise_palette[level] = noise_colors[i]
    
    # Process each formant in rows - each formant gets two rows (one for each group)
    for i, formant in enumerate(formants):
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Row 1: Healthy
        ax_healthy = fig.add_subplot(gs[i*2, :])
        healthy_data = formant_data[formant_data['Group'] == 'Healthy']
        
        sns.boxplot(
            x='Category', 
            y='GW_Distance',
            hue='NoiseLevel',
            hue_order=snr_order,  # Use the updated order
            data=healthy_data,
            ax=ax_healthy,
            palette=noise_palette,
            width=0.8,
            fliersize=2,
            linewidth=1.2,
            saturation=0.9,
            showmeans=True,
            meanprops={"marker":"o", "markerfacecolor":"white", "markeredgecolor":"black", "markersize":"4"}
        )
        
        # Add a subtle grid and styling
        ax_healthy.grid(axis='y', linestyle='--', alpha=0.3, zorder=0)
        ax_healthy.set_facecolor('#f8f9fa')
        
        # Customize the panel
        ax_healthy.set_title(f'{formant} - Healthy', fontsize=16, fontweight='bold')
        ax_healthy.set_xlabel('')  # Remove x-label for shared axis
        ax_healthy.set_ylabel('GW Distance', fontsize=14, fontweight='bold')
        
        # Remove legend
        ax_healthy.get_legend().remove()
        
        # Add subtle border
        for spine in ax_healthy.spines.values():
            spine.set_linewidth(1.2)
            spine.set_color('#333333')
        
        # Row 2: ANSD
        ax_ansd = fig.add_subplot(gs[i*2+1, :])
        ansd_data = formant_data[formant_data['Group'] == 'ANSD']
        
        sns.boxplot(
            x='Category', 
            y='GW_Distance',
            hue='NoiseLevel',
            hue_order=snr_order,  # Use the updated order
            data=ansd_data,
            ax=ax_ansd,
            palette=noise_palette,
            width=0.8,
            fliersize=2,
            linewidth=1.2,
            saturation=0.9,
            showmeans=True,
            meanprops={"marker":"o", "markerfacecolor":"white", "markeredgecolor":"black", "markersize":"4"}
        )
        
        # Add a subtle grid and styling
        ax_ansd.grid(axis='y', linestyle='--', alpha=0.3, zorder=0)
        ax_ansd.set_facecolor('#f8f9fa')
        
        # Customize the panel
        ax_ansd.set_title(f'{formant} - ANSD', fontsize=16, fontweight='bold')
        ax_ansd.set_xlabel('')  # Remove x-label for shared axis
        ax_ansd.set_ylabel('GW Distance', fontsize=14, fontweight='bold')
        
        # Remove legend
        ax_ansd.get_legend().remove()
        
        # Add subtle border
        for spine in ax_ansd.spines.values():
            spine.set_linewidth(1.2)
            spine.set_color('#333333')
    
    # Add a shared x-axis label
    fig.text(0.5, 0.02, 'Phoneme Category', ha='center', fontsize=16, fontweight='bold')
    
    # Get legend handles from the last plot
    handles, labels = ax_ansd.get_legend_handles_labels()
    
    # Create a subplot for the shared legend at the bottom
    legend_ax = fig.add_subplot(gs[6, :])
    legend_ax.axis('off')  # Hide the axis
    
    # Add a beautiful legend
    legend = legend_ax.legend(
        handles,
        labels,
        loc='center',
        ncol=4,  # Adjust number of columns based on your noise levels
        title='Noise Level',
        fontsize=13,
        title_fontsize=16,
        frameon=True,
        framealpha=0.95,
        fancybox=True,
        shadow=True,
        borderpad=1,
        labelspacing=1.2,
        handletextpad=0.8
    )
    
    # Add a subtle background to the entire figure
    fig.patch.set_facecolor('#ffffff')
    
    plt.tight_layout()
    plt.subplots_adjust(bottom=0.08, hspace=0.4)  # Adjust spacing
    
    # Save high-resolution version
    plt.savefig(output_path / 'noise_effect_comparison.png', dpi=400, bbox_inches='tight')
    
    # Also save PDF for publication
    plt.savefig(output_path / 'noise_effect_comparison.pdf', format='pdf', bbox_inches='tight')
    
    plt.close()
# %%
# Execute all visualization functions
# Add a target frequencies constant for CF labels
TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz

create_compact_boxplots_by_formant()
create_health_vs_ansd_comparison()
create_cf_comparison()
create_comprehensive_visualization()
create_noise_effect_visualization()

print(f"All visualizations have been saved to {output_path}")

# %%