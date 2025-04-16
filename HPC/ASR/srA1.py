# -*- coding: utf-8 -*-
"""
Simplified srA1.py following the paper's architecture
"""

import numpy as np
import tensorflow as tf
import sklearn
import os
from DataGenTimit import DataGenerator
# Import the new balanced data generator
from DataGenTimitTriBalanced import BalancedDataGenerator

def trainCausalNN(filename_X='L_scaled.npy', filename_Y='Phonemes39consecutive.npy',
                 filename_idx='Phonemes39_position_index.npy', file_identifier_out='srA1_a',
                 epochs_to_save=1, epochs_total=100, batch_size=1024, reduce_factor=1, load_model=None):

    # Create output directory if needed
    save_dir = os.path.dirname(file_identifier_out)
    if save_dir:
        os.makedirs(save_dir, exist_ok=True)

    # Load data
    X = np.load(filename_X)
    Y = np.load(filename_Y)
    idx = np.load(filename_idx)
    
    # Determine max class ID from the data
    unique_classes = np.unique(Y).astype(int)
    max_class_id = max(unique_classes) if len(unique_classes) > 0 else 39
    num_classes = max_class_id + 1  # Classes from 0 to max_class_id
    print(f"Setting num_classes to {num_classes} based on max class ID {max_class_id}")
    
    # Disable class weights to avoid TensorFlow GatherV2 error with high-valued class IDs
    print("Disabling class weights - using balanced data generator for class balancing instead")
    class_weight_dict = None
    
    idx = idx.reshape(idx.shape[0],)
    
    # Model parameters
    num_features = X.shape[1]
    num_timesteps = 50
    dim = (batch_size, num_timesteps, num_features)
    
    # Split data
    data_split = int(0.9 * len(idx))
    idx_train = idx[:data_split]
    idx_val = idx[data_split:]
    
    # Define model - SIMPLIFIED as per paper
    inp = tf.keras.Input(shape=(num_timesteps, num_features))
    
    # Two GRU layers without heavy regularization
    x = tf.keras.layers.GRU(64, return_sequences=True)(inp)
    x = tf.keras.layers.GRU(64)(x)
    
    # Output layer - MODIFIED to support variable number of classes
    out = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
    
    model = tf.keras.Model(inputs=inp, outputs=out)
    
    # Compile model
    model.compile(
        loss='categorical_crossentropy',
        optimizer='adam',
        metrics=['categorical_accuracy']
    )
    
    # Load pre-existing model if specified
    if load_model is not None:
        if os.path.dirname(load_model):
            model = tf.keras.models.load_model(load_model)
        else:
            model = tf.keras.models.load_model(os.path.join(save_dir, load_model))
    
    # Create early stopping callback
    early_stopping = tf.keras.callbacks.EarlyStopping(
        monitor='val_categorical_accuracy',
        patience=5,
        restore_best_weights=True
    )
    
    # Create data generators
    # Comment out original data generator
    # training_generator = DataGenerator(idx_train, X, Y, dim, reduce_factor=reduce_factor)
    # validation_generator = DataGenerator(idx_val, X, Y, dim, reduce_factor=reduce_factor)
    
    # Use balanced data generator instead
    print("Using balanced batch sampling data generator")
    training_generator = BalancedDataGenerator(
        idx_train, X, Y,
        out_dim=dim,
        shuffle=True,
        reduce_factor=reduce_factor,
        non_causal_steps=0  # Causal model doesn't need non-causal steps
    )
    
    # For validation, we can still use balanced batches to properly evaluate per-class metrics
    validation_generator = BalancedDataGenerator(
        idx_val, X, Y,
        out_dim=dim,
        shuffle=False,  # No shuffling for validation
        reduce_factor=reduce_factor,
        non_causal_steps=0
    )
    
    # Train model
    for i in range(int(epochs_total / epochs_to_save)):
        model.fit(
            training_generator,
            validation_data=validation_generator,
            # class_weight parameter removed to avoid TensorFlow GatherV2 error
            epochs=epochs_to_save,
            callbacks=[early_stopping]
        )
        
        # Save model
        model_save_path = f"{file_identifier_out}_{i}.h5"
        model.save(model_save_path)
        print(f"Model saved to: {model_save_path}")
