import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix
import sklearn
import os
import sys
from DataGenTimitTri import DataGeneratorTri

# Import or define the weighted loss function
def weighted_categorical_crossentropy(weights):
    """Weighted categorical crossentropy loss function."""
    weights = tf.constant(weights, dtype=tf.float32)

    def loss_fn(y_true, y_pred):
        # Calculate sample weights based on class weights
        sample_weights = tf.reduce_sum(y_true * tf.reshape(weights, [1, -1]), axis=-1)
        
        # Standard categorical cross entropy
        ce_loss = tf.keras.losses.categorical_crossentropy(y_true, y_pred)
        
        # Apply weights and return mean
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
    Y = Y[50:]  # 50 timesteps in first causal NN
    print(f"X shape: {X.shape}, Y shape: {Y.shape}")

    # Standardize X if data_split_factor is not 1 and not 0
    if data_split_factor != 1 and data_split_factor != 0:
        print(f"Scaling input data by factor {data_split_factor}")
        X = X / data_split_factor
    elif data_split_factor == 0:
        print("Skipping scaling as data_split_factor is 0 (processing all data)")

    # Calculate class weights for the custom loss function
    class_weight = sklearn.utils.class_weight.compute_class_weight(
        class_weight='balanced',
        classes=np.unique(Y),
        y=Y
    )
    print(f"Class weights computed for {len(np.unique(Y))} unique classes")
    
    # Normalize weights
    weight_values = np.array(class_weight) / np.mean(class_weight)
    
    # Parameters for the model
    time_window = 305  # 50ms context on each side
    non_causal_steps = time_window // 2
    n_features = 40  # Number of phoneme probabilities from srA1
    pool_size = 5  # For 10ms frames
    
    # Build the model with the same architecture as in srA2.py
    with tf.device('/cpu:0'):  # Build on CPU to avoid OOM on GPU
        # Input layer
        input_layer = tf.keras.layers.Input(shape=(time_window, n_features), name="input")
        
        # Pooling layer to reduce time steps (5ms → 10ms)
        x = tf.keras.layers.AveragePooling1D(pool_size=pool_size, name="pool_10ms")(input_layer)
        
        # Bidirectional GRU layers with increased capacity (128->256) and dropout
        gru1_input = x  # For residual connection
        
        x = tf.keras.layers.Bidirectional(
            tf.keras.layers.GRU(256, return_sequences=True),  # Increased from 128 to 256
            name="gru1"
        )(x)
        x = tf.keras.layers.Dropout(0.2)(x)  # Add dropout for regularization
        
        # Residual connection if shapes match (not applied in first layer due to pooling)
        
        x = tf.keras.layers.Bidirectional(
            tf.keras.layers.GRU(256),  # Increased from 128 to 256
            name="gru2"
        )(x)
        x = tf.keras.layers.Dropout(0.2)(x)  # Add dropout for regularization
        
        # Add self-attention mechanism with increased dimensions
        query = tf.keras.layers.Dense(512, name="attention_query")(x)  # Increased from 256 to 512
        key = tf.keras.layers.Dense(512, name="attention_key")(x)      # Increased from 256 to 512
        value = tf.keras.layers.Dense(512, name="attention_value")(x)  # Increased from 256 to 512
        
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
        
        # Three output heads for predicting previous, current, and next phoneme
        output_prev = tf.keras.layers.Dense(n_features, activation='softmax', name='out_prev2')(x)
        output_now = tf.keras.layers.Dense(n_features, activation='softmax', name='out_now2')(x)
        output_next = tf.keras.layers.Dense(n_features, activation='softmax', name='out_next2')(x)
        
        # Create model
        model = tf.keras.Model(inputs=input_layer, outputs=[output_prev, output_now, output_next])
    
    # Compile model with the same loss functions and metrics
    model.compile(
        optimizer='adam',  # Doesn't matter for prediction
        loss={
            'out_prev2': weighted_categorical_crossentropy(weight_values),
            'out_now2': weighted_categorical_crossentropy(weight_values),
            'out_next2': weighted_categorical_crossentropy(weight_values)
        },
        metrics={
            'out_prev2': 'categorical_accuracy',
            'out_now2': 'categorical_accuracy',
            'out_next2': 'categorical_accuracy'
        }
    )
    
    # Load the trained model weights - this is the key fix
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
    
    # Define output dimensions for the DataGeneratorTri - using batch size of 256
    batch_size = 256
    out_dim = (batch_size, time_window, n_features)
    
    # Create generator with the correct parameters
    print("Initializing data generator...")
    data_generator = DataGeneratorTri(
        filtered_indices, X, Y, 
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
            
            # Get true labels
            if isinstance(batch_y, list):
                true_batch = np.argmax(batch_y[1], axis=1)  # Use current phoneme
            else:
                true_batch = np.argmax(batch_y, axis=1)
                
            all_true_labels.append(true_batch)
            
            # Make predictions for this batch
            batch_preds = model.predict(batch_x, verbose=0)
            
            # Store batch predictions
            all_predictions_prev.append(batch_preds[0])
            all_predictions_now.append(batch_preds[1])
            all_predictions_next.append(batch_preds[2])
        
        # Combine all batches
        predictions_prev = np.vstack(all_predictions_prev)
        predictions_now = np.vstack(all_predictions_now)
        predictions_next = np.vstack(all_predictions_next)
        true_labels = np.concatenate(all_true_labels)
        
        print(f"Final shapes - Predictions: {predictions_now.shape}, True labels: {true_labels.shape}")
        
        # Save prediction probabilities
        base_name = os.path.basename(model_name)
        out_dir = save_dir if save_dir else '.'
        
        prev_file = os.path.join(out_dir, f"{base_name}_p_prev.npy")
        now_file = os.path.join(out_dir, f"{base_name}_p_now.npy")
        next_file = os.path.join(out_dir, f"{base_name}_p_next.npy")
        
        np.save(prev_file, predictions_prev)
        np.save(now_file, predictions_now)
        np.save(next_file, predictions_next)
        
        print(f"Saved prediction probabilities to:")
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
            flat_indices = np.argsort(conf_matrix_copy.flatten())[-5:]  # Top 5 confused pairs
            row_indices, col_indices = np.unravel_index(flat_indices, conf_matrix.shape)
            
            print("\nTop 5 class confusion pairs:")
            for i, j in zip(row_indices, col_indices):
                true_count = np.sum(Y_true == i)
                if true_count > 0:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times ({conf_matrix[i, j]/true_count*100:.2f}%)")
                else:
                    print(f"True class {i} predicted as {j}: {conf_matrix[i, j]} times (0.00%)")
            
            # Save confusion matrix
            conf_matrix_file = os.path.join(out_dir, f"{base_name}_confusion_matrix.npy")
            np.save(conf_matrix_file, conf_matrix)
            print(f"Saved confusion matrix to {conf_matrix_file}")
                    
        except Exception as e:
            print(f"Could not compute confusion matrix: {e}")
        
    except Exception as e:
        print(f"Error during prediction: {e}")
        import traceback
        traceback.print_exc()
        
    print("Prediction completed.")
    return
