# -*- coding: utf-8 -*-
"""
Modified srA2predict.py to handle custom loss function and fix evaluation/prediction
"""

import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix
import sklearn
import os
import sys

# Import the custom loss function from srA2.py
# This assumes srA2.py is in the same directory
try:
    from srA2 import weighted_categorical_crossentropy
    from DataGenTimitTri import DataGeneratorTri
except ImportError:
    # Define the function inline if import fails
    def weighted_categorical_crossentropy(weights):
        """Simplified weighted categorical crossentropy loss function."""
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
    
    # Load the trained model with custom loss function
    model_path = f"{model_name}.h5"
    print(f"Loading model from: {model_path}")
    
    try:
        # Load model with custom loss function
        with tf.keras.utils.custom_object_scope({
            'loss_fn': weighted_categorical_crossentropy(class_weight)
        }):
            model = tf.keras.models.load_model(model_path)
        print("Model loaded successfully")
    except Exception as e:
        print(f"Error loading model: {e}")
        print("This may be due to an issue with the custom loss function.")
        print("Please ensure the model was saved with the same custom loss function.")
        return
    
    # Create a DataGeneratorTri for proper shape handling
    num_timesteps = 305  # This should match what was used in training
    batch_size = 256     # Adjust based on available memory
    dim = (batch_size, num_timesteps, X.shape[1])
    
    # Generate indices for all samples
    idx = np.arange(len(X))
    
    print(f"Creating data generator with timesteps: {num_timesteps}")
    predict_generator = DataGeneratorTri(
        idx, X, Y, dim, 
        shuffle=False, 
        reduce_factor=1,
        non_causal_steps=int(num_timesteps/2)  # Same setting as in training
    )
    
    # Evaluate model performance using generator
    print(f"Evaluating model with generator length: {len(predict_generator)}")
    try:
        evaluation = model.evaluate(predict_generator, verbose=1)
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
        for i in range(len(predict_generator)):
            if i % 50 == 0:
                print(f"Processing batch {i}/{len(predict_generator)}")
                
            # Get data batch
            batch_x, batch_y = predict_generator[i]
            
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
        print(f"Traceback: {sys.exc_info()}")
        import traceback
        traceback.print_exc()
        
    print("Prediction completed.")
    return
