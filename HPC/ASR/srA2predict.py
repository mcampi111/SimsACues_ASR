
import numpy as np
import tensorflow as tf
from sklearn.metrics import confusion_matrix
import sklearn
import os
import sys
from DataGenTimitTri import DataGeneratorTri
from phoneme_grouping import get_phoneme_groups, get_group_name

# Import or define the focal loss function
def focal_loss(gamma=2.0, alpha=None):
    """
    Focal loss for multi-class classification.
    
    Args:
        gamma: Focusing parameter. Higher gamma means more focus on hard examples.
        alpha: Optional weighting factor array. If provided, must be of size equal to the number of classes.
    
    Returns:
        A loss function.
    """
    # Store alpha as a tensor outside the inner function to avoid scoping issues
    alpha_tensor = None
    if alpha is not None:
        alpha_tensor = tf.constant(alpha, dtype=tf.float32)
    
    def loss_fn(y_true, y_pred):
        # Clip prediction values to avoid log(0) errors
        epsilon = 1e-7
        y_pred = tf.clip_by_value(y_pred, epsilon, 1.0 - epsilon)
        
        # Calculate cross entropy
        cross_entropy = -y_true * tf.math.log(y_pred)
        
        # Calculate focal weight - apply more weight to hard examples
        if gamma > 0:
            focal_weight = tf.pow(1 - y_pred, gamma)
            cross_entropy = focal_weight * cross_entropy
        
        # Apply alpha weighting if provided
        if alpha_tensor is not None:
            alpha_factor = y_true * tf.reshape(alpha_tensor, [1, -1])
            cross_entropy = alpha_factor * cross_entropy
        
        # Sum over all classes
        loss = tf.reduce_sum(cross_entropy, axis=-1)
        
        # Return mean across samples
        return tf.reduce_mean(loss)
    
    return loss_fn

def predictPhonemeProbabilitiesNonCausalNN(filename_X, filename_Y, model_name, original_phonemes_path=None, data_split_factor=1):
    """
    Generate phoneme predictions using a trained non-causal neural network.
    
    Args:
        filename_X: Path to input features
        filename_Y: Path to phoneme labels (grouped)
        model_name: Path to saved model (without .h5 extension)
        original_phonemes_path: Path to original ungrouped phonemes (for comparison)
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
    Y = Y[50:]  # 50 timesteps in first causal NN
    print(f"X shape: {X.shape}, Y shape: {Y.shape}")
    
    # Load original phonemes if provided (for comparison)
    Y_original = None
    if original_phonemes_path:
        print(f"Loading original phonemes from {original_phonemes_path} for comparison")
        Y_original = np.load(original_phonemes_path)
        Y_original = Y_original[50:]  # 50 timesteps in first causal NN
        print(f"Original phonemes shape: {Y_original.shape}")

    # Standardize X if data_split_factor is not 1 and not 0
    if data_split_factor != 1 and data_split_factor != 0:
        print(f"Scaling input data by factor {data_split_factor}")
        X = X / data_split_factor
    elif data_split_factor == 0:
        print("Skipping scaling as data_split_factor is 0 (processing all data)")

    # Calculate class frequencies and weights
    class_frequencies = np.bincount(Y.astype(np.int32), minlength=105)  # Increased to 105 for group classes
    total_samples = len(Y)
    
    # Extremely aggressive alpha to compensate for the 99%/1% imbalance
    alpha = np.ones(105)  # Increased to 105 for group classes
    for i in range(len(class_frequencies)):
        if i < len(alpha) and class_frequencies[i] > 0:
            # Inverse frequency with heavy smoothing
            alpha[i] = (1 - (class_frequencies[i] / total_samples)) ** 0.5
    
    # Normalize alpha
    alpha = alpha / np.mean(alpha)
    
    print("Class frequencies:", class_frequencies)
    print("Alpha weights for focal loss:", alpha)
    
    # Parameters for the model
    time_window = 305  # 50ms context on each side
    non_causal_steps = time_window // 2
    n_features = 40  # Number of phoneme probabilities from srA1
    pool_size = 5  # For 10ms frames
    num_phoneme_groups = 5  # Number of phoneme groups (must match training)
    
    # Build the model with hierarchical classification approach
    with tf.device('/cpu:0'):  # Build on CPU to avoid OOM on GPU
        # Input layer
        input_layer = tf.keras.layers.Input(shape=(time_window, n_features), name="input")
        
        # Pooling layer to reduce time steps (5ms → 10ms)
        x = tf.keras.layers.AveragePooling1D(pool_size=pool_size, name="pool_10ms")(input_layer)
        
        # Bidirectional GRU layers with increased capacity (128->256) and dropout
        gru1_input = x  # For residual connection
        
        x = tf.keras.layers.Bidirectional(
            tf.keras.layers.GRU(256, return_sequences=True),
            name="gru1"
        )(x)
        x = tf.keras.layers.Dropout(0.2)(x)  # Add dropout for regularization
        
        # Residual connection if shapes match (not applied in first layer due to pooling)
        
        x = tf.keras.layers.Bidirectional(
            tf.keras.layers.GRU(256),
            name="gru2"
        )(x)
        x = tf.keras.layers.Dropout(0.2)(x)  # Add dropout for regularization
        
        # Add self-attention mechanism with increased dimensions
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
        
        # Add phoneme category classifier (hierarchical approach)
        phoneme_group = tf.keras.layers.Dense(num_phoneme_groups, activation='softmax', name='phoneme_group')(x)
        
        # Create a feature representation enriched with phoneme group information
        x_with_group = tf.keras.layers.Concatenate()([x, phoneme_group])
        
        # Three output heads for predicting previous, current, and next phoneme
        output_prev = tf.keras.layers.Dense(n_features, activation='softmax', name='out_prev2')(x_with_group)
        output_now = tf.keras.layers.Dense(n_features, activation='softmax', name='out_now2')(x_with_group)
        output_next = tf.keras.layers.Dense(n_features, activation='softmax', name='out_next2')(x_with_group)
        
        # Create model
        model = tf.keras.Model(inputs=input_layer, outputs=[phoneme_group, output_prev, output_now, output_next])
    
    # Compile model with the same loss functions and metrics
    model.compile(
        optimizer='adam',  # Doesn't matter for prediction
        loss={
            'phoneme_group': 'categorical_crossentropy',
            'out_prev2': focal_loss(gamma=2.0, alpha=alpha),
            'out_now2': focal_loss(gamma=2.0, alpha=alpha),
            'out_next2': focal_loss(gamma=2.0, alpha=alpha)
        },
        loss_weights={
            'phoneme_group': 0.2,
            'out_prev2': 1.0,
            'out_now2': 1.0,
            'out_next2': 1.0
        },
        metrics={
            'phoneme_group': 'categorical_accuracy',
            'out_prev2': 'categorical_accuracy',
            'out_now2': 'categorical_accuracy',
            'out_next2': 'categorical_accuracy'
        }
    )
    
    # Load the trained model weights
    model_path = f"{model_name}.h5"
    print(f"Loading model weights from: {model_path}")
    
    try:
        # Load just the weights, not the full model
        model.load_weights(model_path)
        print("Model weights loaded successfully")
    except Exception as e:
        print(f"Error loading model weights: {e}")
        print("Please ensure the weights file exists and has the correct format.")
        return
    
    # Create data generator for evaluation and prediction
    print(f"Creating data generator with timesteps: {time_window}")
    
    # Filter indices that don't have enough context
    filtered_indices = []
    for i in range(len(X)):
        if i >= non_causal_steps and i < len(X) - non_causal_steps:
            filtered_indices.append(i)
    
    filtered_indices = np.array(filtered_indices)  # Convert to numpy array
    
    print(f"Filtered out {len(X) - len(filtered_indices)} indices that didn't have enough context")
    
    # Create phoneme groups for data generator
    def create_phoneme_groups(y_data):
        # Simple example mapping: 
        # Group 0: classes 0-7
        # Group 1: classes 8-15
        # Group 2: classes 16-23 
        # Group 3: classes 24-31
        # Group 4: classes 32-39
        groups = np.zeros((len(y_data), num_phoneme_groups))
        for i, label in enumerate(y_data):
            group_idx = min(int(label) // 8, num_phoneme_groups - 1)
            groups[i, group_idx] = 1
        return groups
    
    # Get group labels
    Y_groups = create_phoneme_groups(Y)
    
    # Define output dimensions for the DataGeneratorTri - using batch size of 256
    batch_size = 256
    out_dim = (batch_size, time_window, n_features)
    
    # Create hierarchical data generator
    class HierarchicalDataGenerator(DataGeneratorTri):
        def __init__(self, idx, X, Y, Y_groups, out_dim=(64, 128, 2, 192), shuffle=True, reduce_factor=1, non_causal_steps=0):
            super().__init__(idx, X, Y, out_dim, shuffle, reduce_factor, non_causal_steps)
            self.Y_groups = Y_groups
            
        def __getitem__(self, index):
            X, [Y1, Y2, Y3] = super().__getitem__(index)
            
            # Get phoneme group labels for this batch
            group_indices = [self.idx[k] for k in self.indexes[index*self.batch_size:(index+1)*self.batch_size]]
            batch_groups = np.zeros((len(group_indices), num_phoneme_groups))
            for i, idx in enumerate(group_indices):
                target_idx = min(idx - self.non_causal_steps, len(self.Y_groups) - 1)
                target_idx = max(0, target_idx)  # Ensure index is not negative
                if target_idx < len(self.Y_groups):
                    batch_groups[i] = self.Y_groups[target_idx]
            
            return X, [batch_groups, Y1, Y2, Y3]
    
    # Create generator with the correct parameters
    print("Initializing data generator...")
    data_generator = HierarchicalDataGenerator(
        filtered_indices, X, Y, Y_groups,
        out_dim=out_dim,
        shuffle=False,  # No shuffling for prediction
        reduce_factor=1,
        non_causal_steps=non_causal_steps
    )
    
    # Evaluate model performance using generator
    print(f"Evaluating model with generator length: {len(data_generator)}")
    try:
        evaluation = model.evaluate(data_generator, verbose=1)
        print("Evaluation results:", evaluation)
    except Exception as e:
        print(f"Error during evaluation: {e}")
        print(f"Exception details: {type(e).__name__}, {str(e)}")
    
    # Generate predictions batch by batch 
    print("Making predictions batch by batch...")
    try:
        # Initialize arrays to store predictions
        all_group_predictions = []
        all_predictions_prev = []
        all_predictions_now = []
        all_predictions_next = []
        all_true_labels = []
        
        # Process each batch
        for i in range(len(data_generator)):
            if i % 50 == 0:
                print(f"Processing batch {i}/{len(data_generator)}")
                
            # Get data batch
            batch_x, batch_y = data_generator[i]
            
            # Get true labels - now batch_y is [groups, prev, now, next]
            if isinstance(batch_y, list) and len(batch_y) > 2:
                true_batch = np.argmax(batch_y[2], axis=1)  # Use current phoneme
            else:
                true_batch = np.argmax(batch_y, axis=1)
                
            all_true_labels.append(true_batch)
            
            # Make predictions for this batch
            batch_preds = model.predict(batch_x, verbose=0)
            
            # Store batch predictions
            all_group_predictions.append(batch_preds[0])
            all_predictions_prev.append(batch_preds[1])
            all_predictions_now.append(batch_preds[2])
            all_predictions_next.append(batch_preds[3])
        
        # Combine all batches
        group_predictions = np.vstack(all_group_predictions)
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
        
        np.save(group_file, group_predictions)
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
        accuracy = np.mean(Y_pred == Y_true)
        print(f"Number of samples: {len(Y_true)}")
        print(f"Standard accuracy: {accuracy:.4f} ({np.sum(Y_pred == Y_true)}/{len(Y_true)})")
        
        # Calculate per-class accuracy
        class_accuracies = []
        for cls in range(105):  # Updated to 105 for group IDs
            mask = (Y_true == cls)
            if np.sum(mask) > 0:
                class_acc = np.mean(Y_pred[mask] == Y_true[mask])
                class_accuracies.append((cls, class_acc, np.sum(mask)))
                print(f"Class {cls} accuracy: {class_acc:.4f} ({np.sum(Y_pred[mask] == Y_true[mask])}/{np.sum(mask)})")
        
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
            
            # Find top confused pairs
            conf_matrix_copy = conf_matrix.copy()
            np.fill_diagonal(conf_matrix_copy, 0)  # Zero out diagonal to find off-diagonal elements
            
            # Calculate confusion rates (normalized by class frequency)
            class_total = np.sum(conf_matrix, axis=1)
            confusion_rate = conf_matrix_copy / class_total[:, np.newaxis]
            
            # Find top confused pairs (absolute numbers)
            flat_indices = np.argsort(conf_matrix_copy.flatten())[-5:]  # Top 5 confused pairs
            row_indices, col_indices = np.unravel_index(flat_indices, conf_matrix.shape)
            
            print("\nTop 5 class confusion pairs (absolute numbers):")
            for i, j in zip(row_indices, col_indices):
                true_count = np.sum(Y_true == i)
                if true_count > 0:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times ({conf_matrix[i, j]/true_count*100:.2f}%)")
                else:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times (0.00%)")
            
            # Find top confused pairs (by rate)
            flat_indices = np.argsort(confusion_rate.flatten())[-5:]  # Top 5 confused pairs by rate
            row_indices, col_indices = np.unravel_index(flat_indices, confusion_rate.shape)
            
            print("\nTop 5 class confusion pairs (by confusion rate):")
            for i, j in zip(row_indices, col_indices):
                true_count = np.sum(Y_true == i)
                if true_count > 0:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times ({confusion_rate[i, j]*100:.2f}%)")
                else:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times (0.00%)")
            
            # Save confusion matrix
            conf_matrix_file = os.path.join(out_dir, f"{base_name}_confusion_matrix.npy")
            np.save(conf_matrix_file, conf_matrix)
            print(f"Saved confusion matrix to {conf_matrix_file}")
            
            # Evaluate with phoneme grouping for rare classes (if original phonemes available)
            if Y_original is not None:
                print("\nEvaluating with phoneme grouping for rare classes...")
                mapping = get_phoneme_groups()
                
                # Get predictions in the original phoneme space
                Y_pred_original = Y_pred.copy()
                Y_true_original = Y_original[non_causal_steps:len(Y_original)-non_causal_steps]
                
                # Ensure correct dimensions
                Y_true_original = Y_true_original[:len(Y_pred_original)]
                
                # Create mapped versions for evaluation
                Y_pred_mapped = Y_pred_original.copy()
                Y_true_mapped = Y_true_original.copy()
                
                # Apply mapping to both predictions and true labels
                for orig_id, group_id in mapping.items():
                    # Map predicted original phonemes to their group ID
                    Y_pred_mapped[Y_pred_original == orig_id] = group_id
                    # Map true original phonemes to their group ID
                    Y_true_mapped[Y_true_original == orig_id] = group_id
                
                # Calculate accuracy with grouped phonemes
                grouped_accuracy = np.mean(Y_pred_mapped == Y_true_mapped)
                print(f"Accuracy with grouped rare phonemes: {grouped_accuracy:.4f} ({np.sum(Y_pred_mapped == Y_true_mapped)}/{len(Y_true_mapped)})")
                
                # Calculate per-group accuracy for the phoneme groups
                for group_id in sorted(set(mapping.values())):
                    mask = (Y_true_mapped == group_id)
                    if np.sum(mask) > 0:
                        group_acc = np.mean(Y_pred_mapped[mask] == Y_true_mapped[mask])
                        group_name = get_group_name(group_id)
                        print(f"Group {group_id} ({group_name}) accuracy: {group_acc:.4f} ({np.sum(Y_pred_mapped[mask] == Y_true_mapped[mask])}/{np.sum(mask)})")
                
                # Calculate accuracy for individual rare phonemes (for comparison)
                print("\nIndividual rare phoneme accuracy:")
                for orig_id in sorted(mapping.keys()):
                    mask = (Y_true_original == orig_id)
                    if np.sum(mask) > 0:
                        orig_acc = np.mean(Y_pred_original[mask] == Y_true_original[mask])
                        print(f"Phoneme {orig_id} accuracy: {orig_acc:.4f} ({np.sum(Y_pred_original[mask] == Y_true_original[mask])}/{np.sum(mask)})")
                        
        except Exception as e:
            print(f"Could not compute confusion matrix: {e}")
        
    except Exception as e:
        print(f"Error during prediction: {e}")
        import traceback
        traceback.print_exc()
        
    print("Prediction completed.")
    return
