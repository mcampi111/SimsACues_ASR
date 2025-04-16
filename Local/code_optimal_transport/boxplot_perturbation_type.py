# %%
import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import pickle
import traceback
from pathlib import Path
from matplotlib.gridspec import GridSpec

# %%
# Set the style for plots
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_context("paper", font_scale=1.4)

# Define paths to the results folders
base_path = Path("/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/OT_SELECT")
result_folder = base_path / "ANSD_OT_Perturbation_Results"

# Define output path for new visualizations
output_path = base_path / "Perturbation_Visualizations"
os.makedirs(output_path, exist_ok=True)

# Define common phoneme categories to analyze
phoneme_categories = ["Vowel", "Fricative", "Stop", "Nasal", "Liquid", "Glide", "Affricate"]

# Define formants to analyze
formants = ["F1", "F2", "F3"]

# Define perturbation types to look for (based on your logs)
perturbation_types = ["normal", "loss", "jitter", "truncation", "scattered_jitter"]

# %%
# Function to load pickle files with better error handling
def load_pickle(file_path):
    print(f"Attempting to load: {file_path}")
    print(f"File exists: {os.path.exists(file_path)}")
    
    if not os.path.exists(file_path):
        print(f"ERROR: File does not exist at {file_path}")
        return None
    
    try:
        # Get file size
        file_size = os.path.getsize(file_path)
        print(f"File size: {file_size} bytes")
        
        if file_size == 0:
            print(f"ERROR: File is empty (0 bytes)")
            return None
        
        # Try to load the file
        with open(file_path, 'rb') as f:
            try:
                data = pickle.load(f)
            except Exception as e:
                print(f"First attempt failed: {e}")
                print("Trying with different encoding...")
                # Rewind the file pointer to the beginning of the file
                f.seek(0)
                try:
                    # Try with Latin-1 encoding for compatibility with Python 2
                    data = pickle.load(f, encoding='latin1')
                    print("Successfully loaded with latin1 encoding")
                except Exception as e2:
                    print(f"Second attempt failed: {e2}")
                    return None
            
        # Check if data is None
        if data is None:
            print("WARNING: File loaded but contains None")
            return None
            
        # Check data type
        print(f"Data type: {type(data)}")
        
        # Check if data is a DataFrame
        if isinstance(data, pd.DataFrame):
            print(f"DataFrame shape: {data.shape}")
            print(f"DataFrame columns: {data.columns.tolist()}")
            if not data.empty:
                print(f"First few rows:\n{data.head(3)}")
        else:
            print(f"Data is not a DataFrame, it's a {type(data)}")
            
        return data
    
    except Exception as e:
        print(f"ERROR loading {file_path}: {e}")
        # Print more detailed error information
        traceback.print_exc()
        return None

# Try multiple ways to load the data
print("Loading perturbation analysis results...")

# Path to the pickle file
pickle_file = result_folder / "formant_cf_distances_by_perturbation.pkl"
print(f"Trying to load pickle file: {pickle_file}")

# First attempt: Try to load the pickle file
perturbation_data = load_pickle(pickle_file)

# If pickle file failed, try the CSV file
if perturbation_data is None:
    csv_file = result_folder / "formant_cf_distances_by_perturbation.csv"
    print(f"\nPickle file failed to load. Trying CSV file: {csv_file}")
    
    if os.path.exists(csv_file):
        try:
            perturbation_data = pd.read_csv(csv_file)
            print(f"CSV loaded successfully with shape: {perturbation_data.shape}")
        except Exception as e:
            print(f"ERROR loading CSV: {e}")
            perturbation_data = None
    else:
        print(f"CSV file doesn't exist at {csv_file}")

# If both failed, try other pickle files that might have the data
if perturbation_data is None:
    other_files = ["merged_data_with_perturbation.pkl", "distance_results_checkpoint.pkl"]
    for file_name in other_files:
        print(f"\nTrying alternative file: {file_name}")
        alt_path = result_folder / file_name
        alt_data = load_pickle(alt_path)
        
        if alt_data is not None and isinstance(alt_data, pd.DataFrame):
            # Check if this file has what we need
            required_cols = ['Category', 'Formant', 'PerturbationType']
            has_distance_col = any('distance' in col.lower() or 'gw' in col.lower() for col in alt_data.columns)
            
            if all(col in alt_data.columns for col in required_cols) and has_distance_col:
                print(f"Found usable data in {file_name}")
                perturbation_data = alt_data
                break

# If we still don't have data, we cannot proceed
if perturbation_data is None or not isinstance(perturbation_data, pd.DataFrame):
    print("Failed to load perturbation data from any source. Cannot proceed.")
    sys.exit(1)

print(f"Successfully loaded data with {len(perturbation_data)} entries")

# Check the structure of the data
print("Data columns:", perturbation_data.columns.tolist())
if 'PerturbationType' in perturbation_data.columns:
    print("Perturbation types in data:", perturbation_data['PerturbationType'].unique())
else:
    print("WARNING: No 'PerturbationType' column found")

# Make sure we have the required columns
required_columns = ['Category', 'Formant', 'GW_Distance', 'PerturbationType']
missing_columns = [col for col in required_columns if col not in perturbation_data.columns]

if missing_columns:
    print(f"Warning: Missing required columns: {missing_columns}")
    
    # Try to adapt the data structure if needed
    if 'Category_x' in perturbation_data.columns and 'Category' not in perturbation_data.columns:
        perturbation_data['Category'] = perturbation_data['Category_x']
        print("Renamed 'Category_x' to 'Category'")
    
    # If GW_Distance is missing but we have a distance column with a different name
    distance_columns = [col for col in perturbation_data.columns if 'distance' in col.lower() or 'gw' in col.lower()]
    if 'GW_Distance' not in perturbation_data.columns and distance_columns:
        perturbation_data['GW_Distance'] = perturbation_data[distance_columns[0]]
        print(f"Renamed '{distance_columns[0]}' to 'GW_Distance'")
    
    # If we still have missing columns, we cannot proceed
    missing_columns = [col for col in required_columns if col not in perturbation_data.columns]
    if missing_columns:
        print(f"Error: Still missing required columns: {missing_columns}")
        print("Cannot proceed with visualization.")
        sys.exit(1)

# Filter to include only the common categories we're interested in
filtered_data = perturbation_data[perturbation_data['Category'].isin(phoneme_categories)]
print(f"Filtered to {len(filtered_data)} entries with common phoneme categories")

# Save the filtered data for reference
filtered_data.to_csv(output_path / "filtered_perturbation_data.csv", index=False)

# %%
# Create compact visualization with all formants side by side
def create_compact_boxplots_by_formant():
    print("Creating compact boxplots by formant...")
    
    # Create a publication-quality figure layout with reduced height
    fig = plt.figure(figsize=(22, 16))  # Reduced height to minimize empty space
    
    # Create a special layout with less space for the legend at the bottom
    gs = GridSpec(4, 3, figure=fig, height_ratios=[10, 10, 10, 2], width_ratios=[1, 1, 1])
    
    # Define perturbation types in a logical order
    pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                 if p in filtered_data['PerturbationType'].unique()]
    
    # Special color scheme
    cmap = plt.cm.viridis
    pert_colors = cmap(np.linspace(0, 1, len(pert_order)))
    
    # Create a perturbation palette mapping each type to a color
    pert_palette = {}
    for i, level in enumerate(pert_order):
        pert_palette[level] = pert_colors[i]
    
    # Create separate panels for each formant in a 3x1 grid (vertical arrangement)
    for i, formant in enumerate(formants):
        # Check if we have data for this formant
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        # Create subplot in the ith row
        ax = fig.add_subplot(gs[i, :])
        
        # Create enhanced box plot with publication-quality styling
        # Use hue_order to ensure consistent legend ordering
        box_plot = sns.boxplot(
            x='Category',
            y='GW_Distance',
            hue='PerturbationType',
            hue_order=pert_order,
            data=formant_data,
            ax=ax,
            palette=pert_palette,
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
        ax.set_title(f'{formant} to CF Distances by Perturbation Type', fontsize=16, fontweight='bold')
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
    
    # Create a beautiful legend with custom styling at the bottom
    legend = legend_ax.legend(
        handles, 
        labels, 
        loc='center', 
        ncol=len(pert_order),  # One column per perturbation type
        title='Perturbation Type', 
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
    plt.savefig(output_path / 'perturbation_boxplots_by_formant.png', dpi=400, bbox_inches='tight')
    
    # Also save as PDF for publication purposes
    plt.savefig(output_path / 'perturbation_boxplots_by_formant.pdf', format='pdf', bbox_inches='tight')
    
    plt.close()

# %%
# Create boxplots for each formant separately by perturbation type
def create_formant_boxplots_by_perturbation():
    print("Creating individual formant boxplots...")
    
    # Define perturbation types in a logical order
    pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                 if p in filtered_data['PerturbationType'].unique()]
    
    # Create a separate plot for each formant
    for formant in formants:
        # Check if we have data for this formant
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        plt.figure(figsize=(16, 10))
        
        # Create box plot
        sns.boxplot(
            x='Category',
            y='GW_Distance',
            hue='PerturbationType',
            hue_order=pert_order,
            data=formant_data,
            palette='viridis',
            width=0.8,
            fliersize=2
        )
        
        # Customize the plot
        plt.title(f'{formant} to CF Distances by Perturbation Type', fontsize=16)
        plt.xlabel('Phoneme Category', fontsize=14)
        plt.ylabel('GW Distance', fontsize=14)
        plt.xticks(rotation=45, ha='right')
        
        # Add a legend
        plt.legend(title='Perturbation Type', fontsize=12)
        
        plt.tight_layout()
        plt.savefig(output_path / f'perturbation_{formant}_boxplot.png', dpi=300)
        plt.close()

# %%
# Create a comprehensive heatmap visualization of distances by perturbation type and category
def create_perturbation_heatmaps():
    print("Creating perturbation heatmaps...")
    
    # Create a separate heatmap for each formant
    for formant in formants:
        # Check if we have data for this formant
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        try:
            # Create a pivot table for the heatmap
            pivot_data = formant_data.pivot_table(
                index='Category', 
                columns='PerturbationType', 
                values='GW_Distance',
                aggfunc='mean'
            )
            
            # Create a figure
            plt.figure(figsize=(14, 10))
            
            # Create heatmap
            sns.heatmap(
                pivot_data,
                annot=True,
                fmt=".3f",
                cmap="YlGnBu",
                cbar_kws={'label': 'Mean GW Distance'},
                linewidths=.5
            )
            
            # Customize the plot
            plt.title(f'Mean {formant} to CF Distances by Perturbation Type', fontsize=16)
            plt.ylabel('Phoneme Category', fontsize=14)
            plt.xlabel('Perturbation Type', fontsize=14)
            
            plt.tight_layout()
            plt.savefig(output_path / f'perturbation_{formant}_heatmap.png', dpi=300)
            plt.close()
        except Exception as e:
            print(f"Error creating heatmap for {formant}: {e}")
            traceback.print_exc()

# %%
# Create a bar chart comparing perturbation effects by formant
def create_perturbation_bar_charts():
    print("Creating perturbation bar charts...")
    
    try:
        # Group the data by perturbation type and formant
        grouped_data = filtered_data.groupby(['PerturbationType', 'Formant'])['GW_Distance'].mean().reset_index()
        
        # Create a bar chart
        plt.figure(figsize=(14, 8))
        
        # Define perturbation types in a logical order
        pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                     if p in filtered_data['PerturbationType'].unique()]
        
        # Create the bar chart
        g = sns.barplot(
            x='Formant',
            y='GW_Distance',
            hue='PerturbationType',
            hue_order=pert_order,
            data=grouped_data,
            palette='viridis',
            edgecolor='black',
            linewidth=1
        )
        
        # Add value labels on the bars
        for i, bar in enumerate(g.patches):
            height = bar.get_height()
            g.text(
                bar.get_x() + bar.get_width()/2.,
                height + 0.01,
                f'{height:.3f}',
                ha='center',
                fontsize=8,
                rotation=0
            )
        
        # Customize the plot
        plt.title('Mean GW Distance by Formant and Perturbation Type', fontsize=16)
        plt.xlabel('Formant', fontsize=14)
        plt.ylabel('Mean GW Distance', fontsize=14)
        plt.legend(title='Perturbation Type', fontsize=12)
        
        plt.tight_layout()
        plt.savefig(output_path / 'perturbation_bar_chart.png', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating bar chart: {e}")
        traceback.print_exc()

# %%
# Create violin plots to show distribution of distances by perturbation type
def create_perturbation_violin_plots():
    print("Creating perturbation violin plots...")
    
    try:
        # Create a figure with three rows for the three formants
        fig, axes = plt.subplots(len(formants), 1, figsize=(16, 18), sharex=True)
        
        # If only one formant, wrap axes in a list
        if len(formants) == 1:
            axes = [axes]
        
        # Define perturbation types in a logical order
        pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                     if p in filtered_data['PerturbationType'].unique()]
        
        # Create a violin plot for each formant
        for i, formant in enumerate(formants):
            # Check if we have data for this formant
            formant_data = filtered_data[filtered_data['Formant'] == formant]
            if len(formant_data) == 0:
                print(f"No data for formant {formant}, skipping...")
                continue
                
            # Create violin plot on the corresponding axis
            sns.violinplot(
                x='PerturbationType',
                y='GW_Distance',
                order=pert_order,
                data=formant_data,
                ax=axes[i],
                palette='viridis',
                inner='box',
                cut=0
            )
            
            # Check if we have enough data points for a swarm plot
            if len(formant_data) < 1000:  # Only add swarm for smaller datasets
                # Add a swarm plot for the actual data points
                sns.swarmplot(
                    x='PerturbationType',
                    y='GW_Distance',
                    order=pert_order,
                    data=formant_data,
                    ax=axes[i],
                    color='white',
                    edgecolor='black',
                    size=3,
                    alpha=0.5
                )
            
            # Customize the subplot
            axes[i].set_title(f'{formant} - Distribution of GW Distances', fontsize=14)
            axes[i].set_ylabel('GW Distance', fontsize=12)
            
            if i < len(formants) - 1:
                axes[i].set_xlabel('')  # Remove x-label for all but the last subplot
        
        # Set the x-label for the last subplot
        axes[-1].set_xlabel('Perturbation Type', fontsize=14)
        
        plt.tight_layout()
        plt.savefig(output_path / 'perturbation_violin_plots.png', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating violin plots: {e}")
        traceback.print_exc()

# %%
# Execute all visualization functions with error handling
try:
    create_compact_boxplots_by_formant()
except Exception as e:
    print(f"Error in create_compact_boxplots_by_formant: {e}")
    traceback.print_exc()

try:
    create_formant_boxplots_by_perturbation()
except Exception as e:
    print(f"Error in create_formant_boxplots_by_perturbation: {e}")
    traceback.print_exc()

try:
    create_perturbation_heatmaps()
except Exception as e:
    print(f"Error in create_perturbation_heatmaps: {e}")
    traceback.print_exc()

try:
    create_perturbation_bar_charts()
except Exception as e:
    print(f"Error in create_perturbation_bar_charts: {e}")
    traceback.print_exc()

try:
    create_perturbation_violin_plots()
except Exception as e:
    print(f"Error in create_perturbation_violin_plots: {e}")
    traceback.print_exc()

print(f"All visualization attempts completed. Check {output_path} for generated images.")

# %%
