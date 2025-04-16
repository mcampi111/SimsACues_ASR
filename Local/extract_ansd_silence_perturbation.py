# %%   
import os
import numpy as np
import json

# %%   
def recover_perturbation_types(input_path):
    """
    Recover perturbation types by walking directory structure
    and using the same random seed, without sorting
    """
    # Set the same random seed as in the original code
    np.random.seed(42)
    
    results = {}
    
    # Walk through the directory structure WITHOUT sorting
    for dr_dir in os.listdir(input_path):
        if not dr_dir.startswith('DR'):
            continue
            
        dr_path = os.path.join(input_path, dr_dir)
        print(f"Processing {dr_dir}...")
        
        for speaker_dir in os.listdir(dr_path):
            if speaker_dir.startswith('.'):
                continue
                
            speaker_path = os.path.join(dr_path, speaker_dir)
            print(f"Processing speaker {speaker_dir}...")
            
            # Process each .mat file WITHOUT sorting
            for filename in os.listdir(speaker_path):
                if not filename.endswith('_neurogram.mat'):
                    continue
                
                # This makes exactly the same choice as the original code would have
                perturbation_type = np.random.choice(['scattered_jitter', 'jitter', 'loss', 'truncation'])
                
                # Store the perturbation type
                ansd_filename = filename[:-4] + '_ansd.mat'
                results[ansd_filename] = perturbation_type
    
    return results

# %%   
# Define paths based on your directory structure
base_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all'
input_base = os.path.join(base_dir, 'SELECT_Neurograms')
train_path = os.path.join(input_base, 'TRAIN')
test_path = os.path.join(input_base, 'TEST')

# Recover perturbation types
print("\nRecovering TRAIN perturbation types...")
train_pert_types = recover_perturbation_types(train_path)

print("\nRecovering TEST perturbation types...")
test_pert_types = recover_perturbation_types(test_path)

# Save results to a file
combined_types = {**train_pert_types, **test_pert_types}
output_file = os.path.join(base_dir, 'perturbation_types.json')
with open(output_file, 'w') as f:
    json.dump(combined_types, f, indent=2)

# Count the number of entries
train_count = len(train_pert_types)
test_count = len(test_pert_types)
total_count = len(combined_types)

print(f"\nStatistics:")
print(f"Number of TRAIN files: {train_count}")
print(f"Number of TEST files: {test_count}")
print(f"Total files: {total_count}")

# Count actual ANSD files in directories
def count_ansd_files(directory):
    count = 0
    for root, _, files in os.walk(directory):
        count += sum(1 for f in files if f.endswith('_ansd.mat'))
    return count

ansd_dir = os.path.join(base_dir, 'SELECT_Neurograms_ANSD')
train_ansd_dir = os.path.join(ansd_dir, 'TRAIN')
test_ansd_dir = os.path.join(ansd_dir, 'TEST')

actual_train_count = count_ansd_files(train_ansd_dir)
actual_test_count = count_ansd_files(test_ansd_dir)
actual_total = actual_train_count + actual_test_count

print(f"\nActual ANSD file counts:")
print(f"TRAIN: {actual_train_count}")
print(f"TEST: {actual_test_count}")
print(f"Total: {actual_total}")
print(f"Counts match: {total_count == actual_total}")

# Detailed analysis of file counts
def detailed_file_analysis(input_dir, ansd_dir):
    """Analyzes differences between source and ANSD files"""
    # Count original neurogram files
    orig_files = set()
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.endswith('_neurogram.mat'):
                orig_files.add(f[:-4] + '_ansd.mat')  # What the ANSD filename should be
    
    # Count actual ANSD files
    ansd_files = set()
    for root, _, files in os.walk(ansd_dir):
        for f in files:
            if f.endswith('_ansd.mat'):
                ansd_files.add(f)
    
    # Compare
    missing_from_ansd = orig_files - ansd_files
    extra_in_ansd = ansd_files - orig_files
    
    print(f"Total original files that should have ANSD versions: {len(orig_files)}")
    print(f"Total actual ANSD files: {len(ansd_files)}")
    print(f"Missing ANSD files (expected but not found): {len(missing_from_ansd)}")
    print(f"Extra ANSD files (found but not expected): {len(extra_in_ansd)}")
    
    return orig_files, ansd_files

# %%   
# Run analysis
print("\nAnalyzing TRAIN files:")
train_orig, train_ansd = detailed_file_analysis(train_path, train_ansd_dir)

print("\nAnalyzing TEST files:")
test_orig, test_ansd = detailed_file_analysis(test_path, test_ansd_dir)

# %%    