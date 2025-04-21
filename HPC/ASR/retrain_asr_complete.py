import numpy as np
import tensorflow as tf
import gc
import os
import time
from collections import Counter
from srA1 import trainCausalNN
from srA1predict import combineModelCausalNN
from srA2 import trainNonCausalNN
from srA2predict import predictPhonemeProbabilitiesNonCausalNN
from balance_indices import generate_balanced_indices

# Define output directory
OUTPUT_DIR = 'results/healthy/silence'

# Create output directory if it doesn't exist
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Record start time
start_time = time.time()
print(f"Starting retraining at {time.strftime('%a %b %d %H:%M:%S %Z %Y', time.localtime())}")

# Configure memory growth for GPUs
physical_devices = tf.config.list_physical_devices('GPU')
print("Checking for GPU availability...")
if len(physical_devices) > 0:
    print(f"GPUs detected, setting up CUDA environment...")
    for device in physical_devices:
        try:
            tf.config.experimental.set_memory_growth(device, True)
            print(f"Memory growth enabled for {device}")
        except Exception as e:
            print(f"Error setting memory growth: {e}")
else:
    print("No GPUs detected, running in CPU mode")

# Set up multi-GPU strategy
try:
    strategy = tf.distribute.MirroredStrategy()
    print(f"Number of devices: {strategy.num_replicas_in_sync}")
except Exception as e:
    print(f"Error setting up distributed strategy: {e}")
    # Fallback to default strategy
    strategy = tf.distribute.get_strategy()
    print("Using default strategy")

# Updated paths for input files
NEUROGRAM_PATH = 'TIMIT_Neuro/train/TIMIT_neurogram_scaled.npy'
PHONEMES_PATH = 'Phonemes39_posindex_labels/train/healthy_silence/Phonemes39consecutive_true_train_healthy_silence.npy'
POSITIONS_PATH = 'Phonemes39_posindex_labels/train/healthy_silence/Phonemes39_position_index_true_train_healthy_silence.npy'

# Test data loading
print("Loading data...")
try:
    scaled_data = np.load(NEUROGRAM_PATH)
    phonemes = np.load(PHONEMES_PATH)
    positions = np.load(POSITIONS_PATH)

    print("Data shapes:")
    print(f"Scaled data: {scaled_data.shape}")
    print(f"Phonemes: {phonemes.shape}")
    print(f"Positions: {positions.shape}")
except Exception as e:
    print(f"Error loading data: {e}")
    raise

# Paths to the generated index files
balanced_positions_path = f"{OUTPUT_DIR}/balanced_positions.npy"
validation_positions_path = f"{OUTPUT_DIR}/validation_positions.npy"
test_positions_path = f"{OUTPUT_DIR}/test_positions.npy"

# Check if validation positions file already exists, if not create and save it
if not os.path.exists(validation_positions_path):
    print("WARNING: Validation positions file does not exist.")
    print("Creating and saving validation positions for future use...")
    
    # Generate random validation split (20% of data)
    indices = np.arange(len(phonemes))
    np.random.shuffle(indices)
    split = int(len(indices) * 0.8)
    train_positions = indices[:split]
    val_positions = indices[split:]
    
    # Save validation positions for future runs
    np.save(validation_positions_path, val_positions)
    print(f"Created validation split with {len(val_positions)} samples")
    print(f"Validation positions saved to {validation_positions_path}")
else:
    print(f"Using existing validation positions from {validation_positions_path}")

# Generate balanced position indices for training - keep this for srA1 training
print("\nGenerating balanced position indices...")

try:
    # Generate balanced indices
    balanced_positions = generate_balanced_indices(
        PHONEMES_PATH,
        POSITIONS_PATH,
        OUTPUT_DIR,
        min_samples=500,      # Minimum samples per class
        max_ratio=5.0,        # Maximum ratio between classes
        time_steps=50         # Window size for context
    )
except Exception as e:
    print(f"Error generating balanced indices: {e}")
    import traceback
    traceback.print_exc()
    raise

try:
    #-------------------------------------------------------------------------------
    # CAUSAL PART - Keep using balanced positions for this part
    #-------------------------------------------------------------------------------
    
    # Adjust batch size for multi-GPU
    try:
        # Use larger batch size per replica
        BATCH_SIZE_PER_REPLICA = 256
        GLOBAL_BATCH_SIZE = BATCH_SIZE_PER_REPLICA * strategy.num_replicas_in_sync
    except:
        GLOBAL_BATCH_SIZE = 256  # Fallback
    
    # Phase 1: Causal Training with strategy and balanced positions
    print("\nStarting Causal Network Training (Phase 1) with balanced data...")
    with strategy.scope():
        trainCausalNN(
            filename_X=NEUROGRAM_PATH,
            filename_Y=PHONEMES_PATH,
            filename_idx=balanced_positions_path,
            file_identifier_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_a',
            epochs_to_save=1,
            epochs_total=12,
            batch_size=GLOBAL_BATCH_SIZE
        )
    
    # Clear memory after Phase 1
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Phase 2: Using best model from Phase 1
    print("\nStarting Causal Network Training (Phase 2)...")
    with strategy.scope():
        trainCausalNN(
            filename_X=NEUROGRAM_PATH,
            filename_Y=PHONEMES_PATH,
            filename_idx=balanced_positions_path,
            file_identifier_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_b',
            epochs_to_save=1,
            epochs_total=1,
            # Scale batch size by number of GPUs
            batch_size=1024 * strategy.num_replicas_in_sync,
            load_model=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_a_11.h5'
        )
    
    # Clear memory after Phase 2
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Phase 3: Final causal training
    print("\nStarting Causal Network Training (Phase 3)...")
    with strategy.scope():
        trainCausalNN(
            filename_X=NEUROGRAM_PATH,
            filename_Y=PHONEMES_PATH,
            filename_idx=balanced_positions_path,
            file_identifier_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c',
            epochs_to_save=1,
            epochs_total=1,
            # Scale batch size by number of GPUs
            batch_size=4096 * strategy.num_replicas_in_sync,
            load_model=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_b_0.h5'
        )
    
    # Clear memory after Phase 3
    gc.collect()
    tf.keras.backend.clear_session()
    
    # CRITICAL FIX: Combine the same model twice (matching the original script's approach)
    # This is counterintuitive but matches what worked in the runASRscript.py
    print("\nCombining models...")
    combineModelCausalNN(
        model_name_1=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c_0',    # Use the same model
        model_name_2=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c_0',    # Use the same model again!
        model_name_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi',
        filename_X1=NEUROGRAM_PATH,
        filename_X2=NEUROGRAM_PATH,
        filename_Y=PHONEMES_PATH,
        output_dir=OUTPUT_DIR
    )
    
    #-------------------------------------------------------------------------------
    # NON-CAUSAL PART - Keep using the original approach from successful run
    #-------------------------------------------------------------------------------
    
    # Adjust batch size for non-causal part
    try:
        BATCH_SIZE_PER_REPLICA = 512
        GLOBAL_BATCH_SIZE = BATCH_SIZE_PER_REPLICA * strategy.num_replicas_in_sync
    except:
        GLOBAL_BATCH_SIZE = 512  # Fallback
    
    # Non-causal training phase 1
    print("\nStarting Non-causal Network Training (Phase 1)...")
    print("Using balanced batch sampling with hierarchical data generator")
        
    with strategy.scope():
        trainNonCausalNN(
            filename_X=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_logp_combined_all.npy',
            filename_Y=PHONEMES_PATH,
            file_identifier_out=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_a',
            epochs_to_save=1,
            epochs_total=10,
            batch_size=GLOBAL_BATCH_SIZE,
            validation_positions_path=validation_positions_path,
            balanced_positions_path=balanced_positions_path  # Keep using just balanced positions
        )
    
    # Clear memory after Phase 1
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Non-causal training phase 2
    print("\nStarting Non-causal Network Training (Phase 2)...")
    with strategy.scope():
        trainNonCausalNN(
            filename_X=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_logp_combined_all.npy',
            filename_Y=PHONEMES_PATH,
            file_identifier_out=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_b',
            epochs_to_save=1,
            epochs_total=10,
            batch_size=GLOBAL_BATCH_SIZE,
            load_model=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_a_9.h5',
            validation_positions_path=validation_positions_path,
            balanced_positions_path=balanced_positions_path  # Keep using just balanced positions
        )
    
    # Clear memory after Phase 2
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Final predictions
    print("\nGenerating final predictions...")
    # Use the trained model for predictions
    predictPhonemeProbabilitiesNonCausalNN(
        filename_X=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_logp_combined_all.npy',
        filename_Y=PHONEMES_PATH,
        model_name=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_b_9',
        data_split_factor=0  # Set to 0 to predict on all data
    )

except Exception as e:
    print(f"Training failed with error: {e}")
    print(f"Error details: {type(e).__name__}, {str(e)}")
    import traceback
    traceback.print_exc()
    raise e

# Record end time
end_time = time.time()
elapsed_time = end_time - start_time
hours, remainder = divmod(elapsed_time, 3600)
minutes, seconds = divmod(remainder, 60)

print("Complete ASR training pipeline completed successfully!")
print(f"Retraining completed at {time.strftime('%a %b %d %H:%M:%S %Z %Y', time.localtime())}")
print(f"Total training time: {int(hours)} hours, {int(minutes)} minutes, {int(seconds)} seconds")
