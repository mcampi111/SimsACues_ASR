# %%
import os

# %%

# Base directories
test_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TEST'
train_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/Phonemes/TRAIN'

# %%

def delete_pkl_files(base_dir):
    pkl_count = 0
    # Walk through all directories
    for dr_dir in os.listdir(base_dir):
        if not dr_dir.startswith('DR'):
            continue
            
        dr_path = os.path.join(base_dir, dr_dir)
        
        for speaker_dir in os.listdir(dr_path):
            if speaker_dir.startswith('.'):
                continue
                
            speaker_path = os.path.join(dr_path, speaker_dir)
            
            # Find and delete .pkl files
            for file in os.listdir(speaker_path):
                if file.endswith('.pkl'):
                    file_path = os.path.join(speaker_path, file)
                    os.remove(file_path)
                    pkl_count += 1
                    print(f"Deleted: {file_path}")
    
    return pkl_count

# %%

# Delete .pkl files in TEST directory
print("\nProcessing TEST directory...")
test_count = delete_pkl_files(test_dir)
print(f"Deleted {test_count} .pkl files from TEST")

# Delete .pkl files in TRAIN directory
print("\nProcessing TRAIN directory...")
train_count = delete_pkl_files(train_dir)
print(f"Deleted {train_count} .pkl files from TRAIN")

print(f"\nTotal .pkl files deleted: {test_count + train_count}")
# %%
