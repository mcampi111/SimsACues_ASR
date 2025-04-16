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
# Import the balanced data generator for consistency with training
from DataGenTimitTriBalanced import BalancedDataGenerator

def predictPhonemeProbabilitiesCausalNN( filename_X = 'L_scaled.npy', filename_Y = 'Phonemes39consecutive.npy', model_name = 'srA1_k_1', data_split_factor = 0.9, output_dir=None):
    ''' data_split_factor = 0 to predict and store for all timesteps. set to 0.9 for evaluation of development set (and use X of train+dev set)
        see also srA1eval script for evaluation purposes '''
    
    # MARTA added directory creation
    save_dir =  output_dir if output_dir else os.path.dirname(model_name)
    os.makedirs(save_dir, exist_ok=True)
    
    X = np.load( filename_X )
    Y = np.load( filename_Y )
    
    # Determine max class ID from the data
    unique_classes = np.unique(Y).astype(int)
    max_class_id = max(unique_classes) if len(unique_classes) > 0 else 39
    num_classes = max_class_id + 1  # Classes from 0 to max_class_id
    print(f"Setting num_classes to {num_classes} based on max class ID {max_class_id}")
    
    idx = np.arange(len(X))   # predict all including first after phoneme boundary
    idx = idx.reshape(idx.shape[0],)
    
    num_timesteps = 50
    batch_size    = 1024
    num_features  = X.shape[1]
    dim           = ( batch_size, num_timesteps, num_features )
    
    data_split = int( data_split_factor * len(idx))
    idx_val   = idx[data_split:]
    
    # Use balanced data generator for consistency with training
    predict_generator = BalancedDataGenerator(
        idx_val, X, Y, 
        out_dim=dim, 
        reduce_factor=1, 
        shuffle=False,
        non_causal_steps=0
    )
    
    # MARTA modified model loading to handle paths
    model_path = model_name + '.h5'
    model = tf.keras.models.load_model(model_path)
    
    # MARTA commented deprecated generator methods and replaced with new ones
    #evaluation = model.evaluate_generator( predict_generator, verbose = 1 )
    evaluation = model.evaluate(predict_generator, verbose = 1)
    
    #p = model.predict_generator( predict_generator, verbose = 1 )
    p = model.predict(predict_generator, verbose = 1)
    
    idx_valed = np.array(idx_val)[np.array(range(len(p)))] + num_timesteps
    
    # MARTA MODIFIED HERE - Add bounds checking to prevent index out of bounds errors
    idx_valed = np.minimum(idx_valed, len(Y) - 1)
    
    # MARTA modified save paths to use results directory
    logp = np.log(p)
    np.save(os.path.join(save_dir, f'{os.path.basename(model_name)}_logp.npy'), logp)
    
    y_pred = np.argmax(p,axis=1)
    y_true = Y[idx_valed]
    pred_correct = sum( ( np.logical_or( y_pred[:-8] == y_true[:-8], y_pred[8:] == y_true[:-8]  ) ) ) / (len(y_pred)-8)
    
    # MARTA modified save paths
    np.save(os.path.join(save_dir, f'Phonemes39pred_{os.path.basename(model_name)}.npy'), y_pred)
    np.save(os.path.join(save_dir, 'Phonemes39true.npy'), y_true)
    
    print("Evaluation accuracy:", evaluation[1])
    print("Prediction accuracy:", pred_correct)

######### combine
    
def combineModelCausalNN( model_name_1 = 'srA1_k_1', model_name_2 = 'srA1_h_0', model_name_out = 'srA1', filename_X1 = 'L_scaled.npy',
                          filename_X2 = 'CC_scaled.npy', filename_Y = 'Phonemes39consecutive.npy', output_dir=None ):
    ''' combine models based on level and cepstral coefficients (or any two models) by adding their log probabilities '''
    
    # MARTA added directory handling
    save_dir = output_dir if output_dir else os.path.dirname(model_name_out)
    os.makedirs(save_dir, exist_ok=True)

    predictPhonemeProbabilitiesCausalNN( filename_X = filename_X1, filename_Y = filename_Y, model_name = model_name_1, data_split_factor = 0, output_dir=save_dir)
    # MARTA modified load paths
    logp_1  = np.load(os.path.join(save_dir, f'{os.path.basename(model_name_1)}_logp.npy'))
    
    predictPhonemeProbabilitiesCausalNN( filename_X = filename_X2, filename_Y = filename_Y, model_name = model_name_2, data_split_factor = 0, output_dir=save_dir)
    # MARTA modified load paths
    logp_2  = np.load(os.path.join(save_dir, f'{os.path.basename(model_name_2)}_logp.npy'))
    
    logp = logp_1 + logp_2
    # MARTA modified save paths
    np.save(os.path.join(save_dir, f'{os.path.basename(model_name_out)}_logp_combined_all.npy'), logp)
    np.save(os.path.join(save_dir, f'{os.path.basename(model_name_out)}_p_combined_all.npy'), np.exp(logp))
