# %%
import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import pickle
import traceback
import statsmodels.api as sm
from statsmodels.formula.api import ols
from scipy import stats
import pingouin as pg
import scikit_posthocs as sp

# Set the style for plots
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_context("paper", font_scale=1.4)

# Define paths - update this to match your environment
base_path = Path("/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/OT_SELECT")
result_folder = base_path / "ANSD_OT_Perturbation_Results"
output_path = base_path / "Perturbation_Statistical_Analysis"
os.makedirs(output_path, exist_ok=True)

# Create a results folder for tables and figures
tables_path = output_path / "tables"
figures_path = output_path / "figures"
os.makedirs(tables_path, exist_ok=True)
os.makedirs(figures_path, exist_ok=True)

# Define common phoneme categories and formants
phoneme_categories = ["Vowel", "Fricative", "Stop", "Nasal", "Liquid", "Glide", "Affricate", 
                     "Flap", "Glottal Stop", "Epenthetic", "Silence", "Syllabic Consonant"]
formants = ["F1", "F2", "F3"]
perturbation_types = ["normal", "loss", "jitter", "truncation", "scattered_jitter"]

# TARGET_FREQUENCIES for center frequency labels
TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz

# %%
# Function to load data with robust error handling
def load_data():
    """
    Load the perturbation analysis data from pickle or CSV file with robust error handling.
    Returns a DataFrame with the data or None if loading fails.
    """
    print("\nLoading perturbation analysis data...")
    
    # First try to load the pickle file
    pickle_path = result_folder / "formant_cf_distances_by_perturbation.pkl"
    try:
        if pickle_path.exists():
            print(f"Attempting to load pickle file: {pickle_path}")
            with open(pickle_path, 'rb') as f:
                try:
                    data = pickle.load(f)
                    print(f"Successfully loaded pickle with {len(data)} rows")
                    return data
                except Exception as e:
                    print(f"Error loading pickle file: {e}")
                    # Try with different encoding
                    try:
                        f.seek(0)
                        data = pickle.load(f, encoding='latin1')
                        print(f"Successfully loaded pickle with latin1 encoding, {len(data)} rows")
                        return data
                    except Exception as e2:
                        print(f"Error loading pickle with latin1 encoding: {e2}")
        else:
            print(f"Pickle file not found: {pickle_path}")
    except Exception as e:
        print(f"Unexpected error accessing pickle file: {e}")
    
    # If pickle fails, try the CSV file
    csv_path = result_folder / "formant_cf_distances_by_perturbation.csv"
    try:
        if csv_path.exists():
            print(f"Attempting to load CSV file: {csv_path}")
            data = pd.read_csv(csv_path)
            print(f"Successfully loaded CSV with {len(data)} rows")
            return data
        else:
            print(f"CSV file not found: {csv_path}")
    except Exception as e:
        print(f"Error loading CSV file: {e}")
    
    # Try other potential data files
    alternative_files = [
        "merged_data_with_perturbation.pkl",
        "distance_results_checkpoint.pkl",
        "distance_results_partial.csv"
    ]
    
    for filename in alternative_files:
        file_path = result_folder / filename
        try:
            if file_path.exists():
                print(f"Attempting to load alternative file: {file_path}")
                if filename.endswith('.pkl'):
                    with open(file_path, 'rb') as f:
                        try:
                            data = pickle.load(f)
                            print(f"Successfully loaded {filename} with {len(data)} rows")
                            return data
                        except Exception as e:
                            print(f"Error loading {filename}: {e}")
                            # Try with different encoding
                            try:
                                f.seek(0)
                                data = pickle.load(f, encoding='latin1')
                                print(f"Successfully loaded {filename} with latin1 encoding")
                                return data
                            except Exception as e2:
                                print(f"Error loading {filename} with latin1 encoding: {e2}")
                else:  # CSV file
                    data = pd.read_csv(file_path)
                    print(f"Successfully loaded {filename} with {len(data)} rows")
                    return data
            else:
                print(f"Alternative file not found: {file_path}")
        except Exception as e:
            print(f"Error accessing alternative file {filename}: {e}")
    
    print("Failed to load data from any source.")
    return None

# %%
# Load and preprocess the data
perturbation_data = load_data()

if perturbation_data is None:
    print("Could not load any data. Exiting.")
    sys.exit(1)

# Check and prepare the data structure
print("\nChecking data structure...")
print(f"Original columns: {perturbation_data.columns.tolist()}")

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
        
    # Recheck for missing columns
    missing_columns = [col for col in required_columns if col not in perturbation_data.columns]
    if missing_columns:
        print(f"Error: Still missing required columns: {missing_columns}")
        sys.exit(1)

# Filter to include only the common categories we're interested in
filtered_data = perturbation_data[perturbation_data['Category'].isin(phoneme_categories)]
print(f"Filtered to {len(filtered_data)} entries with common phoneme categories")

# Check perturbation types
if 'PerturbationType' in filtered_data.columns:
    unique_perturbations = filtered_data['PerturbationType'].unique()
    print(f"Unique perturbation types: {unique_perturbations}")
else:
    print("Error: No PerturbationType column found in the filtered data")
    sys.exit(1)

# Save the filtered data for reference
filtered_data.to_csv(output_path / "filtered_perturbation_data.csv", index=False)

# %%
# RESEARCH QUESTION 1: Is there a significant difference in OT distances between different perturbation types?
def analyze_perturbation_differences():
    """
    Analyze the overall differences between perturbation types.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 1: Is there a significant difference in OT distances between different perturbation types?")
    print("="*80)
    
    # First, let's create a summary table of means and standard deviations by perturbation type
    summary_stats = filtered_data.groupby(['PerturbationType', 'Formant']).agg({
        'GW_Distance': ['mean', 'std', 'count']
    }).reset_index()
    
    print("Summary statistics by perturbation type and formant:")
    print(summary_stats)
    
    # Save summary table
    summary_stats.to_csv(tables_path / "perturbation_summary_stats.csv")
    
    # For each formant, run an ANOVA between the perturbation types
    anova_results = []
    
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        # Create the formula - testing PerturbationType while controlling for Category and CF_Num
        formula = "GW_Distance ~ C(PerturbationType) + C(Category) + C(CF_Freq)"
        
        # Fit the model
        try:
            model = ols(formula, data=formant_data).fit()
            
            # Print ANOVA table
            anova_table = sm.stats.anova_lm(model, typ=2)
            print(f"\nANOVA for {formant} - Testing PerturbationType effect:")
            print(anova_table)
            
            # Save ANOVA results
            anova_table.to_csv(tables_path / f"anova_perturbation_effect_{formant}.csv")
            
            # Extract perturbation effect p-value
            if 'C(PerturbationType)' in anova_table.index:
                pert_p = anova_table.loc['C(PerturbationType)', 'PR(>F)']
                anova_results.append({
                    'Formant': formant,
                    'F_Value': anova_table.loc['C(PerturbationType)', 'F'],
                    'P_Value': pert_p,
                    'Significant': pert_p < 0.05
                })
        except Exception as e:
            print(f"Error running ANOVA for {formant}: {e}")
            traceback.print_exc()
    
    # Summarize ANOVA results
    if anova_results:
        anova_df = pd.DataFrame(anova_results)
        print("\nSummary of perturbation type effects across formants:")
        print(anova_df)
        anova_df.to_csv(tables_path / "perturbation_anova_summary.csv")
    
    # Perform post-hoc tests for significant perturbation differences
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            continue
            
        # Check if we have significant perturbation effect from previous ANOVA
        significant = False
        for result in anova_results:
            if result['Formant'] == formant and result['Significant']:
                significant = True
                break
        
        if significant:
            print(f"\nPerforming post-hoc tests for {formant}...")
            try:
                # Perform Tukey's HSD test
                from statsmodels.stats.multicomp import pairwise_tukeyhsd
                
                tukey = pairwise_tukeyhsd(
                    formant_data['GW_Distance'], 
                    formant_data['PerturbationType'],
                    alpha=0.05
                )
                
                print(f"Tukey's HSD post-hoc tests for {formant}:")
                print(tukey)
                
                # Save to a more readable format
                tukey_df = pd.DataFrame(
                    data=tukey._results_table.data[1:],
                    columns=tukey._results_table.data[0]
                )
                
                tukey_df.to_csv(tables_path / f"tukey_perturbation_{formant}.csv")
            except Exception as e:
                print(f"Error in post-hoc tests for {formant}: {e}")
                traceback.print_exc()
    
    # Create visualization comparing perturbation types for each formant
    try:
        fig, axes = plt.subplots(len(formants), 1, figsize=(12, 15), sharex=True)
        
        for i, formant in enumerate(formants):
            formant_data = filtered_data[filtered_data['Formant'] == formant]
            
            if len(formant_data) == 0:
                continue
                
            # Create violin plots with overlaid box plots
            ax = axes[i] if len(formants) > 1 else axes
            
            # Order perturbation types in a logical sequence
            pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                        if p in formant_data['PerturbationType'].unique()]
            
            # Create the plot
            sns.violinplot(x='PerturbationType', y='GW_Distance', data=formant_data, 
                          order=pert_order, ax=ax, palette='viridis', alpha=0.7)
            
            # Add individual data points with jitter
            sns.stripplot(x='PerturbationType', y='GW_Distance', data=formant_data, 
                         order=pert_order, ax=ax, color='black', alpha=0.1, size=1.5, jitter=True)
            
            # Add mean and confidence interval
            sns.pointplot(x='PerturbationType', y='GW_Distance', data=formant_data, 
                         order=pert_order, ax=ax, color='black', scale=0.5, markers='d')
            
            ax.set_title(f'{formant} Distance by Perturbation Type', fontsize=14, fontweight='bold')
            ax.set_ylabel('GW Distance', fontsize=12)
            
            # Only add x-label to bottom subplot
            if i == len(formants) - 1:
                ax.set_xlabel('Perturbation Type', fontsize=12)
            else:
                ax.set_xlabel('')
            
            # Rotate x-tick labels for better readability
            plt.setp(ax.get_xticklabels(), rotation=45, ha='right')
            
            # Add p-value annotation if available
            for result in anova_results:
                if result['Formant'] == formant:
                    ax.text(
                        0.02, 0.95, 
                        f"ANOVA: F={result['F_Value']:.2f}, p={result['P_Value']:.4f}" + 
                        (' *' if result['Significant'] else ''),
                        transform=ax.transAxes,
                        fontsize=10,
                        bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.3')
                    )
                    break
        
        plt.tight_layout()
        plt.savefig(figures_path / 'perturbation_comparison.png', dpi=300)
        plt.savefig(figures_path / 'perturbation_comparison.pdf', format='pdf')
        plt.close()
    except Exception as e:
        print(f"Error creating perturbation comparison plot: {e}")
        traceback.print_exc()

# %%
# RESEARCH QUESTION 2: Do perturbation effects differ across phoneme categories?
def analyze_category_perturbation_interaction():
    """
    Analyze whether perturbation effects differ across phoneme categories.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 2: Do perturbation effects differ across phoneme categories?")
    print("="*80)
    
    # For each formant, test for Category × PerturbationType interaction
    interaction_results = []
    
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        # Create the formula - testing the interaction while controlling for CF_Num
        formula = "GW_Distance ~ C(Category) * C(PerturbationType) + C(CF_Freq)"
        
        try:
            # Fit the model
            model = ols(formula, data=formant_data).fit()
            
            # Get ANOVA table
            anova_table = sm.stats.anova_lm(model, typ=2)
            print(f"\nANOVA for {formant} - Testing Category × PerturbationType interaction:")
            print(anova_table)
            
            # Save ANOVA results
            anova_table.to_csv(tables_path / f"anova_category_perturbation_{formant}.csv")
            
            # Extract interaction p-value
            if 'C(Category):C(PerturbationType)' in anova_table.index:
                int_p = anova_table.loc['C(Category):C(PerturbationType)', 'PR(>F)']
                interaction_results.append({
                    'Formant': formant,
                    'F_Value': anova_table.loc['C(Category):C(PerturbationType)', 'F'],
                    'P_Value': int_p,
                    'Significant': int_p < 0.05
                })
        except Exception as e:
            print(f"Error running interaction ANOVA for {formant}: {e}")
            traceback.print_exc()
    
    # Summarize interaction results
    if interaction_results:
        int_df = pd.DataFrame(interaction_results)
        print("\nSummary of Category × PerturbationType interaction effects:")
        print(int_df)
        int_df.to_csv(tables_path / "category_perturbation_interaction_summary.csv")
    
    # Create heatmaps showing differential category responses to perturbations
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
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
            
            # Add interaction p-value to title if available
            title = f'Mean {formant} Distances by Category and Perturbation Type'
            for result in interaction_results:
                if result['Formant'] == formant:
                    title += f' (Interaction p={result["P_Value"]:.4f}' + (')' if not result['Significant'] else ', significant)')
                    break
            
            plt.title(title, fontsize=16)
            plt.ylabel('Phoneme Category', fontsize=14)
            plt.xlabel('Perturbation Type', fontsize=14)
            
            plt.tight_layout()
            plt.savefig(figures_path / f'category_perturbation_heatmap_{formant}.png', dpi=300)
            plt.savefig(figures_path / f'category_perturbation_heatmap_{formant}.pdf', format='pdf')
            plt.close()
            
            # For each category, create a bar plot showing perturbation effects
            for category in phoneme_categories:
                category_data = formant_data[formant_data['Category'] == category]
                
                if len(category_data) == 0:
                    continue
                    
                plt.figure(figsize=(10, 6))
                
                # Order perturbation types in a logical sequence
                pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                            if p in category_data['PerturbationType'].unique()]
                
                # Create boxplot
                sns.boxplot(
                    x='PerturbationType', 
                    y='GW_Distance', 
                    data=category_data,
                    order=pert_order,
                    palette='viridis'
                )
                
                # Add scatter points
                sns.stripplot(
                    x='PerturbationType', 
                    y='GW_Distance', 
                    data=category_data,
                    order=pert_order,
                    color='black',
                    alpha=0.3,
                    size=4,
                    jitter=True
                )
                
                plt.title(f'{formant} - {category}: Response to Perturbations', fontsize=14)
                plt.xlabel('Perturbation Type', fontsize=12)
                plt.ylabel('GW Distance', fontsize=12)
                plt.xticks(rotation=45, ha='right')
                
                plt.tight_layout()
                plt.savefig(figures_path / f'perturbation_response_{formant}_{category}.png', dpi=300)
                plt.close()
        except Exception as e:
            print(f"Error creating visualizations for {formant}: {e}")
            traceback.print_exc()

# %%
# RESEARCH QUESTION 3: Are there differences in how F1, F2, and F3 are affected by different perturbation types?
def analyze_formant_perturbation_interaction():
    """
    Analyze whether perturbation effects differ across formants.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 3: Are there differences in how F1, F2, and F3 are affected by different perturbation types?")
    print("="*80)
    
    # Test for Formant × PerturbationType interaction
    try:
        # Create the formula - testing the interaction while controlling for Category and CF_Num
        formula = "GW_Distance ~ C(Formant) * C(PerturbationType) + C(Category) + C(CF_Num)"
        
        # Fit the model
        model = ols(formula, data=filtered_data).fit()
        
        # Get ANOVA table
        anova_table = sm.stats.anova_lm(model, typ=2)
        print("\nANOVA - Testing Formant × PerturbationType interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / "anova_formant_perturbation.csv")
        
        # Check if interaction is significant
        significant = False
        if 'C(Formant):C(PerturbationType)' in anova_table.index:
            int_p = anova_table.loc['C(Formant):C(PerturbationType)', 'PR(>F)']
            significant = int_p < 0.05
            print(f"Formant × PerturbationType interaction p-value: {int_p}")
            print(f"Significant: {significant}")
    except Exception as e:
        print(f"Error running formant-perturbation interaction ANOVA: {e}")
        traceback.print_exc()
    
    # Create a visualization showing perturbation effects for each formant
    try:
        # Calculate mean and SE for each Formant-PerturbationType combination
        formant_pert_summary = filtered_data.groupby(['Formant', 'PerturbationType']).agg({
            'GW_Distance': ['mean', 'sem', 'count']
        }).reset_index()
        
        # Order perturbation types in a logical sequence
        pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                    if p in filtered_data['PerturbationType'].unique()]
        
        # Create a bar plot
        plt.figure(figsize=(12, 8))
        
        # Set up positions for the bars
        bar_width = 0.15
        formant_count = len(formants)
        pert_count = len(pert_order)
        
        # Calculate positions for each group of bars
        indices = np.arange(len(formants))
        
        # Create bars for each perturbation type
        for i, pert_type in enumerate(pert_order):
            # Get data for this perturbation type
            pert_data = formant_pert_summary[formant_pert_summary['PerturbationType'] == pert_type]
            
            # Ensure data is in the right order
            pert_data = pert_data.set_index('Formant').loc[formants].reset_index()
            
            # Define position offset for this group of bars
            offset = i - (pert_count - 1) / 2
            pos = indices + offset * bar_width
            
            # Create the bars
            plt.bar(
                pos, 
                pert_data['GW_Distance']['mean'], 
                width=bar_width,
                yerr=pert_data['GW_Distance']['sem'],
                capsize=4,
                label=pert_type
            )
        
        # Set x-axis ticks and labels
        plt.xticks(indices, formants)
        
        # Add labels and legend
        plt.xlabel('Formant', fontsize=14)
        plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
        plt.title('Perturbation Effects by Formant', fontsize=16, fontweight='bold')
        plt.legend(title='Perturbation Type')
        
        # Add p-value for interaction if available
        try:
            if 'C(Formant):C(PerturbationType)' in anova_table.index:
                int_p = anova_table.loc['C(Formant):C(PerturbationType)', 'PR(>F)']
                plt.text(
                    0.02, 0.98, 
                    f"Interaction p={int_p:.4f}" + (' *' if int_p < 0.05 else ''),
                    transform=plt.gca().transAxes,
                    fontsize=10,
                    bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.3'),
                    verticalalignment='top'
                )
        except (KeyError, NameError):
            pass
        
        plt.tight_layout()
        plt.savefig(figures_path / 'formant_perturbation_interaction.png', dpi=300)
        plt.savefig(figures_path / 'formant_perturbation_interaction.pdf', format='pdf')
        plt.close()
        
        # Create a heatmap for the interaction
        # Pivot the data
        pivot_data = formant_pert_summary.pivot_table(
            index='Formant',
            columns='PerturbationType',
            values=('GW_Distance', 'mean')
        )
        
        # Flatten the MultiIndex columns
        pivot_data.columns = pivot_data.columns.droplevel(0)
        
        # Create the heatmap
        plt.figure(figsize=(12, 8))
        
        # Reorder the columns if possible
        try:
            pivot_data = pivot_data[pert_order]
        except KeyError:
            pass
        
        # Create the heatmap
        sns.heatmap(
            pivot_data,
            annot=True,
            fmt=".3f",
            cmap="viridis",
            cbar_kws={'label': 'Mean GW Distance'},
            linewidths=0.5
        )
        
        plt.title('Formant × Perturbation Type Interaction', fontsize=16)
        plt.tight_layout()
        plt.savefig(figures_path / 'formant_perturbation_heatmap.png', dpi=300)
        plt.savefig(figures_path / 'formant_perturbation_heatmap.pdf', format='pdf')
        plt.close()
    except Exception as e:
        print(f"Error creating formant-perturbation visualization: {e}")
        traceback.print_exc()

# %%
# RESEARCH QUESTION 4: How do center frequencies (CFs) interact with perturbation types?
def analyze_cf_perturbation_interaction():
    """
    Analyze how center frequencies (CFs) interact with perturbation types.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 4: How do center frequencies (CFs) interact with perturbation types?")
    print("="*80)
    
    # For each formant, test for CF_Num × PerturbationType interaction
    interaction_results = []
    
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
            
        # Create the formula - testing the interaction while controlling for Category
        formula = "GW_Distance ~ C(CF_Freq) * C(PerturbationType) + C(Category)"
        
        try:
            # Fit the model
            model = ols(formula, data=formant_data).fit()
            
            # Get ANOVA table
            anova_table = sm.stats.anova_lm(model, typ=2)
            print(f"\nANOVA for {formant} - Testing CF_Num × PerturbationType interaction:")
            print(anova_table)
            
            # Save ANOVA results
            anova_table.to_csv(tables_path / f"anova_cf_perturbation_{formant}.csv")
            
            # Extract interaction p-value
            if 'C(CF_Num):C(PerturbationType)' in anova_table.index:
                int_p = anova_table.loc['C(CF_Num):C(PerturbationType)', 'PR(>F)']
                interaction_results.append({
                    'Formant': formant,
                    'F_Value': anova_table.loc['C(CF_Num):C(PerturbationType)', 'F'],
                    'P_Value': int_p,
                    'Significant': int_p < 0.05
                })
        except Exception as e:
            print(f"Error running CF-perturbation interaction ANOVA for {formant}: {e}")
            traceback.print_exc()
    
    # Summarize interaction results
    if interaction_results:
        int_df = pd.DataFrame(interaction_results)
        print("\nSummary of CF_Num × PerturbationType interaction effects:")
        print(int_df)
        int_df.to_csv(tables_path / "cf_perturbation_interaction_summary.csv")
    
    # Create heatmaps showing differential CF responses to perturbations
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            continue
            
        try:
            # Create a pivot table for the heatmap
            pivot_data = formant_data.pivot_table(
                index='CF_Num', 
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
            
            # Add interaction p-value to title if available
            title = f'Mean {formant} Distances by CF and Perturbation Type'
            for result in interaction_results:
                if result['Formant'] == formant:
                    title += f' (Interaction p={result["P_Value"]:.4f}' + (')' if not result['Significant'] else ', significant)')
                    break
            
            plt.title(title, fontsize=16)
            
            # Customize y-tick labels with actual frequencies
            yticks = []
            for n in sorted(pivot_data.index):
                if n-1 < len(TARGET_FREQUENCIES):
                    yticks.append(f'CF{n} ({TARGET_FREQUENCIES[n-1]} Hz)')
                else:
                    yticks.append(f'CF{n}')
            
            plt.yticks(range(len(yticks)), yticks)
            
            plt.ylabel('Center Frequency', fontsize=14)
            plt.xlabel('Perturbation Type', fontsize=14)
            
            plt.tight_layout()
            plt.savefig(figures_path / f'cf_perturbation_heatmap_{formant}.png', dpi=300)
            plt.savefig(figures_path / f'cf_perturbation_heatmap_{formant}.pdf', format='pdf')
            plt.close()
            
            # Create line plots showing CF response patterns for each perturbation type
            plt.figure(figsize=(12, 8))
            
            # Order perturbation types in a logical sequence
            pert_order = [p for p in ["normal", "loss", "jitter", "truncation", "scattered_jitter"] 
                        if p in formant_data['PerturbationType'].unique()]
            
            # Group by CF_Num and PerturbationType
            cf_pert_means = formant_data.groupby(['CF_Num', 'PerturbationType'])['GW_Distance'].agg(
                ['mean', 'sem']
            ).reset_index()
            
            # Plot a line for each perturbation type
            for pert_type in pert_order:
                pert_data = cf_pert_means[cf_pert_means['PerturbationType'] == pert_type]
                
                # Sort by CF_Num
                pert_data = pert_data.sort_values('CF_Num')
                
                plt.errorbar(
                    x=pert_data['CF_Num'],
                    y=pert_data['mean'],
                    yerr=pert_data['sem'],
                    fmt='o-',
                    capsize=4,
                    linewidth=2,
                    label=pert_type
                )
            
            # Set x-ticks with CF numbers and Hz values
            cf_numbers = sorted(formant_data['CF_Num'].unique())
            xticks = []
            for n in cf_numbers:
                if n-1 < len(TARGET_FREQUENCIES):
                    xticks.append(f'CF{n}\n({TARGET_FREQUENCIES[n-1]} Hz)')
                else:
                    xticks.append(f'CF{n}')
            
            plt.xticks(cf_numbers, xticks)
            
            plt.title(f'{formant}: Center Frequency Response by Perturbation Type', fontsize=16)
            plt.xlabel('Center Frequency', fontsize=14)
            plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
            plt.legend(title='Perturbation Type')
            plt.grid(True, linestyle='--', alpha=0.7)
            
            # Add interaction p-value if available
            for result in interaction_results:
                if result['Formant'] == formant:
                    plt.text(
                        0.02, 0.98, 
                        f"Interaction p={result['P_Value']:.4f}" + (' *' if result['Significant'] else ''),
                        transform=plt.gca().transAxes,
                        fontsize=10,
                        bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.3'),
                        verticalalignment='top'
                    )
                    break
            
            plt.tight_layout()
            plt.savefig(figures_path / f'cf_perturbation_lines_{formant}.png', dpi=300)
            plt.savefig(figures_path / f'cf_perturbation_lines_{formant}.pdf', format='pdf')
            plt.close()
        except Exception as e:
            print(f"Error creating CF-perturbation visualizations for {formant}: {e}")
            traceback.print_exc()

# %%
# RESEARCH QUESTION 5: Which phoneme categories are most affected by specific perturbation types?
def analyze_category_sensitivity():
    """
    Analyze which phoneme categories are most sensitive to different perturbation types.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 5: Which phoneme categories are most affected by specific perturbation types?")
    print("="*80)
    
    # For each formant, analyze how different perturbation types affect each category
    for formant in formants:
        formant_data = filtered_data[filtered_data['Formant'] == formant]
        
        if len(formant_data) == 0:
            print(f"No data for formant {formant}, skipping...")
            continue
        
        try:
            # Calculate the reference level (normal) for each category
            reference_data = formant_data[formant_data['PerturbationType'] == 'normal']
            
            # If there's no 'normal' reference, use the mean across all perturbation types as reference
            if len(reference_data) == 0:
                print(f"No 'normal' reference for {formant}, using mean across perturbation types")
                reference_data = formant_data.groupby('Category')['GW_Distance'].mean().reset_index()
                reference_data.columns = ['Category', 'Reference']
            else:
                reference_data = reference_data.groupby('Category')['GW_Distance'].mean().reset_index()
                reference_data.columns = ['Category', 'Reference']
            
            # Calculate the effect of each perturbation type relative to reference
            effect_data = []
            
            for category in phoneme_categories:
                cat_ref = reference_data[reference_data['Category'] == category]
                
                if len(cat_ref) == 0:
                    continue
                    
                ref_value = cat_ref['Reference'].values[0]
                
                for pert_type in formant_data['PerturbationType'].unique():
                    if pert_type == 'normal':
                        continue
                        
                    # Get data for this category and perturbation type
                    cat_pert_data = formant_data[
                        (formant_data['Category'] == category) & 
                        (formant_data['PerturbationType'] == pert_type)
                    ]
                    
                    if len(cat_pert_data) == 0:
                        continue
                        
                    # Calculate mean, SEM, and effect size
                    mean_val = cat_pert_data['GW_Distance'].mean()
                    sem_val = cat_pert_data['GW_Distance'].sem()
                    effect = mean_val - ref_value
                    
                    # Calculate t-test if possible
                    t_stat, p_val = np.nan, np.nan
                    try:
                        cat_normal = formant_data[
                            (formant_data['Category'] == category) & 
                            (formant_data['PerturbationType'] == 'normal')
                        ]['GW_Distance']
                        
                        if len(cat_normal) > 0:
                            t_stat, p_val = stats.ttest_ind(
                                cat_pert_data['GW_Distance'],
                                cat_normal,
                                equal_var=False
                            )
                    except Exception as e:
                        print(f"Error calculating t-test for {category}, {pert_type}: {e}")
                    
                    effect_data.append({
                        'Formant': formant,
                        'Category': category,
                        'PerturbationType': pert_type,
                        'Mean': mean_val,
                        'SEM': sem_val,
                        'Reference': ref_value,
                        'Effect': effect,
                        'Percent_Change': (effect / ref_value) * 100 if ref_value != 0 else np.nan,
                        'T_Statistic': t_stat,
                        'P_Value': p_val,
                        'Significant': p_val < 0.05 if not np.isnan(p_val) else np.nan
                    })
            
            # Convert to DataFrame
            if effect_data:
                effect_df = pd.DataFrame(effect_data)
                
                # Save to CSV
                effect_df.to_csv(tables_path / f"category_sensitivity_{formant}.csv", index=False)
                
                print(f"\nCategory sensitivity analysis for {formant}:")
                print(effect_df[['Category', 'PerturbationType', 'Effect', 'Percent_Change', 'P_Value', 'Significant']].head())
                
                # Create heatmap of percent changes
                try:
                    # Pivot data for heatmap
                    pivot_effect = effect_df.pivot_table(
                        index='Category',
                        columns='PerturbationType',
                        values='Percent_Change'
                    )
                    
                    # Create the heatmap
                    plt.figure(figsize=(12, 8))
                    
                    # Use a diverging colormap centered at 0
                    # Positive values (red): increase from reference
                    # Negative values (blue): decrease from reference
                    max_abs_change = max(abs(pivot_effect.min().min()), abs(pivot_effect.max().max()))
                    vmin = -max_abs_change
                    vmax = max_abs_change
                    
                    sns.heatmap(
                        pivot_effect,
                        annot=True,
                        fmt=".1f",
                        cmap="RdBu_r",
                        center=0,
                        vmin=vmin,
                        vmax=vmax,
                        linewidths=0.5,
                        cbar_kws={'label': 'Percent Change from Reference (%)'}
                    )
                    
                    plt.title(f'{formant}: Category Sensitivity to Perturbation Types', fontsize=16)
                    plt.ylabel('Phoneme Category', fontsize=14)
                    plt.xlabel('Perturbation Type', fontsize=14)
                    
                    plt.tight_layout()
                    plt.savefig(figures_path / f'category_sensitivity_heatmap_{formant}.png', dpi=300)
                    plt.savefig(figures_path / f'category_sensitivity_heatmap_{formant}.pdf', format='pdf')
                    plt.close()
                    
                    # Create bar chart of most affected categories
                    # Calculate the mean absolute effect across all perturbation types
                    mean_abs_effect = effect_df.groupby('Category')['Percent_Change'].apply(
                        lambda x: np.mean(np.abs(x))
                    ).reset_index()
                    mean_abs_effect = mean_abs_effect.sort_values('Percent_Change', ascending=False)
                    
                    plt.figure(figsize=(12, 6))
                    
                    # Create bar chart
                    bars = plt.bar(
                        mean_abs_effect['Category'],
                        mean_abs_effect['Percent_Change'],
                        color='skyblue',
                        edgecolor='black'
                    )
                    
                    # Add value labels above bars
                    for bar in bars:
                        height = bar.get_height()
                        plt.text(
                            bar.get_x() + bar.get_width()/2.,
                            height + 0.5,
                            f'{height:.1f}%',
                            ha='center',
                            va='bottom',
                            fontsize=10
                        )
                    
                    plt.title(f'{formant}: Mean Category Sensitivity to Perturbations', fontsize=16)
                    plt.ylabel('Mean Absolute Percent Change', fontsize=14)
                    plt.xlabel('Phoneme Category', fontsize=14)
                    plt.xticks(rotation=45, ha='right')
                    plt.grid(axis='y', linestyle='--', alpha=0.7)
                    
                    plt.tight_layout()
                    plt.savefig(figures_path / f'category_sensitivity_bars_{formant}.png', dpi=300)
                    plt.savefig(figures_path / f'category_sensitivity_bars_{formant}.pdf', format='pdf')
                    plt.close()
                except Exception as e:
                    print(f"Error creating category sensitivity visualizations for {formant}: {e}")
                    traceback.print_exc()
        except Exception as e:
            print(f"Error analyzing category sensitivity for {formant}: {e}")
            traceback.print_exc()

# %%
# Integrated analysis and summary
def create_integrated_summary():
    """
    Create a comprehensive summary of all findings.
    """
    print("\n" + "="*80)
    print("Creating Integrated Summary of Findings")
    print("="*80)
    
    # Prepare a comprehensive summary DataFrame
    summary_rows = []
    
    # Summarize perturbation type effects
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_perturbation_effect_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(PerturbationType)' in anova_data.index:
                    p_val = anova_data.loc['C(PerturbationType)', 'PR(>F)']
                    f_val = anova_data.loc['C(PerturbationType)', 'F']
                    
                    summary_rows.append({
                        'Question': 'Perturbation Type Main Effect',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Summarize Category × PerturbationType interactions
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_category_perturbation_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(Category):C(PerturbationType)' in anova_data.index:
                    p_val = anova_data.loc['C(Category):C(PerturbationType)', 'PR(>F)']
                    f_val = anova_data.loc['C(Category):C(PerturbationType)', 'F']
                    
                    summary_rows.append({
                        'Question': 'Category × Perturbation Interaction',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Summarize Formant × PerturbationType interactions
    try:
        anova_file = tables_path / "anova_formant_perturbation.csv"
        if anova_file.exists():
            anova_data = pd.read_csv(anova_file, index_col=0)
            if 'C(Formant):C(PerturbationType)' in anova_data.index:
                p_val = anova_data.loc['C(Formant):C(PerturbationType)', 'PR(>F)']
                f_val = anova_data.loc['C(Formant):C(PerturbationType)', 'F']
                
                summary_rows.append({
                    'Question': 'Formant × Perturbation Interaction',
                    'Formant': 'All',
                    'F_value': f_val,
                    'P_value': p_val,
                    'Significant': p_val < 0.05
                })
    except Exception as e:
        print(f"Could not process {anova_file}: {e}")
    
    # Summarize CF × PerturbationType interactions
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_cf_perturbation_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(CF_Num):C(PerturbationType)' in anova_data.index:
                    p_val = anova_data.loc['C(CF_Num):C(PerturbationType)', 'PR(>F)']
                    f_val = anova_data.loc['C(CF_Num):C(PerturbationType)', 'F']
                    
                    summary_rows.append({
                        'Question': 'CF × Perturbation Interaction',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Create and save the summary DataFrame
    if summary_rows:
        summary_df = pd.DataFrame(summary_rows)
        summary_df = summary_df.sort_values(['Question', 'Formant', 'P_value'])
        summary_df.to_csv(output_path / "integrated_statistical_summary.csv", index=False)
        
        print(f"Integrated summary saved to {output_path / 'integrated_statistical_summary.csv'}")
    
    # Create a markdown report summarizing the findings
    report_content = """# Perturbation Analysis Statistical Report

## Overview
This report summarizes the results of statistical analyses on how different perturbation types affect the OT (Optimal Transport) distances between formants and center frequencies.

## Research Questions

1. **Perturbation Type Effects**: Are there significant differences in OT distances between different perturbation types?
2. **Category × Perturbation Interaction**: Do perturbation effects differ across phoneme categories?
3. **Formant × Perturbation Interaction**: Are there differences in how F1, F2, and F3 are affected by different perturbation types?
4. **CF × Perturbation Interaction**: How do center frequencies (CFs) interact with perturbation types?
5. **Category Sensitivity**: Which phoneme categories are most affected by specific perturbation types?

## Key Findings

[This section will be populated based on the statistical results]

## Conclusions

[This section will summarize the overall implications of the findings]
"""
    
    # Write the report to a file
    with open(output_path / "perturbation_analysis_report.md", "w") as f:
        f.write(report_content)
    
    print(f"Report template created at {output_path / 'perturbation_analysis_report.md'}")

# %%
# Run all analyses
def run_all_analyses():
    """
    Execute all research question analyses.
    """
    print("\n" + "="*80)
    print("RUNNING ALL STATISTICAL ANALYSES FOR PERTURBATION DATA")
    print("="*80)
    
    # Run analyses for each research question
    analyze_perturbation_differences()       # Question 1
    analyze_category_perturbation_interaction()  # Question 2
    analyze_formant_perturbation_interaction()   # Question 3
    analyze_cf_perturbation_interaction()        # Question 4
    analyze_category_sensitivity()               # Question 5
    
    # Create integrated summary
    create_integrated_summary()
    
    print("\n" + "="*80)
    print("ALL ANALYSES COMPLETE")
    print(f"Results saved to {output_path}")
    print("="*80)

# %%
# Main execution
if __name__ == "__main__":
    # Run all analyses
    run_all_analyses()
# %%
