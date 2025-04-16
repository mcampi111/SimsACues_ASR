# %%
import numpy as np
import os
import wave
import soundfile as sf
import logging
from collections import defaultdict


# %%
##############
#READING DATA#
##############
# Define the base directories
base_dir = '/Users/mcampi/Desktop/To_Marta/CI-ASR/TIMIT/timit/SELECT/timit/'
input_dirs = [os.path.join(base_dir, 'TRAIN'), os.path.join(base_dir, 'TEST')]
output_dirs = [os.path.join(base_dir, 'TRAIN_Phonemes'), os.path.join(base_dir, 'TEST_Phonemes')]

# %%
###########
#FUNCTIONS#
###########

# Function to process a single WAV file
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def process_wav_file(wav_filepath, phn_filepath, output_dir):
    try:
        logging.info(f"Processing file: {wav_filepath}")
        
        # Open and read WAV file metadata
        with wave.open(wav_filepath, 'rb') as wav_file:
            sample_rate = wav_file.getframerate()
            num_channels = wav_file.getnchannels()
            frames = wav_file.readframes(wav_file.getnframes())
            audio_data = np.frombuffer(frames, dtype=np.int16)
            
            if num_channels > 1:
                audio_data = np.reshape(audio_data, (-1, num_channels))
        
        # Read the .PHN file for phoneme segmentation
        with open(phn_filepath, 'r') as phn_file:
            for line in phn_file:
                try:
                    start_idx, end_idx, phoneme = line.strip().split()
                    start_idx, end_idx = int(start_idx), int(end_idx)
                    
                    # Segment the audio data
                    phoneme_audio = audio_data[start_idx:end_idx]
                    
                    # Construct output filename with speaker identity as prefix and save
                    relative_path = os.path.relpath(wav_filepath, base_dir)
                    output_subdir = os.path.join(output_dir, os.path.dirname(relative_path))
                    os.makedirs(output_subdir, exist_ok=True)
                    
                    phoneme_filename = f"{output_subdir}/{os.path.basename(wav_filepath).replace('.WAV', '')}_{phoneme}_{start_idx}_{end_idx}.wav"
                    sf.write(phoneme_filename, phoneme_audio, sample_rate)

                    logging.info(f"Saved phoneme '{phoneme}' from {start_idx} to {end_idx} in {phoneme_filename}")
                except Exception as e:
                    logging.error(f"Error processing phoneme in {wav_filepath}: {str(e)}")
    except Exception as e:
        logging.error(f"Error processing file {wav_filepath}: {str(e)}")
# %%
###########
#FUNCTIONS#
###########
def check_processing():
    # Define the directories inside the function
    base_dir = '/Users/mcampi/Desktop/To_Marta/CI-ASR/TIMIT/timit/SELECT/timit/'
    reference_dirs = [os.path.join(base_dir, 'TRAIN'), os.path.join(base_dir, 'TEST')]
    checked_dirs = [os.path.join(base_dir, 'TRAIN_Phonemes'), os.path.join(base_dir, 'TEST_Phonemes')]

    for reference_dir, checked_dir in zip(reference_dirs, checked_dirs):
        logging.info(f"\nChecking directories:")
        logging.info(f"Reference directory: {reference_dir}")
        logging.info(f"Output directory: {checked_dir}")
        
        phoneme_count = defaultdict(lambda: {'expected': 0, 'processed': 0})
        total_wav_files = 0
        
        # First, count expected phonemes from reference directory
        for root, _, files in os.walk(reference_dir):
            wav_files = [f for f in files if f.endswith('.WAV')]
            total_wav_files += len(wav_files)
            
            for wav_file in wav_files:
                phn_file = wav_file.replace('.WAV', '.PHN')
                phn_path = os.path.join(root, phn_file)
                
                if os.path.exists(phn_path):
                    with open(phn_path, 'r') as f:
                        for line in f:
                            _, _, phoneme = line.strip().split()
                            phoneme_count[phoneme]['expected'] += 1
        
        # Then, count processed phonemes in output directory
        for root, _, files in os.walk(checked_dir):
            for file in files:
                if file.endswith('.wav'):
                    # Extract phoneme from filename
                    parts = file.split('_')
                    if len(parts) >= 2:
                        # The phoneme should be the second-to-last element before the timestamps
                        phoneme = parts[-3]  # Assuming format is basename_phoneme_start_end.wav
                        phoneme_count[phoneme]['processed'] += 1
        
        # Print results
        logging.info(f"\nTotal WAV files in reference directory: {total_wav_files}")
        logging.info("\nPhoneme Statistics:")
        
        total_expected = 0
        total_processed = 0
        
        # Sort phonemes by frequency for better readability
        sorted_phonemes = sorted(phoneme_count.items(), 
                               key=lambda x: x[1]['expected'], 
                               reverse=True)
        
        for phoneme, counts in sorted_phonemes:
            expected = counts['expected']
            processed = counts['processed']
            missing = expected - processed
            total_expected += expected
            total_processed += processed
            
            logging.info(f"\nPhoneme: {phoneme}")
            logging.info(f"  Expected: {expected}")
            logging.info(f"  Processed: {processed}")
            logging.info(f"  Missing: {max(0, missing)}")
        
        logging.info(f"\nSummary:")
        logging.info(f"Total expected phonemes: {total_expected}")
        logging.info(f"Total processed phonemes: {total_processed}")
        logging.info(f"Total missing phonemes: {max(0, total_expected - total_processed)}")
        
        if total_expected > 0:
            completion_rate = (total_processed / total_expected) * 100
            logging.info(f"Completion rate: {completion_rate:.2f}%")



# %%
# Process all files in both TRAIN and TEST directories
for input_dir, output_dir in zip(input_dirs, output_dirs):
    for root, dirs, files in os.walk(input_dir):
        for file in files:
            if file.endswith(".WAV"):
                wav_filepath = os.path.join(root, file)
                phn_filepath = wav_filepath.replace(".WAV", ".PHN")
                
                if os.path.exists(phn_filepath):
                    process_wav_file(wav_filepath, phn_filepath, output_dir)
                else:
                    logging.warning(f"PHN file not found for {wav_filepath}")
                    
                    

# %%
#######
#CHECK#
#######

check_processing()
# %%

# %%

# %%


# %%


# %%


# %%