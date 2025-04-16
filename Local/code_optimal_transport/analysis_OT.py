# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import pickle
import statsmodels.api as sm
from statsmodels.formula.api import ols, mixedlm
from scipy import stats
import pingouin as pg
import scikit_posthocs as sp

# Set the style for plots
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_context("paper", font_scale=1.4)

# Define paths - update this to match your environment
base_path = Path("/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/OT_SELECT")
output_path = base_path / "Statistical_Analysis"
os.makedirs(output_path, exist_ok=True)

# Load the combined dataset created in your original script
# Assuming the pickle file was created and stored at the specified location
data_file = base_path / "Boxplot_Comparisons" / "all_ot_distances_combined.pkl"

try:
    all_data = pd.read_pickle(data_file)
    print(f"Loaded dataset with {len(all_data)} rows")
except Exception as e:
    print(f"Error loading data: {e}")
    raise

# Define phoneme categories and formants from your original code
phoneme_categories = ["Vowel", "Fricative", "Stop", "Nasal", "Liquid", "Glide", "Affricate", 
                     "Flap", "Glottal Stop", "Epenthetic", "Silence", "Syllabic Consonant"]
formants = ["F1", "F2", "F3"]

# Create a results folder for tables
tables_path = output_path / "tables"
os.makedirs(tables_path, exist_ok=True)

# Create figures folder
figures_path = output_path / "figures"
os.makedirs(figures_path, exist_ok=True)

# %%
# RESEARCH QUESTION 1: Is there a significant difference in OT distances between Healthy and ANSD groups?
# This is the most fundamental question - comparing the basic difference between groups

def analyze_group_differences():
    """
    Analyze the overall differences between Healthy and ANSD groups, 
    controlling for other factors.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 1: Is there a significant difference in OT distances between Healthy and ANSD groups?")
    print("="*80)
    
    # First, let's create a summary table of means and standard deviations by group
    summary_stats = all_data.groupby(['Group', 'Formant']).agg({
        'GW_Distance': ['mean', 'std', 'count']
    }).reset_index()
    
    print("Summary statistics by group and formant:")
    print(summary_stats)
    
    # Save summary table
    summary_stats.to_csv(tables_path / "group_summary_stats.csv")
    
    # For each formant, run a t-test between the groups
    # We'll focus on silence condition first for a clean comparison
    silence_data = all_data[all_data['NoiseLevel'] == 'Silence']
    
    t_test_results = []
    for formant in formants:
        formant_data = silence_data[silence_data['Formant'] == formant]
        healthy_data = formant_data[formant_data['Group'] == 'Healthy']['GW_Distance']
        ansd_data = formant_data[formant_data['Group'] == 'ANSD']['GW_Distance']
        
        t_stat, p_val = stats.ttest_ind(healthy_data, ansd_data, equal_var=False)
        t_test_results.append({
            'Formant': formant,
            'T-statistic': t_stat,
            'P-value': p_val,
            'Significant': p_val < 0.05
        })
    
    t_test_df = pd.DataFrame(t_test_results)
    print("\nT-test results for Healthy vs. ANSD (Silence condition only):")
    print(t_test_df)
    
    # Save t-test results
    t_test_df.to_csv(tables_path / "group_ttest_results.csv")
    
    # Now let's run a more comprehensive analysis using a mixed-effects model
    # This will control for phoneme category while testing the group effect
    
    # For a more detailed analysis, we'll run a model for each formant
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Create the formula - testing Group while controlling for Category and CF_Num
        formula = "GW_Distance ~ Group + C(Category) + C(CF_Num)"
        
        # Fit the model
        model = ols(formula, data=formant_data).fit()
        
        # Print ANOVA table
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nANOVA for {formant} - Testing Group effect:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_group_effect_{formant}.csv")
        
        # Print model summary for more detailed statistics
        print(f"\nDetailed model summary for {formant}:")
        print(model.summary())
    
    # Create a visualization comparing healthy vs ANSD for each formant (across all noise conditions)
    fig, axes = plt.subplots(len(formants), 1, figsize=(12, 15), sharex=True)
    
    for i, formant in enumerate(formants):
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Create violin plots with overlaid box plots
        sns.violinplot(x='Group', y='GW_Distance', data=formant_data, 
                      ax=axes[i], palette=['#1f77b4', '#ff7f0e'], alpha=0.7)
        
        # Add individual data points with jitter
        sns.stripplot(x='Group', y='GW_Distance', data=formant_data, 
                     ax=axes[i], color='black', alpha=0.2, size=3, jitter=True)
        
        # Add mean and confidence interval
        sns.pointplot(x='Group', y='GW_Distance', data=formant_data, 
                     ax=axes[i], color='black', scale=0.7, markers='d')
        
        axes[i].set_title(f'{formant} Distance by Group', fontsize=14, fontweight='bold')
        axes[i].set_ylabel('GW Distance', fontsize=12)
        
        # Only add x-label to bottom subplot
        if i == len(formants) - 1:
            axes[i].set_xlabel('Group', fontsize=12)
        else:
            axes[i].set_xlabel('')
    
    plt.tight_layout()
    #plt.savefig(figures_path / 'formant_noise_interaction.png', dpi=300)
    plt.savefig(figures_path / 'formant_noise_interaction.pdf', format='pdf')
    plt.close()

# %%
# RESEARCH QUESTION 6: How do center frequencies (CFs) affect OT distances in each group?
# This examines whether different CFs show different patterns in Healthy vs ANSD

def analyze_cf_effects():
    """
    Analyze how center frequencies (CFs) affect OT distances and whether this differs between groups.
    This research question examines how frequency-specific neural processing is affected in ANSD
    compared to healthy individuals, which could reveal localized auditory system deficits.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 6: How do center frequencies (CFs) affect OT distances in each group?")
    print("="*80)
    
    # Test for overall CF effects
    formula = "GW_Distance ~ C(CF_Num) + C(Group) + C(NoiseLevel) + C(Category) + C(Formant)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing CF main effect:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_cf_main.csv")
    
    # Test for CF × Group interaction
    formula = "GW_Distance ~ C(CF_Num) * C(Group) + C(NoiseLevel) + C(Category) + C(Formant)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing CF × Group interaction:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_cf_group.csv")
    
    # Test for CF × NoiseLevel interaction - important to understand how noise affects different frequency bands
    formula = "GW_Distance ~ C(CF_Num) * C(NoiseLevel) + C(Group) + C(Category) + C(Formant)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing CF × NoiseLevel interaction:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_cf_noise.csv")
    
    # Three-way interaction: CF × Group × NoiseLevel
    formula = "GW_Distance ~ C(CF_Num) * C(Group) * C(NoiseLevel) + C(Category) + C(Formant)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing CF × Group × NoiseLevel interaction:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_cf_group_noise.csv")
    
    # If significant CF differences, perform post-hoc tests
    formula = "GW_Distance ~ C(CF_Num)"
    model = ols(formula, data=all_data).fit()
    anova_table = sm.stats.anova_lm(model, typ=2)
    
    if 'C(CF_Num)' in anova_table.index and anova_table.loc['C(CF_Num)', 'PR(>F)'] < 0.05:
        # Perform Tukey's HSD post-hoc test for CFs
        from statsmodels.stats.multicomp import pairwise_tukeyhsd
        
        tukey = pairwise_tukeyhsd(
            all_data['GW_Distance'], 
            all_data['CF_Num'],
            alpha=0.05
        )
        
        print("\nTukey's HSD post-hoc tests for center frequencies:")
        print(tukey)
        
        # Save to a more readable format
        tukey_df = pd.DataFrame(
            data=tukey._results_table.data[1:],
            columns=tukey._results_table.data[0]
        )
        
        tukey_df.to_csv(tables_path / "tukey_cf.csv")
    
    # For each formant, analyze CF patterns
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Test CF × Group interaction for this formant
        formula = "GW_Distance ~ C(CF_Num) * C(Group) + C(NoiseLevel) + C(Category)"
        model = ols(formula, data=formant_data).fit()
        
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nANOVA for {formant} - Testing CF × Group interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_cf_group_{formant}.csv")
    
    # Create visualizations comparing CF patterns between groups
    # First, aggregate data by CF, Group, and Formant
    cf_summary = all_data.groupby(['CF_Num', 'Group', 'Formant']).agg({
        'GW_Distance': ['mean', 'sem', 'count']
    }).reset_index()
    
    # Define TARGET_FREQUENCIES for CF labels (from your original code)
    TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz
    
    # Create plots for each formant
    for formant in formants:
        formant_data = cf_summary[cf_summary['Formant'] == formant]
        
        plt.figure(figsize=(12, 8))
        
        # Plot for Healthy group
        healthy_data = formant_data[formant_data['Group'] == 'Healthy']
        plt.errorbar(
            x=healthy_data['CF_Num'],
            y=healthy_data['GW_Distance']['mean'],
            yerr=healthy_data['GW_Distance']['sem'],
            fmt='o-',
            color='#1f77b4',
            label='Healthy',
            capsize=5,
            linewidth=2,
            markersize=8
        )
        
        # Plot for ANSD group
        ansd_data = formant_data[formant_data['Group'] == 'ANSD']
        plt.errorbar(
            x=ansd_data['CF_Num'],
            y=ansd_data['GW_Distance']['mean'],
            yerr=ansd_data['GW_Distance']['sem'],
            fmt='s-',
            color='#ff7f0e',
            label='ANSD',
            capsize=5,
            linewidth=2,
            markersize=8
        )
        
        # Set x-axis ticks and labels with actual frequencies
        cf_labels = []
        for n in sorted(all_data['CF_Num'].unique()):
            if n-1 < len(TARGET_FREQUENCIES):
                cf_labels.append(f'CF{n}\n({TARGET_FREQUENCIES[n-1]} Hz)')
            else:
                cf_labels.append(f'CF{n}')
        
        plt.xticks(sorted(all_data['CF_Num'].unique()), cf_labels)
        
        # Add titles and labels
        plt.title(f'CF Comparison - {formant}', fontsize=16, fontweight='bold')
        plt.xlabel('Center Frequency', fontsize=14)
        plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
        plt.legend(fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)
        
        # Add statistical annotation
        # Find the ANOVA p-value for this formant's CF × Group interaction
        try:
            anova_file = tables_path / f"anova_cf_group_{formant}.csv"
            if anova_file.exists():
                anova_results = pd.read_csv(anova_file)
                interaction_p = anova_results.loc[
                    anova_results.iloc[:, 0] == 'C(CF_Num):C(Group)', 'PR(>F)'].values[0]
                
                plt.text(
                    0.02, 0.02, 
                    f'CF × Group interaction p = {interaction_p:.4f}' + 
                    (' *' if interaction_p < 0.05 else ''),
                    transform=plt.gca().transAxes,
                    fontsize=12,
                    bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.5')
                )
        except (FileNotFoundError, IndexError, KeyError) as e:
            print(f"Could not add p-value annotation: {e}")
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'cf_comparison_{formant}.png', dpi=300)
        plt.savefig(figures_path / f'cf_comparison_{formant}.pdf', format='pdf')
        plt.close()
    
    # Create a visualization showing CF response by noise level for each group and formant
    # This is important to see how different frequency channels are affected by noise
    for formant in formants:
        for group in ['Healthy', 'ANSD']:
            # Filter data
            group_formant_data = all_data[
                (all_data['Formant'] == formant) & 
                (all_data['Group'] == group)
            ]
            
            # Create a figure with subplots for each noise level
            noise_levels = sorted(group_formant_data['NoiseLevel'].unique())
            n_noise = len(noise_levels)
            
            # Calculate grid dimensions (approximately square layout)
            n_cols = min(3, n_noise)  # Maximum 3 columns
            n_rows = (n_noise + n_cols - 1) // n_cols  # Ceiling division
            
            fig, axes = plt.subplots(n_rows, n_cols, figsize=(15, 4*n_rows), sharex=True, sharey=True)
            
            # Flatten axes array for easier indexing
            if n_rows > 1 and n_cols > 1:
                axes_flat = axes.flatten()
            elif n_rows == 1 and n_cols > 1:
                axes_flat = axes
            elif n_cols == 1 and n_rows > 1:
                axes_flat = axes
            else:
                axes_flat = [axes]
            
            # Plot each noise level
            for i, noise_level in enumerate(noise_levels):
                if i < len(axes_flat):
                    ax = axes_flat[i]
                    
                    # Filter for this noise level
                    noise_data = group_formant_data[group_formant_data['NoiseLevel'] == noise_level]
                    
                    # Group by CF_Num
                    cf_means = noise_data.groupby('CF_Num')['GW_Distance'].agg(['mean', 'sem']).reset_index()
                    
                    # Sort by CF_Num
                    cf_means = cf_means.sort_values('CF_Num')
                    
                    # Plot
                    ax.errorbar(
                        x=cf_means['CF_Num'],
                        y=cf_means['mean'],
                        yerr=cf_means['sem'],
                        fmt='o-',
                        capsize=3,
                        linewidth=1.5,
                        markersize=6
                    )
                    
                    # Set title and labels
                    ax.set_title(f'{noise_level}', fontsize=12)
                    
                    # Set x-ticks with CF numbers only (no Hz to avoid clutter)
                    ax.set_xticks(sorted(cf_means['CF_Num']))
                    ax.set_xticklabels([f'CF{n}' for n in sorted(cf_means['CF_Num'])])
                    
                    # Add grid
                    ax.grid(True, linestyle='--', alpha=0.5)
            
            # Hide any unused subplots
            for i in range(len(noise_levels), len(axes_flat)):
                axes_flat[i].set_visible(False)
            
            # Add shared x and y labels
            fig.text(0.5, 0.04, 'Center Frequency', ha='center', fontsize=14)
            fig.text(0.04, 0.5, 'GW Distance (Mean ± SEM)', va='center', rotation='vertical', fontsize=14)
            
            # Add main title
            plt.suptitle(f'{formant} - {group}: CF Response by Noise Level', fontsize=16, fontweight='bold')
            
            plt.tight_layout()
            plt.subplots_adjust(top=0.9)  # Make room for the main title
            
            #plt.savefig(figures_path / f'cf_noise_response_{formant}_{group}.png', dpi=300)
            plt.savefig(figures_path / f'cf_noise_response_{formant}_{group}.pdf', format='pdf')
            plt.close()
        
    # Create a heatmap visualizing the CF × Formant pattern for each group
    for group in ['Healthy', 'ANSD']:
        group_data = all_data[all_data['Group'] == group]
        
        # Pivot to create a matrix of CF × Formant
        pivot_data = group_data.pivot_table(
            index='CF_Num',
            columns='Formant',
            values='GW_Distance',
            aggfunc='mean'
        )
        
        plt.figure(figsize=(10, 8))
        sns.heatmap(
            pivot_data,
            annot=True,
            fmt='.2f',
            cmap='viridis',
            linewidths=0.5,
            cbar_kws={'label': 'Mean GW Distance'}
        )
        
        plt.title(f'CF × Formant Heatmap - {group}', fontsize=16, fontweight='bold')
        plt.xlabel('Formant', fontsize=14)
        plt.ylabel('Center Frequency', fontsize=14)
        
        # Customize y-tick labels with actual frequencies
        yticks = []
        for n in sorted(pivot_data.index):
            if n-1 < len(TARGET_FREQUENCIES):
                yticks.append(f'CF{n} ({TARGET_FREQUENCIES[n-1]} Hz)')
            else:
                yticks.append(f'CF{n}')
        
        plt.yticks(range(len(yticks)), yticks)
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'cf_formant_heatmap_{group}.png', dpi=300)
        plt.savefig(figures_path / f'cf_formant_heatmap_{group}.pdf', format='pdf')
        plt.close()
        
    # Advanced analysis: Create CF × NoiseLevel heatmaps for each formant and group
    # This provides a comprehensive visualization of how different frequency channels 
    # respond to different noise levels
    for formant in formants:
        for group in ['Healthy', 'ANSD']:
            # Filter data
            group_formant_data = all_data[
                (all_data['Formant'] == formant) & 
                (all_data['Group'] == group)
            ]
            
            # Create pivot table
            pivot_data = group_formant_data.pivot_table(
                index='CF_Num',
                columns='NoiseLevel',
                values='GW_Distance',
                aggfunc='mean'
            )
            
            # Sort noise levels in the desired order
            noise_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
            try:
                pivot_data = pivot_data.reindex(columns=noise_order)
            except:
                print(f"Could not reindex columns for {formant}, {group} heatmap - using available noise levels")
            
            # Create the heatmap
            plt.figure(figsize=(12, 8))
            
            # Use a diverging colormap centered around the median
            median_val = pivot_data.median().median()
            vmin = max(0, median_val - 2*pivot_data.std().mean())
            vmax = median_val + 2*pivot_data.std().mean()
            
            sns.heatmap(
                pivot_data,
                annot=True,
                fmt='.2f',
                cmap='RdBu_r',
                center=median_val,
                vmin=vmin,
                vmax=vmax,
                linewidths=0.5,
                cbar_kws={'label': 'Mean GW Distance'}
            )
            
            plt.title(f'{formant} - {group}: CF × Noise Level Response', 
                     fontsize=16, fontweight='bold')
            plt.xlabel('Noise Level', fontsize=14)
            plt.ylabel('Center Frequency', fontsize=14)
            
            # Customize y-tick labels with actual frequencies
            yticks = []
            for n in sorted(pivot_data.index):
                if n-1 < len(TARGET_FREQUENCIES):
                    yticks.append(f'CF{n} ({TARGET_FREQUENCIES[n-1]} Hz)')
                else:
                    yticks.append(f'CF{n}')
            
            plt.yticks(range(len(yticks)), yticks)
            
            plt.tight_layout()
            #plt.savefig(figures_path / f'cf_noise_heatmap_{formant}_{group}.png', dpi=300)
            plt.savefig(figures_path / f'cf_noise_heatmap_{formant}_{group}.pdf', format='pdf')
            plt.close()
            

# %%
# RESEARCH QUESTION 7: Are there differences in how phoneme categories are affected by noise in Healthy vs ANSD?
# This investigates the three-way interaction between Group, NoiseLevel, and Category

def analyze_three_way_interaction():
    """
    Analyze the three-way interaction between Group, NoiseLevel, and Category.
    This addresses the complex relationship between auditory neuropathy, 
    noise susceptibility, and phoneme-specific processing deficits, which
    is crucial for understanding the full spectrum of ANSD effects.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 7: Are there differences in how phoneme categories are affected by noise in Healthy vs ANSD?")
    print("="*80)
    
    # For each formant, run a three-way ANOVA
    three_way_results = []
    
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Create the formula - testing the three-way interaction
        formula = "GW_Distance ~ C(Group) * C(NoiseLevel) * C(Category)"
        
        # Fit the model
        model = ols(formula, data=formant_data).fit()
        
        # Get ANOVA table
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nThree-way ANOVA for {formant} - Testing Group × NoiseLevel × Category interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_three_way_{formant}.csv")
        
        # Extract the three-way interaction p-value
        try:
            three_way_p = anova_table.loc['C(Group):C(NoiseLevel):C(Category)', 'PR(>F)']
            print(f"Three-way interaction p-value: {three_way_p}")
            significant = three_way_p < 0.05
            print(f"Significant: {significant}")
            
            three_way_results.append({
                'Formant': formant,
                'P_Value': three_way_p,
                'Significant': significant
            })
        except KeyError:
            print("Three-way interaction term not found in ANOVA table.")
    
    # Save summary of three-way interaction results
    if three_way_results:
        three_way_df = pd.DataFrame(three_way_results)
        three_way_df.to_csv(tables_path / "three_way_interaction_summary.csv")
    
    # Analyze each phoneme category's response to noise in each group
    # This helps identify which phoneme categories show different patterns of noise 
    # susceptibility between Healthy and ANSD groups
    for category in phoneme_categories:
        print(f"\nAnalyzing {category} noise response between groups...")
        
        # Filter data for this category
        category_data = all_data[all_data['Category'] == category]
        
        # For each formant, analyze this category's response
        for formant in formants:
            formant_category_data = category_data[category_data['Formant'] == formant]
            
            # Test Group × NoiseLevel interaction for this category and formant
            formula = "GW_Distance ~ C(Group) * C(NoiseLevel)"
            model = ols(formula, data=formant_category_data).fit()
            
            anova_table = sm.stats.anova_lm(model, typ=2)
            print(f"\nANOVA for {category}, {formant} - Testing Group × NoiseLevel interaction:")
            print(anova_table)
            
            # Save ANOVA results
            anova_table.to_csv(tables_path / f"anova_group_noise_{category}_{formant}.csv")
            
            # Create a visualization showing the interaction for this category and formant
            # Create a summary for plotting
            interaction_summary = formant_category_data.groupby(['Group', 'NoiseLevel']).agg({
                'GW_Distance': ['mean', 'sem', 'count']
            }).reset_index()
            
            # Create a categorical noise level variable with proper ordering
            noise_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
            interaction_summary['NoiseLevel'] = pd.Categorical(
                interaction_summary['NoiseLevel'],
                categories=noise_order,
                ordered=True
            )
            
            # Sort by the ordered noise level
            interaction_summary = interaction_summary.sort_values(['Group', 'NoiseLevel'])
            
            # Create the interaction plot
            plt.figure(figsize=(12, 8))
            
            # Plot for Healthy group
            healthy_data = interaction_summary[interaction_summary['Group'] == 'Healthy']
            plt.errorbar(
                x=healthy_data['NoiseLevel'].cat.codes,  # Use category codes for x positions
                y=healthy_data['GW_Distance']['mean'],
                yerr=healthy_data['GW_Distance']['sem'],
                fmt='o-',
                color='#1f77b4',
                label='Healthy',
                capsize=5,
                linewidth=2,
                markersize=8
            )
            
            # Plot for ANSD group
            ansd_data = interaction_summary[interaction_summary['Group'] == 'ANSD']
            plt.errorbar(
                x=ansd_data['NoiseLevel'].cat.codes,  # Use category codes for x positions
                y=ansd_data['GW_Distance']['mean'],
                yerr=ansd_data['GW_Distance']['sem'],
                fmt='s-',
                color='#ff7f0e',
                label='ANSD',
                capsize=5,
                linewidth=2,
                markersize=8
            )
            
            # Set x-axis ticks and labels
            plt.xticks(range(len(noise_order)), noise_order, rotation=45, ha='right')
            
            # Add titles and labels
            plt.title(f'{category} Response to Noise - {formant}', fontsize=16, fontweight='bold')
            plt.xlabel('Noise Level', fontsize=14)
            plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
            plt.legend(fontsize=12)
            plt.grid(True, linestyle='--', alpha=0.7)
            
            # Add interaction p-value to the plot
            try:
                interaction_p = anova_table.loc['C(Group):C(NoiseLevel)', 'PR(>F)']
                plt.text(
                    0.02, 0.02, 
                    f'Group × Noise interaction p = {interaction_p:.4f}' + 
                    (' *' if interaction_p < 0.05 else ''),
                    transform=plt.gca().transAxes,
                    fontsize=12,
                    bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.5')
                )
            except (KeyError, IndexError) as e:
                print(f"Could not add p-value: {e}")
            
            plt.tight_layout()
            #plt.savefig(figures_path / f'{category}_noise_response_{formant}.png', dpi=300)
            plt.savefig(figures_path / f'{category}_noise_response_{formant}.pdf', format='pdf')
            plt.close()
    
    # Create a comprehensive heatmap showing phoneme category sensitivity to noise
    # This helps identify which phoneme categories show the largest differences
    # between healthy and ANSD subjects across noise conditions
    
    # First, compute the difference in GW distances between ANSD and Healthy
    # For each combination of Category, NoiseLevel, and Formant
    diff_data = []
    
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        for category in phoneme_categories:
            category_data = formant_data[formant_data['Category'] == category]
            
            for noise_level in noise_order:
                if noise_level in category_data['NoiseLevel'].values:
                    # Get mean GW distance for each group in this condition
                    noise_data = category_data[category_data['NoiseLevel'] == noise_level]
                    
                    healthy_mean = noise_data[noise_data['Group'] == 'Healthy']['GW_Distance'].mean()
                    ansd_mean = noise_data[noise_data['Group'] == 'ANSD']['GW_Distance'].mean()
                    
                    # Calculate difference (ANSD - Healthy)
                    diff = ansd_mean - healthy_mean
                    
                    diff_data.append({
                        'Formant': formant,
                        'Category': category,
                        'NoiseLevel': noise_level,
                        'Diff': diff,
                        'Healthy_Mean': healthy_mean,
                        'ANSD_Mean': ansd_mean
                    })
    
    # Convert to DataFrame
    diff_df = pd.DataFrame(diff_data)
    
    # Create a pivot table for each formant
    for formant in formants:
        formant_diff = diff_df[diff_df['Formant'] == formant]
        
        # Create pivot
        pivot_diff = formant_diff.pivot_table(
            index='Category',
            columns='NoiseLevel',
            values='Diff',
            aggfunc='mean'
        )
        
        # Sort noise levels in the desired order
        pivot_diff = pivot_diff.reindex(columns=noise_order)
        
        # Create heatmap
        plt.figure(figsize=(14, 8))
        
        # Use a diverging colormap centered at 0 (no difference)
        # Positive values (red): ANSD > Healthy
        # Negative values (blue): Healthy > ANSD
        max_abs_diff = max(abs(pivot_diff.min().min()), abs(pivot_diff.max().max()))
        
        sns.heatmap(
            pivot_diff,
            annot=True,
            fmt='.2f',
            cmap='RdBu_r',
            center=0,
            vmin=-max_abs_diff,
            vmax=max_abs_diff,
            linewidths=0.5,
            cbar_kws={'label': 'Mean GW Distance Difference (ANSD - Healthy)'}
        )
        
        plt.title(f'{formant}: Phoneme Category Sensitivity to Noise (ANSD - Healthy)', 
                 fontsize=16, fontweight='bold')
        plt.xlabel('Noise Level', fontsize=14)
        plt.ylabel('Phoneme Category', fontsize=14)
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'category_noise_diff_heatmap_{formant}.png', dpi=300)
        plt.savefig(figures_path / f'category_noise_diff_heatmap_{formant}.pdf', format='pdf')
        plt.close()
    
    # Additional analysis: Create a summary plot showing which phoneme categories 
    # show the largest overall differences between ANSD and Healthy
    
    # First, compute overall mean differences by phoneme category for each formant
    category_summary = []
    
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        for category in phoneme_categories:
            category_data = formant_data[formant_data['Category'] == category]
            
            healthy_mean = category_data[category_data['Group'] == 'Healthy']['GW_Distance'].mean()
            ansd_mean = category_data[category_data['Group'] == 'ANSD']['GW_Distance'].mean()
            diff = ansd_mean - healthy_mean
            
            # Calculate standard error of the difference
            healthy_sem = category_data[category_data['Group'] == 'Healthy']['GW_Distance'].sem()
            ansd_sem = category_data[category_data['Group'] == 'ANSD']['GW_Distance'].sem()
            # Approximate SEM of difference using error propagation
            diff_sem = np.sqrt(healthy_sem**2 + ansd_sem**2)
            
            category_summary.append({
                'Formant': formant,
                'Category': category,
                'Diff': diff,
                'Diff_SEM': diff_sem,
                'Healthy_Mean': healthy_mean,
                'ANSD_Mean': ansd_mean
            })
    
    # Convert to DataFrame
    category_summary_df = pd.DataFrame(category_summary)
    
    # Save summary to CSV
    category_summary_df.to_csv(tables_path / "category_group_diff_summary.csv")
    
    # Create a bar plot showing differences by category for each formant
    for formant in formants:
        formant_summary = category_summary_df[category_summary_df['Formant'] == formant]
        
        plt.figure(figsize=(12, 8))
        
        # Sort by difference magnitude for better visualization
        formant_summary = formant_summary.sort_values('Diff')
        
        # Create a color gradient based on difference values
        colors = plt.cm.RdBu_r(
            (formant_summary['Diff'] - formant_summary['Diff'].min()) / 
            (formant_summary['Diff'].max() - formant_summary['Diff'].min())
        )
        
        # Create bar plot
        bars = plt.bar(
            formant_summary['Category'],
            formant_summary['Diff'],
            yerr=formant_summary['Diff_SEM'],
            capsize=5,
            color=colors
        )
        
        # Add a horizontal line at y=0
        plt.axhline(y=0, color='black', linestyle='-', alpha=0.5)
        
        # Add labels and title
        plt.title(f'{formant}: Phoneme Category Differences (ANSD - Healthy)', 
                 fontsize=16, fontweight='bold')
        plt.xlabel('Phoneme Category', fontsize=14)
        plt.ylabel('GW Distance Difference (ANSD - Healthy)', fontsize=14)
        plt.xticks(rotation=45, ha='right')
        
        # Add value labels above each bar
        #for bar in bars:
        #    height = bar.get_height()
        #    plt.text(
        #        bar.get_x() + bar.get_width()/2.,
        #        height + (0.1 if height > 0 else -0.1),
        #        f'{height:.2f}',
        #        ha='center',
        #        va='bottom' if height > 0 else 'top',
        #        fontsize=10
        #    )
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'category_group_diff_bars_{formant}.png', dpi=300)
        plt.savefig(figures_path / f'category_group_diff_bars_{formant}.pdf', format='pdf')
        plt.close()

def create_integrated_summary():
    """
    Create a comprehensive summary of all findings, integrating results
    from all research questions to provide a holistic view of the data.
    """
    print("\n" + "="*80)
    print("Creating Integrated Summary of Findings")
    print("="*80)
    
    # Prepare a comprehensive summary DataFrame
    summary_rows = []
    
    # Summarize Group effects
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_group_effect_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'Group' in anova_data.index:
                    p_val = anova_data.loc['Group', 'PR(>F)']
                    f_val = anova_data.loc['Group', 'F']
                    
                    summary_rows.append({
                        'Question': 'Group Effect',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Summarize Noise effects
    for formant in formants:
        for group in ['Healthy', 'ANSD']:
            try:
                anova_file = tables_path / f"anova_noise_{group}_{formant}.csv"
                if anova_file.exists():
                    anova_data = pd.read_csv(anova_file, index_col=0)
                    if 'C(NoiseLevel)' in anova_data.index:
                        p_val = anova_data.loc['C(NoiseLevel)', 'PR(>F)']
                        f_val = anova_data.loc['C(NoiseLevel)', 'F']
                        
                        summary_rows.append({
                            'Question': 'Noise Effect',
                            'Group': group,
                            'Formant': formant,
                            'F_value': f_val,
                            'P_value': p_val,
                            'Significant': p_val < 0.05
                        })
            except Exception as e:
                print(f"Could not process {anova_file}: {e}")
    
    # Summarize Group × Noise interactions
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_interaction_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(Group):C(NoiseLevel)' in anova_data.index:
                    p_val = anova_data.loc['C(Group):C(NoiseLevel)', 'PR(>F)']
                    f_val = anova_data.loc['C(Group):C(NoiseLevel)', 'F']
                    
                    summary_rows.append({
                        'Question': 'Group × Noise Interaction',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Summarize Category effects
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_category_main_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(Category)' in anova_data.index:
                    p_val = anova_data.loc['C(Category)', 'PR(>F)']
                    f_val = anova_data.loc['C(Category)', 'F']
                    
                    summary_rows.append({
                        'Question': 'Category Effect',
                        'Formant': formant,
                        'F_value': f_val,
                        'P_value': p_val,
                        'Significant': p_val < 0.05
                    })
        except Exception as e:
            print(f"Could not process {anova_file}: {e}")
    
    # Summarize CF effects
    for formant in formants:
        try:
            anova_file = tables_path / f"anova_cf_group_{formant}.csv"
            if anova_file.exists():
                anova_data = pd.read_csv(anova_file, index_col=0)
                if 'C(CF_Num):C(Group)' in anova_data.index:
                    p_val = anova_data.loc['C(CF_Num):C(Group)', 'PR(>F)']
                    f_val = anova_data.loc['C(CF_Num):C(Group)', 'F']
                    
                    summary_rows.append({
                        'Question': 'CF × Group Interaction',
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
            
        

# %%
# Run all analyses
def run_all_analyses():
    """
    Execute all research question analyses.
    This function runs all the statistical tests and generates all visualizations.
    """
    print("\n" + "="*80)
    print("RUNNING ALL STATISTICAL ANALYSES")
    print("="*80)
    
    # Define the target frequencies constant for CF labels
    global TARGET_FREQUENCIES
    TARGET_FREQUENCIES = [250, 500, 1000, 2000, 4000, 8000]  # Hz
    
    # First set of analyses (Questions 1-4)
    print("\nRunning first set of analyses (Questions 1-4)...")
    analyze_group_differences()  # Question 1
    analyze_noise_effects()      # Question 2
    analyze_group_noise_interaction()  # Question 3
    analyze_phoneme_category_effects()  # Question 4
    
    # Second set of analyses (Questions 5-7)
    print("\nRunning second set of analyses (Questions 5-7)...")
    analyze_formant_differences()  # Question 5
    analyze_cf_effects()  # Question 6
    analyze_three_way_interaction()  # Question 7
    
    # Create integrated summary
    create_integrated_summary()
    
    print("\n" + "="*80)
    print("ALL ANALYSES COMPLETE")
    print(f"Results saved to {output_path}")
    print("="*80)

# %%
# RESEARCH QUESTION 2: How do noise conditions affect OT distances within each group?
# This explores how different noise levels impact the OT distances, separately for each group

def analyze_noise_effects():
    """
    Analyze how different noise conditions affect OT distances within each group.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 2: How do noise conditions affect OT distances within each group?")
    print("="*80)
    
    # Create summary statistics by noise level for each group
    summary_by_noise = all_data.groupby(['Group', 'NoiseLevel', 'Formant']).agg({
        'GW_Distance': ['mean', 'std', 'count']
    }).reset_index()
    
    print("Summary statistics by noise level within each group:")
    print(summary_by_noise)
    
    # Save summary statistics
    summary_by_noise.to_csv(tables_path / "noise_effect_summary.csv")
    
    # Run repeated measures ANOVA for each group and formant
    for group in ['Healthy', 'ANSD']:
        group_data = all_data[all_data['Group'] == group]
        
        for formant in formants:
            formant_data = group_data[group_data['Formant'] == formant]
            
            try:
                # Using pingouin for repeated measures ANOVA
                # We're treating Category as the subject (repeated measures across noise levels)
                # This assumes you have measurements for each category across noise levels
                aov = pg.rm_anova(
                    data=formant_data,
                    dv='GW_Distance',
                    within='NoiseLevel',
                    subject='Category',
                    detailed=True
                )
                
                print(f"\nRepeated measures ANOVA for {group}, {formant}:")
                print(aov)
                
                # Save ANOVA results
                aov.to_csv(tables_path / f"rm_anova_{group}_{formant}.csv")
                
                # If significant effect of noise level, perform post-hoc tests
                if aov.loc[aov['Source'] == 'NoiseLevel', 'p-unc'].values[0] < 0.05:
                    # Perform post-hoc paired t-tests with correction
                    posthoc = pg.pairwise_ttests(
                        data=formant_data,
                        dv='GW_Distance',
                        within='NoiseLevel',
                        subject='Category',
                        padjust='bonf'  # Bonferroni correction
                    )
                    
                    print("\nPost-hoc tests:")
                    print(posthoc)
                    
                    # Save post-hoc results
                    posthoc.to_csv(tables_path / f"posthoc_{group}_{formant}.csv")
            except Exception as e:
                print(f"Error performing rm_anova for {group}, {formant}: {e}")
                # Fall back to one-way ANOVA if repeated measures fails
                formula = "GW_Distance ~ C(NoiseLevel)"
                model = ols(formula, data=formant_data).fit()
                anova_table = sm.stats.anova_lm(model, typ=2)
                
                print(f"\nOne-way ANOVA for {group}, {formant} - Effect of Noise Level:")
                print(anova_table)
                
                # Save ANOVA results
                anova_table.to_csv(tables_path / f"anova_noise_{group}_{formant}.csv")
    
    # Create visualizations showing noise effects for each group
    noise_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
    
    for group in ['Healthy', 'ANSD']:
        group_data = all_data[all_data['Group'] == group]
        
        fig, axes = plt.subplots(len(formants), 1, figsize=(15, 18), sharex=True)
        
        for i, formant in enumerate(formants):
            formant_data = group_data[group_data['Formant'] == formant]
            
            # Create box plots by noise level
            sns.boxplot(
                x='NoiseLevel', y='GW_Distance', 
                order=noise_order,
                data=formant_data, 
                ax=axes[i],
                palette='viridis'
            )
            
            # Add individual data points
            sns.swarmplot(
                x='NoiseLevel', y='GW_Distance', 
                order=noise_order,
                data=formant_data, 
                ax=axes[i],
                color='black', alpha=0.5, size=3
            )
            
            axes[i].set_title(f'{formant} - {group}', fontsize=14, fontweight='bold')
            axes[i].set_ylabel('GW Distance', fontsize=12)
            
            # Rotate x-labels for better readability
            if i == len(formants) - 1:
                axes[i].set_xlabel('Noise Level', fontsize=12)
                plt.setp(axes[i].get_xticklabels(), rotation=45, ha='right')
            else:
                axes[i].set_xlabel('')
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'noise_effect_{group}.png', dpi=300)
        plt.savefig(figures_path / f'noise_effect_{group}.pdf', format='pdf')
        plt.close()

# %%
# RESEARCH QUESTION 3: Is the effect of noise different between Healthy and ANSD groups?
# This analyzes the interaction between group and noise level

def analyze_group_noise_interaction():
    """
    Analyze whether the effect of noise differs between Healthy and ANSD groups.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 3: Is the effect of noise different between Healthy and ANSD groups?")
    print("="*80)
    
    # For each formant, run a two-way ANOVA with interaction
    interaction_results = []
    
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Create the formula - testing Group, NoiseLevel, and their interaction
        formula = "GW_Distance ~ C(Group) * C(NoiseLevel) + C(Category)"
        
        # Fit the model
        model = ols(formula, data=formant_data).fit()
        
        # Get ANOVA table
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nTwo-way ANOVA for {formant} - Testing Group * NoiseLevel interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_interaction_{formant}.csv")
        
        # Extract interaction p-value
        interaction_p = anova_table.loc['C(Group):C(NoiseLevel)', 'PR(>F)']
        interaction_results.append({
            'Formant': formant,
            'Interaction_P_Value': interaction_p,
            'Significant': interaction_p < 0.05
        })
    
    # Summarize interaction results
    interaction_df = pd.DataFrame(interaction_results)
    print("\nSummary of Group * NoiseLevel interaction effects:")
    print(interaction_df)
    
    # Save interaction summary
    interaction_df.to_csv(tables_path / "group_noise_interaction_summary.csv")
    
    # Create visualization showing the interaction
    # This will be a line plot with noise levels on x-axis, separate lines for groups
    
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Calculate means for each group and noise level
        interaction_means = formant_data.groupby(['Group', 'NoiseLevel'])['GW_Distance'].agg(['mean', 'sem']).reset_index()
        
        # Create a categorical noise level variable with proper ordering
        noise_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
        interaction_means['NoiseLevel'] = pd.Categorical(
            interaction_means['NoiseLevel'],
            categories=noise_order,
            ordered=True
        )
        
        # Sort by the ordered noise level
        interaction_means = interaction_means.sort_values(['Group', 'NoiseLevel'])
        
        # Create the interaction plot
        plt.figure(figsize=(12, 8))
        
        # Plot for Healthy group
        healthy_data = interaction_means[interaction_means['Group'] == 'Healthy']
        plt.errorbar(
            x=healthy_data['NoiseLevel'].cat.codes,  # Use category codes for x positions
            y=healthy_data['mean'],
            yerr=healthy_data['sem'],
            fmt='o-',
            color='#1f77b4',
            label='Healthy',
            capsize=5,
            linewidth=2,
            markersize=8
        )
        
        # Plot for ANSD group
        ansd_data = interaction_means[interaction_means['Group'] == 'ANSD']
        plt.errorbar(
            x=ansd_data['NoiseLevel'].cat.codes,  # Use category codes for x positions
            y=ansd_data['mean'],
            yerr=ansd_data['sem'],
            fmt='s-',
            color='#ff7f0e',
            label='ANSD',
            capsize=5,
            linewidth=2,
            markersize=8
        )
        
        # Set x-axis ticks and labels
        plt.xticks(range(len(noise_order)), noise_order, rotation=45, ha='right')
        
        # Add titles and labels
        plt.title(f'Group × Noise Level Interaction - {formant}', fontsize=16, fontweight='bold')
        plt.xlabel('Noise Level', fontsize=14)
        plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
        plt.legend(fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)
        
        # Add text showing interaction p-value
        interaction_p = interaction_df[interaction_df['Formant'] == formant]['Interaction_P_Value'].values[0]
        plt.text(
            0.02, 0.02, 
            f'Interaction p = {interaction_p:.4f}' + (' *' if interaction_p < 0.05 else ''),
            transform=plt.gca().transAxes,
            fontsize=12,
            bbox=dict(facecolor='white', alpha=0.8, boxstyle='round,pad=0.5')
        )
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'interaction_plot_{formant}.png', dpi=300)
        plt.savefig(figures_path / f'interaction_plot_{formant}.pdf', format='pdf')
        plt.close()

# %%
# RESEARCH QUESTION 4: Do these patterns differ across phoneme categories?
# This examines whether the effects of Group and Noise differ by phoneme category

def analyze_phoneme_category_effects():
    """
    Analyze whether the effects of Group and Noise differ across phoneme categories.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 4: Do these patterns differ across phoneme categories?")
    print("="*80)
    
    # For each formant, analyze category differences
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # First, test if categories differ overall
        formula = "GW_Distance ~ C(Category) + C(Group) + C(NoiseLevel)"
        model = ols(formula, data=formant_data).fit()
        
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nANOVA for {formant} - Testing Category main effect:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_category_main_{formant}.csv")
        
        # Test for Category × Group interaction
        formula = "GW_Distance ~ C(Category) * C(Group) + C(NoiseLevel)"
        model = ols(formula, data=formant_data).fit()
        
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nANOVA for {formant} - Testing Category × Group interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_category_group_{formant}.csv")
        
        # Test for Category × NoiseLevel interaction
        formula = "GW_Distance ~ C(Category) * C(NoiseLevel) + C(Group)"
        model = ols(formula, data=formant_data).fit()
        
        anova_table = sm.stats.anova_lm(model, typ=2)
        print(f"\nANOVA for {formant} - Testing Category × NoiseLevel interaction:")
        print(anova_table)
        
        # Save ANOVA results
        anova_table.to_csv(tables_path / f"anova_category_noise_{formant}.csv")
        
        # If significant category differences, perform post-hoc tests
        formula = "GW_Distance ~ C(Category)"
        model = ols(formula, data=formant_data).fit()
        anova_table = sm.stats.anova_lm(model, typ=2)
        
        if anova_table.loc['C(Category)', 'PR(>F)'] < 0.05:
            # Perform Tukey's HSD post-hoc test for categories
            from statsmodels.stats.multicomp import pairwise_tukeyhsd
            
            tukey = pairwise_tukeyhsd(
                formant_data['GW_Distance'], 
                formant_data['Category'],
                alpha=0.05
            )
            
            print(f"\nTukey's HSD post-hoc tests for categories in {formant}:")
            print(tukey)
            
            # Save to a more readable format
            tukey_df = pd.DataFrame(
                data=tukey._results_table.data[1:],
                columns=tukey._results_table.data[0]
            )
            
            tukey_df.to_csv(tables_path / f"tukey_category_{formant}.csv")
    
    # Create a visualization showing category differences for each group
    for formant in formants:
        formant_data = all_data[all_data['Formant'] == formant]
        
        # Create a figure with subplots for Healthy and ANSD
        fig, axes = plt.subplots(2, 1, figsize=(14, 16), sharex=True)
        
        # Plot for Healthy group
        healthy_data = formant_data[formant_data['Group'] == 'Healthy']
        sns.boxplot(
            x='Category', y='GW_Distance', hue='NoiseLevel',
            hue_order=["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"],
            data=healthy_data,
            ax=axes[0],
            palette='viridis'
        )
        
        axes[0].set_title(f'{formant} - Healthy - Category Differences', fontsize=14, fontweight='bold')
        axes[0].set_ylabel('GW Distance', fontsize=12)
        axes[0].set_xlabel('')
        axes[0].legend(title='Noise Level', bbox_to_anchor=(1.02, 1), loc='upper left')
        
        # Plot for ANSD group
        ansd_data = formant_data[formant_data['Group'] == 'ANSD']
        sns.boxplot(
            x='Category', y='GW_Distance', hue='NoiseLevel',
            hue_order=["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"],
            data=ansd_data,
            ax=axes[1],
            palette='viridis'
        )
        
        axes[1].set_title(f'{formant} - ANSD - Category Differences', fontsize=14, fontweight='bold')
        axes[1].set_ylabel('GW Distance', fontsize=12)
        axes[1].set_xlabel('Phoneme Category', fontsize=14)
        axes[1].legend(title='Noise Level', bbox_to_anchor=(1.02, 1), loc='upper left')
        
        plt.tight_layout()
        #plt.savefig(figures_path / f'category_differences_{formant}.png', dpi=300)
        plt.savefig(figures_path / f'category_differences_{formant}.pdf', format='pdf')
        plt.close()

# %%
# RESEARCH QUESTION 5: Are there differences in how F1, F2, and F3 are affected?
# This examines whether the three formants show different patterns

def analyze_formant_differences():
    """
    Analyze whether F1, F2, and F3 show different patterns in their OT distances.
    This addresses whether the formants are differentially affected in processing,
    which provides insights into specific frequency-related perceptual mechanisms.
    """
    print("\n" + "="*80)
    print("RESEARCH QUESTION 5: Are there differences in how F1, F2, and F3 are affected?")
    print("="*80)
    
    # Test for overall formant differences
    formula = "GW_Distance ~ C(Formant) + C(Group) + C(NoiseLevel) + C(Category)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing Formant main effect:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_formant_main.csv")
    
    # Test for Formant × Group interaction
    formula = "GW_Distance ~ C(Formant) * C(Group) + C(NoiseLevel) + C(Category)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing Formant × Group interaction:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_formant_group.csv")
    
    # Test for Formant × NoiseLevel interaction
    formula = "GW_Distance ~ C(Formant) * C(NoiseLevel) + C(Group) + C(Category)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing Formant × NoiseLevel interaction:")
    print(anova_table)
    
    # Save ANOVA results
    anova_table.to_csv(tables_path / "anova_formant_noise.csv")
    
    # More complex interaction: Formant × Group × NoiseLevel
    formula = "GW_Distance ~ C(Formant) * C(Group) * C(NoiseLevel) + C(Category)"
    model = ols(formula, data=all_data).fit()
    
    anova_table = sm.stats.anova_lm(model, typ=2)
    print("\nANOVA - Testing Formant × Group × NoiseLevel interaction:")
    print(anova_table)
    
    # Save more complex interaction results
    anova_table.to_csv(tables_path / "anova_formant_group_noise.csv")
    
    # If significant formant differences, perform post-hoc tests
    formula = "GW_Distance ~ C(Formant)"
    model = ols(formula, data=all_data).fit()
    anova_table = sm.stats.anova_lm(model, typ=2)
    
    if anova_table.loc['C(Formant)', 'PR(>F)'] < 0.05:
        # Perform Tukey's HSD post-hoc test for formants
        from statsmodels.stats.multicomp import pairwise_tukeyhsd
        
        tukey = pairwise_tukeyhsd(
            all_data['GW_Distance'], 
            all_data['Formant'],
            alpha=0.05
        )
        
        print("\nTukey's HSD post-hoc tests for formants:")
        print(tukey)
        
        # Save to a more readable format
        tukey_df = pd.DataFrame(
            data=tukey._results_table.data[1:],
            columns=tukey._results_table.data[0]
        )
        
        tukey_df.to_csv(tables_path / "tukey_formant.csv")
    
    # Create visualizations comparing formants
    # First, a direct comparison of formants by group
    plt.figure(figsize=(10, 8))
    
    sns.boxplot(
        x='Formant', y='GW_Distance', hue='Group',
        data=all_data,
        palette=['#1f77b4', '#ff7f0e']
    )
    
    # Add individual data points for better visualization of distribution
    sns.stripplot(
        x='Formant', y='GW_Distance', hue='Group',
        data=all_data.sample(frac=0.2),  # Sample to avoid overcrowding
        dodge=True, alpha=0.3, size=3
    )
    
    plt.title('Comparison of F1, F2, and F3 Distances by Group', fontsize=16, fontweight='bold')
    plt.xlabel('Formant', fontsize=14)
    plt.ylabel('GW Distance', fontsize=14)
    
    # Fix the legend to avoid duplication from stripplot
    handles, labels = plt.gca().get_legend_handles_labels()
    plt.legend(handles[:2], labels[:2], title='Group', fontsize=12)
    
    plt.tight_layout()
    #plt.savefig(figures_path / 'formant_comparison_by_group.png', dpi=300)
    plt.savefig(figures_path / 'formant_comparison_by_group.pdf', format='pdf')
    plt.close()
    
    # Now, visualization showing formant × noise level interaction
    plt.figure(figsize=(14, 10))
    
    # Calculate means and standard errors
    formant_noise_means = all_data.groupby(['Formant', 'NoiseLevel'])['GW_Distance'].agg(['mean', 'sem']).reset_index()
    
    # Create a categorical noise level variable with proper ordering
    noise_order = ["SNR -5.0", "SNR 0.0", "SNR 5.0", "SNR 10.0", "SNR 15.0", "Random Noise", "Silence"]
    formant_noise_means['NoiseLevel'] = pd.Categorical(
        formant_noise_means['NoiseLevel'],
        categories=noise_order,
        ordered=True
    )
    
    # Sort by the ordered noise level
    formant_noise_means = formant_noise_means.sort_values(['Formant', 'NoiseLevel'])
    
    # Create the interaction plot with a distinct color palette
    for formant, color in zip(formants, ['#1f77b4', '#ff7f0e', '#2ca02c']):
        formant_data = formant_noise_means[formant_noise_means['Formant'] == formant]
        
        plt.errorbar(
            x=formant_data['NoiseLevel'].cat.codes,  # Use category codes for x positions
            y=formant_data['mean'],
            yerr=formant_data['sem'],
            fmt='o-',
            color=color,
            label=formant,
            capsize=5,
            linewidth=2,
            markersize=8
        )
    
    # Set x-axis ticks and labels
    plt.xticks(range(len(noise_order)), noise_order, rotation=45, ha='right')
    
    # Add titles and labels
    plt.title('Formant × Noise Level Interaction', fontsize=16, fontweight='bold')
    plt.xlabel('Noise Level', fontsize=14)
    plt.ylabel('GW Distance (Mean ± SEM)', fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, linestyle='--', alpha=0.7)
    
    # Further visualization: Separate formant noise response by group
    fig, axes = plt.subplots(1, 3, figsize=(18, 6), sharey=True)
    
    for i, formant in enumerate(formants):
        # Calculate group-specific means by noise level
        group_noise_means = all_data[all_data['Formant'] == formant].groupby(
            ['Group', 'NoiseLevel']
        )['GW_Distance'].agg(['mean', 'sem']).reset_index()
        
        # Apply categorical ordering
        group_noise_means['NoiseLevel'] = pd.Categorical(
            group_noise_means['NoiseLevel'],
            categories=noise_order,
            ordered=True
        )
        group_noise_means = group_noise_means.sort_values(['Group', 'NoiseLevel'])
        
        # Plot for each group
        for group, style, color in zip(['Healthy', 'ANSD'], ['o-', 's--'], ['#1f77b4', '#ff7f0e']):
            group_data = group_noise_means[group_noise_means['Group'] == group]
            
            axes[i].errorbar(
                x=group_data['NoiseLevel'].cat.codes,
                y=group_data['mean'],
                yerr=group_data['sem'],
                fmt=style,
                color=color,
                label=group,
                capsize=4,
                linewidth=2,
                markersize=6
            )
        
        # Set title and format
        axes[i].set_title(f'{formant}', fontsize=14, fontweight='bold')
        axes[i].set_xticks(range(len(noise_order)))
        axes[i].set_xticklabels(noise_order, rotation=45, ha='right', fontsize=10)
        axes[i].grid(True, linestyle='--', alpha=0.5)
        
        # Only add y-label to first subplot
        if i == 0:
            axes[i].set_ylabel('GW Distance (Mean ± SEM)', fontsize=12)
        
        # Only add legend to first subplot
        if i == 0:
            axes[i].legend(fontsize=10)
    
    plt.suptitle('Formant-specific Responses to Noise by Group', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.subplots_adjust(top=0.88)  # Make room for the main title
    
    #plt.savefig(figures_path / 'formant_group_noise_interaction.png', dpi=300)
    plt.savefig(figures_path / 'formant_group_noise_interaction.pdf', format='pdf')
    plt.close()
    
    plt.tight_layout()
    #plt.savefig(figures_path / 'formant_noise_interaction.png', dpi=300)
    plt.savefig(figures_path / 'formant_noise_interaction.pdf', format='pdf')
    plt.close()

def create_summary_report():
    """
    Create a markdown report summarizing the key findings from all analyses.
    """
    report_content = """# Statistical Analysis Summary Report
## Optimal Transport Distances in ANSD vs. Healthy Subjects

This report summarizes the key findings from statistical analyses of Optimal Transport (OT) distances 
between formants (F1, F2, F3) and center frequencies in Healthy subjects compared to subjects with 
Auditory Neuropathy Spectrum Disorder (ANSD), across various noise conditions and phoneme categories.

### Key Research Questions

1. **Group Differences**: Is there a significant difference in OT distances between Healthy and ANSD groups?
2. **Noise Effects**: How do noise conditions affect OT distances within each group?
3. **Group × Noise Interaction**: Is the effect of noise different between Healthy and ANSD groups?
4. **Phoneme Category Effects**: Do these patterns differ across phoneme categories?
5. **Formant Differences**: Are there differences in how F1, F2, and F3 are affected?
6. **Center Frequency Effects**: How do center frequencies (CFs) affect OT distances in each group?
7. **Three-way Interaction**: Are there differences in how phoneme categories are affected by noise in Healthy vs ANSD?

### Key Findings

[This section will be populated based on the analysis results]

### Conclusions

[This section will summarize the overall implications of the findings]
"""
    
    # Write the report to a file
    with open(output_path / "summary_report.md", "w") as f:
        f.write(report_content)
    
    print(f"Summary report template created at {output_path / 'summary_report.md'}")
    print("Please edit this template with the actual findings from your analysis.")    

# %%
# Main execution script
if __name__ == "__main__":
    # Run all analyses
    run_all_analyses()
    
    # Create summary report template
    create_summary_report()
    
    print(f"All analyses and reports have been saved to {output_path}")
# %%    