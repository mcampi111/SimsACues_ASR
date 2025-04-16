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

from scipy.spatial.distance import cdist
from scipy.interpolate import interp1d
from scipy.stats import variation
from scipy.signal import correlate
from scipy import stats
import ast  # for safely evaluating strings as literals

# %%

#############
# FUNCTIONS #
#############

# Define function to plot activation profiles
def plot_activation_profiles_comparison(df_ansd, target_length=1500, num_freq_bands=6):
    """
    Plot activation profiles for each phoneme category with consistent time length.
    
    Parameters:
    df_ansd (DataFrame): DataFrame with ANSD neurogram data.
    target_length (int): The length to interpolate neurograms to for consistent plotting.
    num_freq_bands (int): Number of frequency bands in the neurogram.
    """
    phoneme_categories = df_ansd['Category'].unique()
    neurogram_types = ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']
    colors = plt.cm.rainbow(np.linspace(0, 1, num_freq_bands))
    
    for category in phoneme_categories:
        fig, axes = plt.subplots(1, 4, figsize=(20, 5), sharey=True)
        fig.suptitle(f'Activation Profiles by Phoneme Category: {category}')
        
        category_data = df_ansd[df_ansd['Category'] == category]
        
        for i, neurogram_type in enumerate(neurogram_types):
            band_profiles = [[] for _ in range(num_freq_bands)]
            
            for _, row in category_data.iterrows():
                neurogram = row[neurogram_type]
                if isinstance(neurogram, np.ndarray) and neurogram.ndim == 2:
                    for band in range(num_freq_bands):
                        profile = neurogram[:, band]
                        x_original = np.linspace(0, 1, len(profile))
                        f = interp1d(x_original, profile, kind='linear', bounds_error=False, fill_value="extrapolate")
                        interpolated_profile = f(np.linspace(0, 1, target_length))
                        band_profiles[band].append(interpolated_profile)
            
            x = np.linspace(0, 1, target_length)
            for band, profiles in enumerate(band_profiles):
                if profiles:
                    mean_profile = np.mean(profiles, axis=0)
                    axes[i].plot(x, mean_profile, color=colors[band], label=f'Band {band+1}')
            
            axes[i].set_title(f'{neurogram_type}')
            axes[i].set_xlabel('Normalized Time')
            axes[i].set_ylabel('Activation')
            axes[i].legend()
        
        plt.tight_layout()
        plt.show()

def check_missingness(df, name):
    missing = df.isnull().sum()
    print(f"Missingness in {name}:")
    print(missing[missing > 0])  # Only show columns with missing values
    print(f"Total rows in {name}: {len(df)}")
    print("\n")

def read_neurograms_from_directory(base_path):
    """
    Read neurograms from a directory structure with nested DataFrame in pickle files
    
    Parameters:
    base_path (str): Path to the base directory containing DR1-DR7 folders
    
    Returns:
    DataFrame with neurograms and metadata
    """
    all_neurograms = []
    
    # Iterate through DR directories
    for dr_folder in sorted(os.listdir(base_path)):
        # Skip system files
        if dr_folder.startswith('.'):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        # Check if it's a directory
        if os.path.isdir(dr_path):
            # Iterate through speaker directories
            for speaker_folder in sorted(os.listdir(dr_path)):
                # Skip system files
                if speaker_folder.startswith('.'):
                    continue
                
                speaker_path = os.path.join(dr_path, speaker_folder)
                
                # Check if it's a directory
                if os.path.isdir(speaker_path):
                    # Iterate through pickle files in the speaker directory
                    for pkl_file in sorted(os.listdir(speaker_path)):
                        if pkl_file.endswith('.pkl'):
                            file_path = os.path.join(speaker_path, pkl_file)
                            
                            try:
                                # Read the pickle file
                                with open(file_path, 'rb') as f:
                                    neurogram_df = pickle.load(f)
                                
                                # Convert neurogram column from string/list to numpy array
                                neurogram_df['Original'] = neurogram_df['Original'].apply(
                                    lambda x: np.array(x) if isinstance(x, list) else x
                                )
                                
                                # Add DR information
                                neurogram_df['DR'] = dr_folder
                                
                                # Append to list of neurograms
                                all_neurograms.append(neurogram_df)
                            
                            except Exception as e:
                                print(f"Error reading {file_path}: {e}")
    
    # Concatenate all neurograms into a single DataFrame
    if all_neurograms:
        df_neurograms = pd.concat(all_neurograms, ignore_index=True)
        return df_neurograms
    else:
        return pd.DataFrame()
    


def read_formants_from_directory(base_path):
    all_formants = []
    
    # Iterate through DR directories
    for dr_folder in sorted(os.listdir(base_path)):
        # Skip system files
        if dr_folder.startswith('.'):
            continue
        
        dr_path = os.path.join(base_path, dr_folder)
        
        # Check if it's a directory
        if os.path.isdir(dr_path):
            # Iterate through speaker directories
            for speaker_folder in sorted(os.listdir(dr_path)):
                # Skip system files
                if speaker_folder.startswith('.'):
                    continue
                
                speaker_path = os.path.join(dr_path, speaker_folder)
                
                # Check if it's a directory
                if os.path.isdir(speaker_path):
                    # Find .pred files in the speaker directory
                    pred_files = [f for f in os.listdir(speaker_path) if f.endswith('.pred')]
                    
                    for pred_file in pred_files:
                        file_path = os.path.join(speaker_path, pred_file)
                        
                        try:
                            # Read the .pred file
                            formant_df = pd.read_csv(file_path, sep='\t', 
                                                     names=['time', 'f1', 'f2', 'f3'])
                            
                            # Extract phoneme correctly
                            # Assumes format like 'SA1_ah_12640_14714.pred'
                            parts = pred_file.split('_')
                            phoneme = parts[1]  # 'ah' in this example
                            
                            # Create columns EXACTLY like neurograms
                            formant_df['speaker'] = speaker_folder
                            formant_df['phoneme'] = phoneme
                            formant_df['speaker_phoneme'] = f"{speaker_folder}_{phoneme}"
                            
                            # Add Category using the mapping
                            formant_df['Category'] = phoneme_category_map.get(phoneme, 'Unknown')
                            
                            # Append to list of formants
                            all_formants.append(formant_df)
                        
                        except Exception as e:
                            print(f"Error reading {file_path}: {e}")
    
    # Concatenate all formants into a single DataFrame
    if all_formants:
        df_formants = pd.concat(all_formants, ignore_index=True)
        return df_formants
    else:
        return pd.DataFrame()

# %%
############################################ 
# Mapping dictionary for phoneme categories#
############################################
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

speaker_gender = {
    # Dialect 1
    'DAB0': 'Male', 'WBT0': 'Male', 'ELC0': 'Female',
    
    # Dialect 2
    'TAS1': 'Male', 'WEW0': 'Male', 'PAS0': 'Female',
    
    # Dialect 3
    'JMP0': 'Male', 'LNT0': 'Male', 'PKT0': 'Female',
    
    # Dialect 4
    'LLL0': 'Male', 'TLS0': 'Male', 'JLM0': 'Female',
    
    # Dialect 5
    'BPM0': 'Male', 'KLT0': 'Male', 'NLP0': 'Female',
    
    # Dialect 6
    'CMJ0': 'Male', 'JDH0': 'Male', 'MGD0': 'Female',
    
    # Dialect 7
    'GRT0': 'Male', 'NJM0': 'Male', 'DHC0': 'Female',
    
    # Dialect 8
    'JLN0': 'Male', 'PAM0': 'Male', 'MLD0': 'Female'
}


# %%
##############
#READING DATA# NEUROGRAMs
##############
# Path to your base directory
base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TEST/'

# Read neurograms
df_neurograms = read_neurograms_from_directory(base_path)

# Print basic information
print("Total neurograms read:", len(df_neurograms))
print("\nDistribution of phonemes:")
print(df_neurograms['Phoneme'].value_counts())
print("\nDistribution of categories:")
print(df_neurograms['Category'].value_counts())
print("\nUnique speakers:")
print(df_neurograms['Speaker'].unique())
print("\nUnique DR folders:")
print(df_neurograms['DR'].unique())

# Optional: Verify neurogram data
print("\nSample neurogram shape:")
print(df_neurograms['Original'].iloc[0].shape)


# %%
##############
#READING DATA# FORMANTs
##############

# Path to formants directory
formants_base_path = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Formants/Phonemes/TEST/'

# Read formants
df_formants = read_formants_from_directory(formants_base_path)

# Print basic information
print("Total formant rows:", len(df_formants))
print("\nDistribution of phonemes:")
print(df_formants['phoneme'].value_counts())
print("\nUnique speakers:")
print(df_formants['speaker'].unique())

# Optional: Check column names and first few rows
print("\nFormant DataFrame columns:")
print(df_formants.columns)
print("\nFirst few rows:")
print(df_formants.head())

# Optional: Basic statistics of formants
print("\nFormant statistics:")
print(df_formants[['f1', 'f2', 'f3']].describe())

# Verify categories
print("\nDistribution of Categories:")
print(df_formants['Category'].value_counts())

# %%

#############
#Some Plots #
#############

# Call to plot activation profiles for each phoneme category
plot_activation_profiles_comparison(df_neurograms)


# %%

###################
#Check missingness#
###################

check_missingness(df_neurograms, "df_neurograms_ANSD")
check_missingness(df_formants, "df_formants")



# %%
######################################
#Check matching speakers and phonemes#
######################################
# Create sets of (speaker, phoneme) tuples for both DataFrames
neurograms_set = set(zip(df_neurograms['Speaker'], df_neurograms['Phoneme']))
formants_set = set(zip(df_formants['speaker'], df_formants['phoneme']))

# Find missing combinations
missing_in_neurograms = formants_set - neurograms_set
missing_in_formants = neurograms_set - formants_set

print("Combinations (speaker, phoneme) missing in neurograms:")
for item in missing_in_neurograms:
    print(item)

print("\nCombinations (speaker, phoneme) missing in formants:")
for item in missing_in_formants:
    print(f"\nTotal combinations in neurograms: {len(neurograms_set)}")
    print(f"Total combinations in formants: {len(formants_set)}")
    print(f"Combinations present in both: {len(neurograms_set.intersection(formants_set))}")# %%



# %%

#################################
#Check Combination between the 2#
#################################

# Create a unique identifier for each speaker-phoneme combination
df_neurograms['speaker_phoneme'] = df_neurograms['Speaker'] + '_' + df_neurograms['Phoneme']
df_formants['speaker_phoneme'] = df_formants['speaker'] + '_' + df_formants['phoneme']

# Find the combinations in df_neurograms_ANSD that are not in df_formants
missing_in_formants = df_neurograms[~df_neurograms['speaker_phoneme'].isin(df_formants['speaker_phoneme'])]

print("Combinations in df_neurograms_ANSD that are missing in df_formants:")
print(missing_in_formants[['Speaker', 'Phoneme']])

# %%
#######################
# Merge the dataframes#
#######################

def merge_dataframes_with_full_formants(df_neurograms, df_formants):
    # Group formants by speaker and phoneme
    grouped_formants = df_formants.groupby(['speaker', 'phoneme']).agg({
        'f1': list,
        'f2': list,
        'f3': list,
        'time': list,
        'Category': 'first'  # Take first category if multiple exist
    }).reset_index()
    
    # Rename columns to match neurograms DataFrame
    grouped_formants.columns = ['speaker', 'phoneme', 'f1', 'f2', 'f3', 'time', 'Category']
    
    # Merge neurograms with grouped formants
    merged_df = pd.merge(
        df_neurograms, 
        grouped_formants, 
        left_on=['Speaker', 'Phoneme'], 
        right_on=['speaker', 'phoneme'], 
        how='outer', 
        indicator=True
    )
    
    return merged_df

# Perform the merge
merged_df = merge_dataframes_with_full_formants(df_neurograms, df_formants)

# Optional: Rename or restructure columns as needed
merged_df = merged_df.rename(columns={
    'speaker': 'speaker_formants',
    'phoneme': 'phoneme_formants'
})

# Verify the structure
print(merged_df.head())

# %%
#################
# Further checks#
#################

# Remove the temporary columns and the merge indicator
merged_df = merged_df.drop(columns=['_merge', 'Category_y'])

# Rename columns to avoid duplicates and ensure consistency
merged_df = merged_df.rename(columns={
    'Speaker': 'speaker_neurograms',
    'Phoneme': 'phoneme_neurograms',
    'Category_x': 'Category'
})

print("\nShape of merged dataframe:", merged_df.shape)

# Print the first few rows to verify the structure
print(merged_df.head())

# Check for any remaining duplicate columns
duplicate_columns = merged_df.columns[merged_df.columns.duplicated()].tolist()
if duplicate_columns:
    print("\nWarning: The following columns are duplicated:", duplicate_columns)
else:
    print("\nNo duplicate columns found.")

# Print summary of the merge
print("\nSummary of the merge:")
print(f"Total rows: {len(merged_df)}")
print(f"Rows with data from both sources: {len(merged_df.dropna(subset=['speaker_neurograms', 'speaker_formants']))}")
print(f"Rows only in neurograms: {len(merged_df[merged_df['speaker_formants'].isna()])}")
print(f"Rows only in formants: {len(merged_df[merged_df['speaker_neurograms'].isna()])}")



# %%

###############################################
# FINAL DFs with BOTH Neurograms and Formants #
###############################################

# Identify the rows that are only in neurograms
rows_only_in_neurograms = merged_df[merged_df['speaker_formants'].isna()]

# Print the missing phonemes
print("Phonemes missing from formants data (due to short signal length):")
for _, row in rows_only_in_neurograms.iterrows():
    print(f"Speaker: {row['speaker_neurograms']}, Phoneme: {row['phoneme_neurograms']}")

# Remove these rows
merged_df_clean = merged_df.dropna(subset=['speaker_formants'])

print("\nShape of cleaned merged dataframe:", merged_df_clean.shape)

# Verify the removal
print("\nSummary of the cleaned merged dataframe:")
print(f"Total rows: {len(merged_df_clean)}")
print(f"Rows with data from both sources: {len(merged_df_clean.dropna(subset=['speaker_neurograms', 'speaker_formants']))}")
print(f"Rows only in neurograms: {len(merged_df_clean[merged_df_clean['speaker_formants'].isna()])}")
print(f"Rows only in formants: {len(merged_df_clean[merged_df_clean['speaker_neurograms'].isna()])}")

# Optional: Reset the index of the cleaned dataframe
merged_df_clean = merged_df_clean.reset_index(drop=True)

# Print the first few rows of the cleaned dataframe
print("\nFirst few rows of the cleaned merged dataframe:")
print(merged_df_clean.head())


# %%

# Create a clean merged DataFrame
merged_df_clean = merged_df_clean.rename(columns={
    'speaker_neurograms': 'Speaker',
    'phoneme_neurograms': 'Phoneme',
    'Category_x': 'Category'
})

# Drop unnecessary columns
columns_to_keep = ['Speaker', 'Phoneme', 'Category', 'Original', 'Temporal_Jitter', 
                   'Selective_Loss', 'Truncation', 'time', 'f1', 'f2', 'f3']

merged_df_clean = merged_df_clean[columns_to_keep]

# Optional: Add speaker_phoneme column
merged_df_clean['speaker_phoneme'] = merged_df_clean['Speaker'] + '_' + merged_df_clean['Phoneme']

# Print columns to verify
print(merged_df_clean.columns)


# %%

def compute_mean_formant(formant_series):
    def safe_mean(x):
        try:
            # If it's already a list, compute mean directly
            if isinstance(x, list):
                return round(np.mean(x), 0)
            
            # If it's a string representation of a list, evaluate and compute mean
            if isinstance(x, str):
                x = ast.literal_eval(x)
                return round(np.mean(x), 0)
            
            return np.nan
        except Exception as e:
            print(f"Error processing {x}: {e}")
            return np.nan

    return formant_series.apply(safe_mean)

# Compute mean formants
merged_df_clean['f1_mean'] = compute_mean_formant(merged_df_clean['f1'])
merged_df_clean['f2_mean'] = compute_mean_formant(merged_df_clean['f2'])
merged_df_clean['f3_mean'] = compute_mean_formant(merged_df_clean['f3'])


# %%

# Function to compute mean of center frequencies across time for each neurogram type
def extract_neurogram_values(row, neurogram_type):
    neurogram = row[neurogram_type]
    return pd.Series({f'CF{i+1}_Mean': np.mean(neurogram[:, i]) for i in range(neurogram.shape[1])})

# Extract neurogram values
neurogram_types = ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']
for ntype in neurogram_types:
    mean_columns = merged_df_clean.apply(
        lambda row: extract_neurogram_values(row, ntype), 
        axis=1
    )
    
    # Add prefix to columns
    mean_columns = mean_columns.add_prefix(f'{ntype}_')
    
    # Concatenate with original DataFrame
    merged_df_clean = pd.concat([merged_df_clean, mean_columns], axis=1)

# Drop original neurogram type columns
columns_to_drop = neurogram_types
merged_df_clean = merged_df_clean.drop(columns=columns_to_drop)


# %%
neurogram_types = ['Original', 'Temporal_Jitter', 'Selective_Loss', 'Truncation']

for ntype in neurogram_types:
    # Create a list of mean values for each neurogram type
    merged_df_clean[f'{ntype}_CF_Means'] = merged_df_clean.apply(
        lambda row: [row[f'{ntype}_CF{i}_Mean'] for i in range(1, 7)], 
        axis=1
    )

# Drop individual CF mean columns
columns_to_drop = [
    f'{ntype}_CF{i}_Mean' for ntype in neurogram_types for i in range(1, 7)
]
merged_df_clean = merged_df_clean.drop(columns=columns_to_drop)


# %%
# Count phonemes per category
phoneme_category_counts = merged_df_clean.groupby('Category')['Phoneme'].nunique()

# Create a bar plot
plt.figure(figsize=(12, 6))
phoneme_category_counts.plot(kind='bar')
plt.title('Number of Unique Phonemes per Category')
plt.xlabel('Category')
plt.ylabel('Number of Unique Phonemes')
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.show()
print("Phoneme counts per category:")
print(phoneme_category_counts)


# %%

# Count samples for each phoneme
phoneme_counts = merged_df_clean['Phoneme'].value_counts()

# Create a bar plot
plt.figure(figsize=(15, 7))
phoneme_counts.plot(kind='bar')
plt.title('Number of Samples per Phoneme')
plt.xlabel('Phoneme')
plt.ylabel('Number of Samples')
plt.xticks(rotation=90)
plt.tight_layout()
plt.show()

# Print the counts
print("Phoneme sample counts:")
print(phoneme_counts)

# %%

# Sample up to 100 samples for each phoneme
merged_df_clean_sampled = merged_df_clean.groupby('Phoneme').apply(
    lambda x: x if len(x) <= 100 else x.sample(n=100, random_state=42)
).reset_index(drop=True)

# Verify the sampling
print("Original dataset size:", len(merged_df_clean))
print("Sampled dataset size:", len(merged_df_clean_sampled))

# %%

# Count of samples per phoneme in the sampled dataset
phoneme_counts = merged_df_clean_sampled['Phoneme'].value_counts()

# Visualization
plt.figure(figsize=(15, 7))
phoneme_counts.plot(kind='bar')
plt.title('Number of Samples per Phoneme (Sampled)')
plt.xlabel('Phoneme')
plt.ylabel('Number of Samples')
plt.xticks(rotation=90)
plt.tight_layout()
plt.show()

# Print the counts
print("\nPhonemesample counts in sampled dataset:")
print(phoneme_counts)

# %%
#############################################################
# RECOMMENDATION FOR USE AND COMPARISON OF DISTANCE MEASURES  #
#############################################################

# FOR OVERALL COMPARISON (comparing entire formant space [F1,F2,F3] with entire CF space [CF1-CF6]):

#1. IMPROVED ACOUSTIC DISTANCE (with mel scale)
#def improved_acoustic_distance(x, y):
    # Convert to mel scale + normalization + handles zeros
#Advantages:
# - Most perceptually relevant (mel scale matches human hearing)
# - Properly normalized (0-1 range)
# - Handles acoustic properties of speech frequencies
# - Accounts for logarithmic nature of frequency perception
# - Handles edge cases (zeros, very small values)

#2. SPACE-WISE GW DISTANCE OVERALL
#def compute_space_gw_distance_overall(df, category, neurogram_type):
    # Compares distributions of all formants vs all CFs within categories
#Advantages:
# - Preserves the structural relationships between all frequencies
# - Considers the full distributional properties within phoneme categories
# - Theoretically sound from Optimal Transport perspective
# - Captures global geometry of the frequency spaces

# FOR INDIVIDUAL COMPARISONS (comparing single formant spaces with single CF spaces):

#1. SPACE-WISE GW DISTANCE INDIVIDUAL
#def compute_space_gw_distance(df, formant_name, cf_num, neurogram_type, category)
#Advantages:
# - Maintains the distributional nature of Optimal Transport
# - Compares distributions rather than single values
# - Preserves the geometry of each frequency space
# - Allows detailed analysis of specific formant-CF relationships
# - Theoretically sound for comparing frequency distributions

#2. IMPROVED ACOUSTIC DISTANCE INDIVIDUAL
#Advantages:
# - Direct perceptual comparison between individual formants and CFs
# - Perceptually relevant through mel scale
# - Simpler to interpret than GW distances
# - Reveals direct relationships between specific formants and CFs
# - Useful for detailed analysis of frequency mappings

#############################################################
# RECOMMENDED ANALYSIS PIPELINE                              #
#############################################################

#1. Overall Analysis:
# a) Improved acoustic distance for perceptual comparison
# b) Space-wise GW for structural/geometric comparison

#2. Individual Analysis:
# a) Space-wise GW for distributional comparison
# b) Improved acoustic for direct frequency mapping

#This combination provides:
# - Both perceptual and geometric perspectives
# - Both global and local insights
# - Both direct and distributional comparisons
# - Theoretically sound approach from both acoustic and OT perspectives
# - Comprehensive understanding of formant-CF relationships

# %%

###############################################################
# PART 1: FUNCTION DEFINITIONS FOR ACOUSTIC OPTIMAL TRANSPORT #
###############################################################

# Improved Acoustic Distance (base function for both overall and individual)
def improved_acoustic_distance(x, y):
    epsilon = 1e-10
    
    def freq_to_mel(f):
        return 2595 * np.log10(1 + f/700)
    
    # Ensure x and y are numpy arrays
    x = np.atleast_1d(x) + epsilon
    y = np.atleast_1d(y) + epsilon
    
    # Compute mel values
    x_mel = freq_to_mel(x)
    y_mel = freq_to_mel(y)
    
    # Compute distances
    distances = np.abs(x_mel - y_mel) / np.maximum(x_mel, y_mel)
    
    # Return mean distance if multiple values
    return np.mean(distances)


# %%
##########################################
# PART 2: COMPUTE ALL ACOUSTIC DISTANCES #
##########################################

# Get unique categories
# Get unique categories
categories = merged_df_clean_sampled['Category'].unique()

# Store final results
final_acoustic_individual_df = []

# Process each category separately
for category in categories:
    # Filter dataframe by category
    category_df = merged_df_clean_sampled[merged_df_clean_sampled['Category'] == category]
    
    def pad_to_max_length(lists):
        max_len = max(len(lst) for lst in lists)
        return np.array([lst + [0] * (max_len - len(lst)) for lst in lists])

    f1_matrix = pad_to_max_length(category_df['f1'].tolist())
    f2_matrix = pad_to_max_length(category_df['f2'].tolist())
    f3_matrix = pad_to_max_length(category_df['f3'].tolist())

    # Formants to analyze
    formants = [
        ('F1', f1_matrix), 
        ('F2', f2_matrix), 
        ('F3', f3_matrix)
    ]

    # Neurogram types and their corresponding mean columns
    neurogram_types = [
        ('Original', 'Original_CF_Means'),
        ('Temporal_Jitter', 'Temporal_Jitter_CF_Means'),
        ('Selective_Loss', 'Selective_Loss_CF_Means'),
        ('Truncation', 'Truncation_CF_Means')
    ]

    # Store results for this category
    acoustic_formant_results = []

    # Compute distances
    for formant_name, formant_matrix in formants:
        # Compute distance matrix for formant
        formant_dist_matrix = cdist(formant_matrix, formant_matrix, metric=improved_acoustic_distance)
        formant_dist_matrix = formant_dist_matrix / np.max(formant_dist_matrix) if np.max(formant_dist_matrix) > 0 else formant_dist_matrix
        
        # Prepare uniform weights for formants
        p = ot.unif(len(formant_matrix))

        for ntype, cf_column in neurogram_types:
            try:
                # Extract center frequency means for this category
                def safe_convert(x):
                    if isinstance(x, list):
                        return x
                    elif isinstance(x, str):
                        try:
                            return eval(x)
                        except:
                            return []
                    return []

                cf_means = np.array([safe_convert(x) for x in category_df[cf_column]])
                
                # Compute individual Gromov-Wasserstein distances
                individual_distances = []
                for cf_mean in cf_means:
                    # Compute distance matrix for this CF mean
                    cf_dist_matrix = cdist([cf_mean], [cf_mean], metric=improved_acoustic_distance)
                    cf_dist_matrix = cf_dist_matrix / np.max(cf_dist_matrix) if np.max(cf_dist_matrix) > 0 else cf_dist_matrix
                    
                    # Prepare uniform weights for CF means
                    q = ot.unif(1)
                    
                    # Compute Gromov-Wasserstein distance
                    acoustic_dist = ot.gromov.gromov_wasserstein2(formant_dist_matrix, 
                                                                  cf_dist_matrix,
                                                                  p, q, 
                                                                  loss_fun='square_loss')
                    
                    individual_distances.append(round(acoustic_dist, 2))
                
                # Store results for each CF mean
                acoustic_formant_results.append({
                    'Formant': formant_name,
                    'Neurogram_Type': ntype,
                    'CF1_Distance': individual_distances[0],
                    'CF2_Distance': individual_distances[1],
                    'CF3_Distance': individual_distances[2],
                    'CF4_Distance': individual_distances[3],
                    'CF5_Distance': individual_distances[4],
                    'CF6_Distance': individual_distances[5],
                    'Category': category
                })
            except Exception as e:
                print(f"Error processing {formant_name}, {ntype}, {category}: {str(e)}")

    # Append results for this category
    final_acoustic_individual_df.extend(acoustic_formant_results)

# Convert to DataFrame
acoustic_individual_df = pd.DataFrame(final_acoustic_individual_df)

# %%

acoustic_individual_df.to_pickle('acoustic_individual_distances.pkl')

#with open('acoustic_individual_distances.pkl', 'wb') as f:
#    pickle.dump(acoustic_individual_df, f, protocol=pickle.HIGHEST_PROTOCOL)



# %%
# Create a figure with three subplots
fig, axes = plt.subplots(1, 3, figsize=(20, 6))
fig.suptitle('Acoustic Distances across Categories and CF Means', fontsize=16)

# Formants to plot
formants = ['F1', 'F2', 'F3']

# Create a heatmap for each formant
for i, formant in enumerate(formants):
    # Filter data for the current formant
    formant_data = acoustic_individual_df[acoustic_individual_df['Formant'] == formant]
    
    # Prepare data for heatmap
    heatmap_data = formant_data.melt(
        id_vars=['Category', 'Neurogram_Type'], 
        value_vars=['CF1_Distance', 'CF2_Distance', 'CF3_Distance', 
                    'CF4_Distance', 'CF5_Distance', 'CF6_Distance'],
        var_name='CF_Mean', 
        value_name='Distance'
    )
    
    # Modify CF_Mean to remove 'Distance'
    heatmap_data['CF_Mean'] = heatmap_data['CF_Mean'].str.replace('_Distance', '')
    
    # Combine Neurogram_Type and CF_Mean
    heatmap_data['Neurogram_CF'] = heatmap_data['Neurogram_Type'] + ' - ' + heatmap_data['CF_Mean']
    
    # Pivot the data
    pivot_data = heatmap_data.pivot_table(
        index='Category', 
        columns='Neurogram_CF', 
        values='Distance', 
        aggfunc='mean'
    )
    
    # Create heatmap
    sns.heatmap(pivot_data, 
                ax=axes[i], 
                annot=True, 
                cmap='YlGnBu', 
                fmt='.2f', 
                cbar=True)
    
    axes[i].set_title(f'{formant} Acoustic Distances')
    axes[i].set_xlabel('Neurogram Type - CF Mean')
    axes[i].set_ylabel('Category')
    
    # Rotate x-axis labels for readability
    plt.setp(axes[i].get_xticklabels(), rotation=45, ha='right')

plt.tight_layout()
plt.show()




# %%
