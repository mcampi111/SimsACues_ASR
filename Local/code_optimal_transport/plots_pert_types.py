import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

def create_visualizations(results_file, output_dir):
    """Create visualizations for the analysis results from a pickle or CSV file."""
    # Load results
    print(f"Loading results from {results_file}")
    if results_file.endswith('.csv'):
        results_df = pd.read_csv(results_file)
    else:
        results_df = pd.read_pickle(results_file)
    
    print(f"Loaded {len(results_df)} results")
    
    # Create output directory
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
    plt.close()
    
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
        plt.close()
        
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
            plt.close()
    
    # 4. Line plots for each formant across perturbation types
    plt.figure(figsize=(15, 10))
    
    # Aggregate by formant and perturbation
    formant_agg = results_df.groupby(['Formant', 'PerturbationType'])['GW_Distance'].mean().reset_index()
    
    # Plot
    sns.lineplot(data=formant_agg, x='Formant', y='GW_Distance', hue='PerturbationType', marker='o', markersize=10)
    plt.title('Mean GW Distance by Formant and Perturbation Type')
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'formant_perturbation_line.png'), dpi=300)
    plt.close()
    
    # 5. Category comparison - bar plot
    plt.figure(figsize=(16, 12))
    category_agg = results_df.groupby(['Category', 'PerturbationType'])['GW_Distance'].mean().reset_index()
    sns.barplot(data=category_agg, x='Category', y='GW_Distance', hue='PerturbationType')
    plt.title('Mean GW Distance by Category and Perturbation Type')
    plt.xticks(rotation=45, ha='right')
    plt.grid(True, axis='y', linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'category_perturbation_bar.png'), dpi=300)
    plt.close()
    
    # 6. Correlation between CF frequency and GW distance
    plt.figure(figsize=(12, 8))
    sns.scatterplot(data=results_df, x='CF_Freq', y='GW_Distance', hue='Formant', style='PerturbationType', s=100)
    plt.xscale('log')  # Use log scale for frequency
    plt.title('GW Distance vs. CF Frequency')
    plt.xlabel('Center Frequency (Hz, log scale)')
    plt.ylabel('GW Distance')
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'cf_freq_vs_distance.png'), dpi=300)
    plt.close()
    
    print(f"All visualizations created successfully in {output_dir}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Create visualizations from formant-CF distance results')
    parser.add_argument('--results', type=str, required=True, 
                        help='Path to results file (CSV or pickle)')
    parser.add_argument('--output', type=str, default='visualizations',
                        help='Output directory for visualizations')
    
    args = parser.parse_args()
    
    # Convert to absolute paths
    results_file = os.path.abspath(args.results)
    output_dir = os.path.abspath(args.output)
    
    if not os.path.exists(results_file):
        print(f"Error: Results file {results_file} does not exist")
        exit(1)
    
    create_visualizations(results_file, output_dir)