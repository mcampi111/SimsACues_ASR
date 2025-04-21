# -*- coding: utf-8 -*-
"""
Modified srA2predict.py to match successful run processing all samples
"""

import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix
import sklearn
import os
import sys

# Import the custom loss functions from srA2.py
try:
    from srA2 import weighted_categorical_crossentropy_40, weighted_categorical_crossentropy_5
    from DataGenTimitTri import DataGeneratorTri
except ImportError:
    # Define the functions inline if import fails
    def weighted_categorical_crossentropy_40(weights):
        """Weighted categorical crossentropy for 40-class outputs."""
        weights = tf.constant(weights, dtype=tf.float32)

        def loss_fn(y_true, y_pred):
            sample_weights = tf.reduce_sum(y_true * tf.reshape(weights, [1, -1]), axis=-1)
            ce_loss = tf.keras.losses.categorical_crossentropy(y_true, y_pred)
            return tf.reduce_mean(ce_loss * sample_weights)
        
        return loss_fn
        
    def weighted_categorical_crossentropy_5(weights):
        """Weighted categorical crossentropy for 5-class phoneme groups."""
        group_weights = tf.ones(5, dtype=tf.float32)
        
        def loss_fn(y_true, y_pred):
            sample_weights = tf.reduce_sum(y_true * tf.reshape(group_weights, [1, -1]), axis=-1)
            ce_loss = tf.keras.losses.categorical_crossentropy(y_true, y_pred)
            return tf.reduce_mean(ce_loss * sample_weights)
        
        return loss_fn


def predictPhonemeProbabilitiesNonCausalNN(filename_X, filename_Y, model_name, data_split_factor=1):
    """
    Generate phoneme predictions using a trained non-causal neural network.
    
    Args:
        filename_X: Path to input features
        filename_Y: Path to phoneme labels
        model_name: Path to saved model (without .h5 extension)
        data_split_factor: Factor to divide input data by
    """
    # Create output directory if it doesn't exist
    save_dir = os.path.dirname(model_name)
    if save_dir:
        os.makedirs(save_dir, exist_ok=True)
        
    # Load data
    print(f"Loading data from {filename_X} and {filename_Y}")
    X = np.load(filename_X)
    Y = np.load(filename_Y)
    
    # CRITICAL FIX: Apply the 50-frame offset like in the successful run
    # This manually aligns phoneme labels with frames instead of filtering
    Y = Y[50:]  # 50 timesteps from first causal NN
    
    print(f"X shape: {X.shape}, Y shape: {Y.shape}")

    # Standardize X if data_split_factor is not 1 and not 0
    if data_split_factor != 1 and data_split_factor != 0:
        print(f"Scaling input data by factor {data_split_factor}")
        X = X / data_split_factor
    elif data_split_factor == 0:
        print("Skipping scaling as data_split_factor is 0 (processing all data)")

    # Calculate class weights for the custom loss function
    class_frequencies = np.bincount(np.array(Y, dtype=np.int32), minlength=40)
    
    # Calculate alpha weights (same as in srA2.py)
    alpha_weights = np.ones(40)
    total_samples = np.sum(class_frequencies)
    
    for i in range(40):
        if class_frequencies[i] > 0:
            alpha_weights[i] = 1.0 - 0.3 * np.sqrt(class_frequencies[i] / total_samples)
    
    # Normalize to have mean of 1.0
    alpha_weights = alpha_weights / np.mean(alpha_weights)
    print(f"Alpha weights for focal loss: {alpha_weights}")
    
    # Load the trained model with custom loss functions
    model_path = f"{model_name}.h5"
    print(f"Loading model weights from: {model_path}")
    
    try:
        # Set up the model architecture first (same as in srA2.py)
        time_window = 305
        n_features = 40
        pool_size = 5
        non_causal_steps = time_window // 2
        
        with tf.device('/cpu:0'):
            # Input layer
            input_layer = tf.keras.layers.Input(shape=(time_window, n_features), name="input")
            
            # Pooling layer to reduce time steps (5ms → 10ms)
            x = tf.keras.layers.AveragePooling1D(pool_size=pool_size, name="pool_10ms")(input_layer)
            
            # Bidirectional GRU layers with increased capacity and dropout
            x = tf.keras.layers.Bidirectional(
                tf.keras.layers.GRU(256, return_sequences=True),
                name="gru1"
            )(x)
            x = tf.keras.layers.Dropout(0.2)(x)
            
            x = tf.keras.layers.Bidirectional(
                tf.keras.layers.GRU(256),
                name="gru2"
            )(x)
            x = tf.keras.layers.Dropout(0.2)(x)
            
            # Add self-attention mechanism
            query = tf.keras.layers.Dense(512, name="attention_query")(x)
            key = tf.keras.layers.Dense(512, name="attention_key")(x)
            value = tf.keras.layers.Dense(512, name="attention_value")(x)
            
            # Expand dimensions for attention calculation
            x_expanded = tf.expand_dims(x, axis=1)
            query_expanded = tf.expand_dims(query, axis=1)
            key_expanded = tf.expand_dims(key, axis=1)
            value_expanded = tf.expand_dims(value, axis=1)
            
            # Scaled dot-product attention
            attention_scores = tf.matmul(query_expanded, key_expanded, transpose_b=True)
            attention_scores = attention_scores / tf.math.sqrt(tf.cast(tf.shape(key)[-1], tf.float32))
            attention_weights = tf.nn.softmax(attention_scores, axis=-1)
            context_vector = tf.matmul(attention_weights, value_expanded)
            context_vector = tf.squeeze(context_vector, axis=1)
            
            # Combine with original representation (residual connection)
            x = x + context_vector
            x = tf.keras.layers.LayerNormalization(name="attention_layer_norm")(x)
            
            # Phoneme group classification (high-level categories)
            phoneme_group = tf.keras.layers.Dense(5, activation='softmax', name='phoneme_group')(x)
            
            # Concatenate phoneme group predictions with attention output
            x = tf.keras.layers.Concatenate()([x, phoneme_group])
            
            # Three output heads for predicting previous, current, and next phoneme
            output_prev = tf.keras.layers.Dense(n_features, activation='softmax', name='out_prev2')(x)
            output_now = tf.keras.layers.Dense(n_features, activation='softmax', name='out_now2')(x)
            output_next = tf.keras.layers.Dense(n_features, activation='softmax', name='out_next2')(x)
            
            # Create model
            model = tf.keras.Model(inputs=input_layer, outputs=[phoneme_group, output_prev, output_now, output_next])
        
        # Compile model with custom loss functions
        optimizer = tf.keras.optimizers.legacy.Adam(learning_rate=0.001)
        
        with tf.keras.utils.custom_object_scope({
            'loss_fn': weighted_categorical_crossentropy_40(alpha_weights)
        }):
            model.compile(
                optimizer=optimizer,
                loss={
                    'phoneme_group': weighted_categorical_crossentropy_5(alpha_weights),
                    'out_prev2': weighted_categorical_crossentropy_40(alpha_weights),
                    'out_now2': weighted_categorical_crossentropy_40(alpha_weights),
                    'out_next2': weighted_categorical_crossentropy_40(alpha_weights)
                },
                metrics={
                    'phoneme_group': 'categorical_accuracy',
                    'out_prev2': 'categorical_accuracy',
                    'out_now2': 'categorical_accuracy',
                    'out_next2': 'categorical_accuracy'
                }
            )
        
            # Load only the weights
            model.load_weights(model_path)
            print("Model weights loaded successfully")
    except Exception as e:
        print(f"Error loading model weights: {e}")
        print(f"Error details: {type(e).__name__}, {str(e)}")
        return
    
    # Create a data generator for proper shape handling
    batch_size = 256
    out_dim = (batch_size, time_window, n_features)
    
    # CRITICAL FIX: Process ALL indices like in successful run
    # Instead of filtering for context, we use all indices and let the generator handle it
    idx = np.arange(len(X))
    
    # COMMENTED OUT: The aggressive filtering that reduced data from 7.7M to 116K samples
    #filtered_indices = []
    #for idx in all_indices:
    #    if (idx >= time_window - non_causal_steps - 1 and 
    #        idx < len(X) and 
    #        idx - non_causal_steps >= 0 and 
    #        idx - non_causal_steps < len(Y)):
    #        filtered_indices.append(idx)
    #idx = np.array(filtered_indices)  # Use ALL valid indices
    
    print(f"Using all {len(idx)} indices for prediction")
    
    # Create data generators for context-based processing
    print(f"Creating data generator with timesteps: {time_window}")
    
    # For context filtering during batch generation to avoid memory issues
    print("Initializing data generator...")
    data_generator = DataGeneratorTri(
        idx, X, Y, 
        out_dim=out_dim,
        shuffle=False,  # No shuffling for prediction
        reduce_factor=1,
        non_causal_steps=non_causal_steps
    )
    
    print(f"Data Generator initialized with: batch_size={batch_size}, time_steps={time_window}, features={n_features}, non_causal_steps={non_causal_steps}")
    print(f"DataGeneratorTri initialized with {len(idx)} valid indices")
    
    # Try to evaluate model
    try:
        evaluation = model.evaluate(data_generator, verbose=1)
        print("Evaluation results:", evaluation)
    except Exception as e:
        print(f"Error during evaluation: {e}")
        print(f"Exception details: {type(e).__name__}, {str(e)}")
        print("Continuing with prediction despite evaluation error...")
    
    # Generate predictions batch by batch 
    print("Making predictions batch by batch...")
    try:
        # Initialize arrays to store predictions
        all_predictions_prev = []
        all_predictions_now = []
        all_predictions_next = []
        all_predictions_group = []
        all_true_labels = []
        
        # Process each batch
        for i in range(len(data_generator)):
            if i % 50 == 0:
                print(f"Processing batch {i}/{len(data_generator)}")
                
            # Get data batch
            batch_x, batch_y = data_generator[i]
            
            # Get true labels - use the "now" phoneme (index 1 in the tri-output)
            if isinstance(batch_y, list) and len(batch_y) >= 2:
                true_batch = np.argmax(batch_y[1], axis=1)  # Use current phoneme (out_now2)
            else:
                print("Warning: Unexpected batch_y format")
                true_batch = np.zeros(batch_x.shape[0], dtype=int)
                
            all_true_labels.append(true_batch)
            
            # Make predictions for this batch
            batch_preds = model.predict(batch_x, verbose=0)
            
            # Handle the 4-output model format (group, prev, now, next)
            all_predictions_group.append(batch_preds[0])  # phoneme_group
            all_predictions_prev.append(batch_preds[1])   # out_prev2
            all_predictions_now.append(batch_preds[2])    # out_now2
            all_predictions_next.append(batch_preds[3])   # out_next2
        
        # Combine all batches
        predictions_group = np.vstack(all_predictions_group)
        predictions_prev = np.vstack(all_predictions_prev)
        predictions_now = np.vstack(all_predictions_now)
        predictions_next = np.vstack(all_predictions_next)
        true_labels = np.concatenate(all_true_labels)
        
        print(f"Final shapes - Predictions: {predictions_now.shape}, True labels: {true_labels.shape}")
        
        # Save prediction probabilities
        base_name = os.path.basename(model_name)
        out_dir = save_dir if save_dir else '.'
        
        group_file = os.path.join(out_dir, f"{base_name}_p_group.npy")
        prev_file = os.path.join(out_dir, f"{base_name}_p_prev.npy")
        now_file = os.path.join(out_dir, f"{base_name}_p_now.npy")
        next_file = os.path.join(out_dir, f"{base_name}_p_next.npy")
        
        np.save(group_file, predictions_group)
        np.save(prev_file, predictions_prev)
        np.save(now_file, predictions_now)
        np.save(next_file, predictions_next)
        
        print(f"Saved prediction probabilities to:")
        print(f"  {group_file}")
        print(f"  {prev_file}")
        print(f"  {now_file}")
        print(f"  {next_file}")
        
        # Get the most likely phoneme for each frame
        Y_pred = np.argmax(predictions_now, axis=1)
        
        # Get original Y values (not one-hot encoded)
        Y_true = true_labels
        
        # Calculate accuracy
        correct_predictions = np.sum(Y_pred == Y_true)
        total_predictions = len(Y_true)
        accuracy = correct_predictions / total_predictions
        print(f"Number of samples: {total_predictions}")
        print(f"Prediction accuracy: {accuracy:.4f} ({correct_predictions}/{total_predictions})")
        
        # Calculate per-class accuracy
        for cls in range(40):
            class_mask = (Y_true == cls)
            class_count = np.sum(class_mask)
            if class_count > 0:
                class_correct = np.sum(Y_pred[class_mask] == cls)
                class_accuracy = class_correct / class_count
                print(f"Class {cls} accuracy: {class_accuracy:.4f} ({class_correct}/{class_count})")
        
        # Save prediction results
        pred_file = os.path.join(out_dir, f"Phonemes39pred_{base_name}.npy")
        true_file = os.path.join(out_dir, f"Phonemes39true_{base_name}.npy")
        
        np.save(pred_file, Y_pred)
        np.save(true_file, Y_true)
        
        print(f"Saved prediction results to:")
        print(f"  {pred_file}")
        print(f"  {true_file}")
        
        # Generate confusion matrix
        try:
            conf_matrix = confusion_matrix(Y_true, Y_pred)
            print("Confusion matrix shape:", conf_matrix.shape)
            
            # Find top confused pairs (by absolute number)
            conf_matrix_copy = conf_matrix.copy()
            np.fill_diagonal(conf_matrix_copy, 0)  # Zero out diagonal to find off-diagonal elements
            flat_indices = np.argsort(conf_matrix_copy.flatten())[-5:]  # Top 5 confused pairs
            row_indices, col_indices = np.unravel_index(flat_indices, conf_matrix.shape)
            
            print("\nTop 5 class confusion pairs (absolute numbers):")
            for i, j in zip(row_indices, col_indices):
                true_count = np.sum(Y_true == i)
                if true_count > 0:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times ({conf_matrix[i, j]/true_count*100:.2f}%)")
                else:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times (0.00%)")
            
            # Find top confused pairs (by confusion rate)
            confusion_rates = np.zeros_like(conf_matrix, dtype=float)
            for i in range(conf_matrix.shape[0]):
                row_sum = np.sum(Y_true == i)
                if row_sum > 0:
                    confusion_rates[i, :] = conf_matrix[i, :] / row_sum
            
            np.fill_diagonal(confusion_rates, 0)  # Zero out diagonal
            flat_indices = np.argsort(confusion_rates.flatten())[-5:]  # Top 5 by rate
            row_indices, col_indices = np.unravel_index(flat_indices, confusion_rates.shape)
            
            print("\nTop 5 class confusion pairs (by confusion rate):")
            for i, j in zip(row_indices, col_indices):
                true_count = np.sum(Y_true == i)
                if true_count > 0:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times ({confusion_rates[i, j]*100:.2f}%)")
            
            # Save confusion matrix
            conf_matrix_file = os.path.join(out_dir, f"{base_name}_confusion_matrix.npy")
            np.save(conf_matrix_file, conf_matrix)
            print(f"Saved confusion matrix to {conf_matrix_file}")
                    
        except Exception as e:
            print(f"Could not compute confusion matrix: {e}")
        
    except Exception as e:
        print(f"Error during prediction: {e}")
        print(f"Traceback: {sys.exc_info()}")
        import traceback
        traceback.print_exc()
        
    print("Prediction completed.")
    return
