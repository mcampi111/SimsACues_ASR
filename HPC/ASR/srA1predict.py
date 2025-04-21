# -*- coding: utf-8 -*-
"""
Created on Sat Jun 22 12:29:18 2019

@author: js2251
"""

import numpy as np
import tensorflow as tf
import sklearn
import os  # MARTA added for directory handling
from DataGenTimit import DataGenerator
from DataGenTimitTriBalanced import BalancedDataGenerator

def predictPhonemeProbabilitiesCausalNN(filename_X='L_scaled.npy', filename_Y='Phonemes39consecutive.npy', 
                                       model_name='srA1_k_1', data_split_factor=0.9, output_dir=None):
    ''' data_split_factor = 0 to predict and store for all timesteps. set to 0.9 for evaluation of development set (and use X of train+dev set)
        see also srA1eval script for evaluation purposes '''
    
    # MARTA added directory creation
    save_dir = output_dir if output_dir else os.path.dirname(model_name)
    os.makedirs(save_dir, exist_ok=True)
    
    X = np.load(filename_X)
    Y = np.load(filename_Y)
    
    # Print dimensions for debugging
    print(f"X shape: {X.shape}, Y shape: {Y.shape}")
    
    idx = np.arange(len(X))   # predict all including first after phoneme boundary
    idx = idx.reshape(idx.shape[0],)
    
    num_timesteps = 50
    batch_size = 1024
    num_features = X.shape[1]
    dim = (batch_size, num_timesteps, num_features)
    
    data_split = int(data_split_factor * len(idx))
    idx_val = idx[data_split:]
    
    # Use the standard DataGenerator
    predict_generator = DataGenerator(idx_val, X, Y, dim, reduce_factor=1, shuffle=False)
    
    # MARTA modified model loading to handle paths
    model_path = model_name + '.h5'
    model = tf.keras.models.load_model(model_path)
    
    # Evaluate and predict
    evaluation = model.evaluate(predict_generator, verbose=1)
    p = model.predict(predict_generator, verbose=1)
    
    # Get indices and add timesteps
    idx_valed = np.array(idx_val)[np.array(range(len(p)))] + num_timesteps
    
    # CRITICAL FIX: Use Y length for bounds checking
    idx_valed = np.minimum(idx_valed, len(Y) - 1)
    
    # Add small epsilon to avoid log(0)
    logp = np.log(p + 1e-10)
    np.save(os.path.join(save_dir, f'{os.path.basename(model_name)}_logp.npy'), logp)
    
    y_pred = np.argmax(p, axis=1)
    y_true = Y[idx_valed]
    
    # Calculate accuracy if we have enough predictions
    if len(y_pred) > 8:
        pred_correct = sum((np.logical_or(y_pred[:-8] == y_true[:-8], y_pred[8:] == y_true[:-8]))) / (len(y_pred)-8)
        print("Prediction accuracy:", pred_correct)
    
    # Save predictions
    np.save(os.path.join(save_dir, f'Phonemes39pred_{os.path.basename(model_name)}.npy'), y_pred)
    np.save(os.path.join(save_dir, 'Phonemes39true.npy'), y_true)
    
    print("Evaluation accuracy:", evaluation[1] if isinstance(evaluation, list) else 0)
    return p, logp

def combineModelCausalNN(model_name_1='srA1_k_1', model_name_2='srA1_h_0', model_name_out='srA1', 
                        filename_X1='L_scaled.npy', filename_X2='CC_scaled.npy', 
                        filename_Y='Phonemes39consecutive.npy', output_dir=None):
    ''' combine models based on level and cepstral coefficients (or any two models) by adding their log probabilities '''
    
    # MARTA added directory handling
    save_dir = output_dir if output_dir else os.path.dirname(model_name_out)
    os.makedirs(save_dir, exist_ok=True)

    try:
        # Process first model
        print(f"\n=== Processing first model: {model_name_1} ===")
        predictPhonemeProbabilitiesCausalNN(
            filename_X=filename_X1, 
            filename_Y=filename_Y, 
            model_name=model_name_1, 
            data_split_factor=0, 
            output_dir=save_dir
        )
        
        # Load first model predictions
        logp_1_path = os.path.join(save_dir, f'{os.path.basename(model_name_1)}_logp.npy')
        print(f"Loading first model predictions from: {logp_1_path}")
        logp_1 = np.load(logp_1_path)
        print(f"First model predictions shape: {logp_1.shape}")
        
        # Process second model
        print(f"\n=== Processing second model: {model_name_2} ===")
        predictPhonemeProbabilitiesCausalNN(
            filename_X=filename_X2, 
            filename_Y=filename_Y, 
            model_name=model_name_2, 
            data_split_factor=0, 
            output_dir=save_dir
        )
        
        # Load second model predictions
        logp_2_path = os.path.join(save_dir, f'{os.path.basename(model_name_2)}_logp.npy')
        print(f"Loading second model predictions from: {logp_2_path}")
        logp_2 = np.load(logp_2_path)
        print(f"Second model predictions shape: {logp_2.shape}")
        
        # CRITICAL FIX: Ensure arrays have the same shape before combining
        print("\n=== Combining model predictions ===")
        if logp_1.shape[0] != logp_2.shape[0]:
            print(f"WARNING: Arrays have different shapes: {logp_1.shape} vs {logp_2.shape}")
            min_len = min(len(logp_1), len(logp_2))
            logp_1 = logp_1[:min_len]
            logp_2 = logp_2[:min_len]
            print(f"Trimmed to common length: {min_len}")
        
        # Combine and save
        logp = logp_1 + logp_2
        print(f"Combined shape: {logp.shape}")
        
        np.save(os.path.join(save_dir, f'{os.path.basename(model_name_out)}_logp_combined_all.npy'), logp)
        np.save(os.path.join(save_dir, f'{os.path.basename(model_name_out)}_p_combined_all.npy'), np.exp(logp))
        
        print(f"Successfully combined models {model_name_1} and {model_name_2}")
        return True
    except Exception as e:
        print(f"Error in model combination: {type(e).__name__}, {str(e)}")
        import traceback
        traceback.print_exc()
        return False
