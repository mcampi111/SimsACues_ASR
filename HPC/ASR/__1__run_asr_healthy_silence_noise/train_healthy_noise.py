import numpy as np
import tensorflow as tf
import gc
import os
from srA1 import trainCausalNN
from srA1predict import combineModelCausalNN
from srA2 import trainNonCausalNN
from srA2predict import predictPhonemeProbabilitiesNonCausalNN

# Define output directory
OUTPUT_DIR = 'results/healthy/noise'

# Create output directory if it doesn't exist
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Configure memory growth
physical_devices = tf.config.list_physical_devices('GPU')
for device in physical_devices:
    try:
        tf.config.experimental.set_memory_growth(device, True)
    except:
        pass

# Set up multi-GPU strategy
strategy = tf.distribute.MirroredStrategy()
print(f"Number of devices: {strategy.num_replicas_in_sync}")

# Define file paths
NEUROGRAM_PATH = 'TIMIT_Neuro/train/TIMIT_neurogram_with_noise_scaled.npy'
PHONEMES_PATH = 'Phonemes39_posindex_labels/train/healthy_noise/Phonemes39consecutive_true_train_healthy_noise.npy'
POSITIONS_PATH = 'Phonemes39_posindex_labels/train/healthy_noise/Phonemes39_position_index_true_train_healthy_noise.npy'

# Test data loading
print("Loading data...")
scaled_data = np.load(NEUROGRAM_PATH)
phonemes = np.load(PHONEMES_PATH)
positions = np.load(POSITIONS_PATH)

print("Data shapes:")
print("Scaled data:", scaled_data.shape)
print("Phonemes:", phonemes.shape)
print("Positions:", positions.shape)

try:
    #-------------------------------------------------------------------------------
    # CAUSAL PART
    #-------------------------------------------------------------------------------
    
    # Adjust batch size for multi-GPU
    GLOBAL_BATCH_SIZE = 128 * strategy.num_replicas_in_sync
    
    # Phase 1: Causal Training with strategy
    print("\nStarting Causal Network Training (Phase 1)...")
    with strategy.scope():
        trainCausalNN(
            filename_X=NEUROGRAM_PATH,
            filename_Y=PHONEMES_PATH,
            filename_idx=POSITIONS_PATH,
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
            filename_idx=POSITIONS_PATH,
            file_identifier_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_b',
            epochs_to_save=1,
            epochs_total=1,
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
            filename_idx=POSITIONS_PATH,
            file_identifier_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c',
            epochs_to_save=1,
            epochs_total=1,
            batch_size=4096 * strategy.num_replicas_in_sync,
            load_model=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_b_0.h5'
        )
    
    # Clear memory after Phase 3
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Combine models
    print("\nCombining models...")
    combineModelCausalNN(
        model_name_1=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c_0',
        model_name_2=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_c_0',
        model_name_out=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi',
        filename_X1=NEUROGRAM_PATH,
        filename_X2=NEUROGRAM_PATH,
        filename_Y=PHONEMES_PATH
    )
    
    #-------------------------------------------------------------------------------
    # NON-CAUSAL PART
    #-------------------------------------------------------------------------------
    
    # Adjust batch size for non-causal part
    BATCH_SIZE_PER_REPLICA = 512
    GLOBAL_BATCH_SIZE = BATCH_SIZE_PER_REPLICA * strategy.num_replicas_in_sync
    
    # Non-causal training phase 1
    print("\nStarting Non-causal Network Training (Phase 1)...")
    with strategy.scope():
        trainNonCausalNN(
            filename_X=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_logp_combined_all.npy',
            filename_Y=PHONEMES_PATH,
            file_identifier_out=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_a',
            epochs_to_save=1,
            epochs_total=10,
            batch_size=GLOBAL_BATCH_SIZE,
            reduce_factor=10
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
            reduce_factor=1,
            load_model=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_a_9.h5'
        )
    
    # Clear memory after Phase 2
    gc.collect()
    tf.keras.backend.clear_session()
    
    # Final predictions
    print("\nGenerating final predictions...")
    predictPhonemeProbabilitiesNonCausalNN(
        filename_X=f'{OUTPUT_DIR}/srA1_TIMIT_full_multi_logp_combined_all.npy',
        filename_Y=PHONEMES_PATH,
        model_name=f'{OUTPUT_DIR}/srA2_TIMIT_full_multi_b_9',
        data_split_factor=0
    )

except Exception as e:
    print(f"Training failed with error: {e}")
    raise e

print("Complete Healthy Noise ASR training pipeline completed successfully!")
