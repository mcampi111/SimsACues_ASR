# %%
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.io import loadmat
import seaborn as sns
from scipy.interpolate import interp1d
import ot
import pickle
from joblib import Parallel, delayed
import multiprocessing


# %%

# %%

######################################
# PART 1: FUNCTION DEFINITIONS       #
######################################

# Improved Acoustic Distance (base function for both overall and individual)
def improved_acoustic_distance(x, y):
    epsilon = 1e-10
    x = x + epsilon
    y = y + epsilon
    
    def freq_to_mel(f):
        return 2595 * np.log10(1 + f/700)
    
    x_mel = freq_to_mel(x)
    y_mel = freq_to_mel(y)
    
    return np.abs(x_mel - y_mel) / max(x_mel, y_mel)

# Overall Improved Acoustic
def compute_gw_distance_acoustic_improved(formants, cf_values):
    formants = np.array(formants)
    cf_values = np.array(cf_values)
    
    C1 = np.zeros((len(formants), len(formants)))
    C2 = np.zeros((len(cf_values), len(cf_values)))
    
    for i in range(len(formants)):
        for j in range(len(formants)):
            C1[i,j] = improved_acoustic_distance(formants[i], formants[j])
            
    for i in range(len(cf_values)):
        for j in range(len(cf_values)):
            C2[i,j] = improved_acoustic_distance(cf_values[i], cf_values[j])
    
    C1 = C1 / np.max(C1) if np.max(C1) > 0 else C1
    C2 = C2 / np.max(C2) if np.max(C2) > 0 else C2
    
    p = ot.unif(len(formants))
    q = ot.unif(len(cf_values))
    
    return ot.gromov.gromov_wasserstein2(C1, C2, p, q, loss_fun='square_loss')

# Space-wise Overall
def compute_space_gw_distance_overall(df, category, neurogram_type):
    category_df = df[df['Category'] == category]
    formant_space = category_df[['f1_mean', 'f2_mean', 'f3_mean']].values
    cf_cols = [f'{neurogram_type}_CF{i}' for i in range(1, 7)]
    cf_space = category_df[cf_cols].values
    
    C1 = ot.dist(formant_space, formant_space)
    C2 = ot.dist(cf_space, cf_space)
    
    C1 = C1 / C1.max() if C1.max() > 0 else C1
    C2 = C2 / C2.max() if C2.max() > 0 else C2
    
    p = ot.unif(len(formant_space))
    q = ot.unif(len(cf_space))
    
    return ot.gromov.gromov_wasserstein2(C1, C2, p, q, loss_fun='square_loss')

# Space-wise Individual
def compute_space_gw_distance_individual(df, formant_name, cf_num, neurogram_type, category):
    category_df = df[df['Category'] == category]
    formant_space = category_df[f'{formant_name}_mean'].values.reshape(-1, 1)
    cf_space = category_df[f'{neurogram_type}_CF{cf_num}'].values.reshape(-1, 1)
    
    C1 = ot.dist(formant_space, formant_space)
    C2 = ot.dist(cf_space, cf_space)
    
    C1 = C1 / C1.max() if C1.max() > 0 else C1
    C2 = C2 / C2.max() if C2.max() > 0 else C2
    
    p = ot.unif(len(formant_space))
    q = ot.unif(len(cf_space))
    
    return ot.gromov.gromov_wasserstein2(C1, C2, p, q, loss_fun='square_loss')




# %%
##############
#READING DATA# 
##############




# %%
######################################
# PART 2: COMPUTE ALL DISTANCES      #
######################################

# 1. Improved Acoustic Overall
improved_acoustic_overall = []
for idx, row in merged_df_clean.iterrows():
    formants = [row['f1_mean'], row['f2_mean'], row['f3_mean']]
    for ntype in ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']:
        try:
            cf_values = [row[f'{ntype}_CF{i}'] for i in range(1, 7)]
            gw_dist = compute_gw_distance_acoustic_improved(formants, cf_values)
            improved_acoustic_overall.append({
                'Category': row['Category'],
                'Neurogram_Type': ntype,
                'Distance': round(gw_dist, 2),
                'Method': 'Improved Acoustic Overall'
            })
        except Exception as e:
            print(f"Error in improved acoustic overall at idx {idx}, {ntype}: {e}")

# %%
# 2. Space-wise Overall
space_overall = []
for category in merged_df_clean['Category'].unique():
    for ntype in ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']:
        try:
            dist = compute_space_gw_distance_overall(merged_df_clean, category, ntype)
            space_overall.append({
                'Category': category,
                'Neurogram_Type': ntype,
                'Distance': round(dist, 2),
                'Method': 'Space-wise Overall'
            })
        except Exception as e:
            print(f"Error in space overall for {category}, {ntype}: {e}")

# %%
# 3. Space-wise Individual
space_individual = []
for category in merged_df_clean['Category'].unique():
    for formant in ['f1', 'f2', 'f3']:
        for cf_num in range(1, 7):
            for ntype in ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']:
                try:
                    dist = compute_space_gw_distance_individual(
                        merged_df_clean, formant, cf_num, ntype, category)
                    space_individual.append({
                        'Category': category,
                        'Formant': formant.upper(),
                        'CF': f'CF{cf_num}',
                        'Neurogram_Type': ntype,
                        'Distance': round(dist, 2),
                        'Method': 'Space-wise Individual'
                    })
                except Exception as e:
                    print(f"Error in space individual for {category}, {formant}, CF{cf_num}, {ntype}: {e}")

# %%
# 4. Improved Acoustic Individual
improved_acoustic_individual = []
for idx, row in merged_df_clean.iterrows():
    formants = {'F1': row['f1_mean'], 'F2': row['f2_mean'], 'F3': row['f3_mean']}
    for formant_name, formant_value in formants.items():
        for cf_num in range(1, 7):
            for ntype in ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']:
                try:
                    cf_value = row[f'{ntype}_CF{cf_num}']
                    distance = improved_acoustic_distance(formant_value, cf_value)
                    improved_acoustic_individual.append({
                        'Category': row['Category'],
                        'Formant': formant_name,
                        'CF': f'CF{cf_num}',
                        'Neurogram_Type': ntype,
                        'Distance': round(distance, 2),
                        'Method': 'Improved Acoustic Individual'
                    })
                except Exception as e:
                    print(f"Error in improved acoustic individual at idx {idx}, {formant_name}, CF{cf_num}, {ntype}: {e}")

# %%
