#!/usr/bin/env python3
import os
import shutil
import re

def reorganize_speakers_into_dialect_regions(source_dir, reference_dir):
    """
    Reorganize speaker folders from source_dir into dialect regions based on reference_dir structure.
    
    Args:
        source_dir: Directory with speaker folders directly (e.g., SELECT_Neurograms_WithNoise/TEST)
        reference_dir: Directory with DR structure to emulate (e.g., SELECT_Neurograms/TEST)
    """
    print(f"Reorganizing speakers from {source_dir} based on structure in {reference_dir}")
    
    # Create a mapping of speaker to dialect region by scanning the reference directory
    speaker_to_dr = {}
    
    # First, scan the reference directory to identify which DR each speaker belongs to
    for dr_folder in os.listdir(reference_dir):
        if dr_folder.startswith('DR'):
            dr_path = os.path.join(reference_dir, dr_folder)
            if os.path.isdir(dr_path):
                for speaker in os.listdir(dr_path):
                    if os.path.isdir(os.path.join(dr_path, speaker)):
                        speaker_to_dr[speaker] = dr_folder
    
    print(f"Found {len(speaker_to_dr)} speakers in reference directory")
    
    # Now reorganize the source directory
    for item in os.listdir(source_dir):
        item_path = os.path.join(source_dir, item)
        
        # Only process directories (speakers)
        if os.path.isdir(item_path):
            speaker = item
            
            if speaker in speaker_to_dr:
                dr = speaker_to_dr[speaker]
                dr_path = os.path.join(source_dir, dr)
                
                # Create the DR directory if it doesn't exist
                if not os.path.exists(dr_path):
                    os.makedirs(dr_path)
                    print(f"Created dialect region directory: {dr}")
                
                # Get destination path
                dest_path = os.path.join(dr_path, speaker)
                
                # Move the speaker folder
                print(f"Moving {speaker} to {dr}")
                shutil.move(item_path, dest_path)
            else:
                print(f"Warning: Speaker {speaker} not found in reference structure")
    
    print("Reorganization complete")

if __name__ == "__main__":
    # For TEST directories
    source_test = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_WithNoise/TEST"
    reference_test = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/TEST"
    reorganize_speakers_into_dialect_regions(source_test, reference_test)
    
    # For TRAIN directories
    source_train = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_WithNoise/TRAIN"
    reference_train = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/TRAIN"
    reorganize_speakers_into_dialect_regions(source_train, reference_train)
    
    # For ANSD TEST directory
    source_ansd_test = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/TEST"
    reorganize_speakers_into_dialect_regions(source_ansd_test, reference_test)
    
    # For ANSD TRAIN directory
    source_ansd_train = "/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms_ANSD/TRAIN"
    reorganize_speakers_into_dialect_regions(source_ansd_train, reference_train)
    