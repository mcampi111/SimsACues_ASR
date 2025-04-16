#!/usr/bin/env python3
import os
import numpy as np
import tensorflow as tf
from srA1predict import combineModelCausalNN
from srA2predict import predictPhonemeProbabilitiesNonCausalNN
from sklearn.metrics import confusion_matrix
import scipy.io
import time
import gc

# Configure memory growth for GPUs
physical_devices = tf.config.list_physical_devices('GPU')
for device in physical_devices:
    try:
        tf.config.experimental.set_memory_growth(device, True)
    except:
        pass

# Define paths
DATA_DIR = "TIMIT_Neuro_ANSD"  # Using ANSD data
RESULTS_DIR = "/pasteur/helix/scratch/mcampi/results/healthy/noise/test/ansd"  # Store results in healthy/noise but with ansd subfolder
MODEL_DIR = "results/healthy/noise"  # Using healthy noise model
PHONEMES_DIR = "Phonemes39_posindex_labels/test"

# Create results directory if it doesn't exist
os.makedirs(RESULTS_DIR, exist_ok=True)

# List of test files to process with their corresponding phoneme and position index files
test_files = [
    # ANSD Noisy test data
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_default_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_default.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_default.npy')},
     
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_snr_0_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_0.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_0.npy')},
     
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_snr_5_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_5.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_5.npy')},
     
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_snr_10_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_10.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_10.npy')},
     
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_snr_15_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_15.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_15.npy')},
     
    {'neurogram': 'TIMIT_neurogram_ansd_test_with_noise_snr_neg5_scaled.npy', 
     'phoneme_file': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39consecutive_true_test_ansd_neg5.npy'),
     'position_index': os.path.join(PHONEMES_DIR, 'ansd_noise', 'Phonemes39_position_index_true_test_ansd_neg5.npy')}
]

# Define model paths
causal_model = f"{MODEL_DIR}/srA1_TIMIT_full_multi_c_0"
noncausal_model = f"{MODEL_DIR}/srA2_TIMIT_full_multi_b_9"

# Log file for status updates
log_file_path = os.path.join(RESULTS_DIR, "testing_log.txt")

def log_message(message):
    """Write a message to the log file and print it to console"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"[{timestamp}] {message}"
    print(log_message)
    with open(log_file_path, "a") as log_file:
        log_file.write(log_message + "\n")

def test_condition(test_info):
    """Test the model on a specific test file using position indices"""
    try:
        # Extract neurogram file, phoneme file, and position index file
        test_file = test_info['neurogram']
        phoneme_file = test_info['phoneme_file']
        position_index_file = test_info['position_index']
        
        # Create a readable test condition name
        test_name = os.path.splitext(test_file)[0]
        
        # Extract the noise condition with improved logic
        parts = test_name.split("_")
        for i, part in enumerate(parts):
            if part == "noise":
                if i+1 < len(parts) and parts[i+1] == "snr" and i+2 < len(parts):
                    # For SNR conditions, include both "snr" and the value
                    condition_name = f"snr_{parts[i+2]}"
                elif i+1 < len(parts):
                    condition_name = parts[i+1]
                else:
                    condition_name = "default"
                break
        else:
            condition_name = "unknown"
        
        log_message(f"Starting testing on {test_file} (condition: {condition_name})")
        log_message(f"Using phoneme file: {phoneme_file}")
        log_message(f"Using position index file: {position_index_file}")
        
        # Paths for this test condition
        test_data_path = os.path.join(DATA_DIR, test_file)
        test_results_dir = os.path.join(RESULTS_DIR, condition_name)
        os.makedirs(test_results_dir, exist_ok=True)
        
        # Step 1: Run the causal network
        log_message("Running causal network...")
        output_name = os.path.join(test_results_dir, "srA1_causal_output")
        
        combineModelCausalNN(
            model_name_1=causal_model,
            model_name_2=causal_model,
            model_name_out=output_name,
            filename_X1=test_data_path,
            filename_X2=test_data_path,
            filename_Y=phoneme_file,
            output_dir=test_results_dir
        )
        
        # Clear memory after causal network
        gc.collect()
        tf.keras.backend.clear_session()
        
        # Step 2: Run the non-causal network with the output from step 1
        log_message("Running non-causal network...")
        logp_file = f"{output_name}_logp_combined_all.npy"
        
        predictPhonemeProbabilitiesNonCausalNN(
            filename_X=logp_file,
            filename_Y=phoneme_file,
            model_name=noncausal_model,
            data_split_factor=0,
            output_dir=test_results_dir
        )
        
        # Step 3: Generate confusion matrix
        log_message("Generating confusion matrix...")
        true_file = os.path.join(test_results_dir, f"Phonemes39true_{os.path.basename(noncausal_model)}.npy")
        pred_file = os.path.join(test_results_dir, f"Phonemes39pred_{os.path.basename(noncausal_model)}.npy")
        
        # Load true and predicted phonemes
        true_phonemes = np.load(true_file)
        pred_phonemes = np.load(pred_file)
        
        # Generate confusion matrix
        cf_matrix = confusion_matrix(pred_phonemes, true_phonemes)
        
        # Save confusion matrix with appropriate name
        cf_matrix_file = os.path.join(test_results_dir, f"cfMatrix_{condition_name}.mat")
        scipy.io.savemat(cf_matrix_file, {'cf_matrix': cf_matrix})
        
        # Calculate and save accuracy
        accuracy = np.sum(pred_phonemes == true_phonemes) / len(true_phonemes)
        with open(os.path.join(test_results_dir, "accuracy.txt"), "w") as f:
            f.write(f"Accuracy: {accuracy:.4f}\n")
        
        log_message(f"Testing completed for {condition_name}. Accuracy: {accuracy:.4f}")
        return True, accuracy, condition_name
        
    except Exception as e:
        log_message(f"Error testing {test_file}: {str(e)}")
        return False, 0.0, "unknown"

def main():
    """Main function to test all conditions"""
    log_message("Starting testing for healthy noise model on ANSD noise data")
    log_message(f"Model: Causal={causal_model}, Non-causal={noncausal_model}")
    log_message(f"Results will be stored in: {RESULTS_DIR}")
    
    # Test each condition
    results = {}
    accuracies = {}
    
    for test_info in test_files:
        success, accuracy, condition_name = test_condition(test_info)
        results[condition_name] = "Success" if success else "Failed"
        accuracies[condition_name] = accuracy
    
    # Generate summary
    log_message("Testing completed. Summary:")
    
    # Sort conditions logically: by SNR value
    def sort_key(condition):
        if condition == "default":
            return -99   # Put default first
        if condition.startswith("snr_"):
            try:
                # Extract the number after snr_
                snr_value = condition.split("_")[1]
                if snr_value.startswith("neg"):
                    # Handle negative values like "neg5"
                    return -1 * int(snr_value[3:])
                else:
                    return int(snr_value)
            except:
                return 0
        return 0
    
    sorted_conditions = sorted(results.keys(), key=sort_key, reverse=True)
    
    # Save summary to file
    with open(os.path.join(RESULTS_DIR, "summary.txt"), "w") as f:
        f.write("HEALTHY NOISE MODEL ON ANSD NOISE DATA TESTING SUMMARY\n")
        f.write("==================================================\n\n")
        f.write("Condition | Status | Accuracy\n")
        f.write("---------|--------|----------\n")
        
        for condition in sorted_conditions:
            f.write(f"{condition:10} | {results[condition]:7} | {accuracies[condition]:.4f}\n")
            log_message(f"{condition}: {results[condition]} (Accuracy: {accuracies[condition]:.4f})")

if __name__ == "__main__":
    main()
