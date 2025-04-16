# -*- coding: utf-8 -*-
"""
Simplified srA2.py following the paper's architecture
"""

import numpy as np
import tensorflow as tf
import sklearn
import os
from DataGenTimitTri import DataGeneratorTri

def weighted_categorical_crossentropy(weights):
    """Simplified weighted categorical crossentropy."""
    weights = tf.constant(weights, dtype=tf.float32)

    def loss_fn(y_true, y_pred):
        # Calculate sample weights
        sample_weights = tf.reduce_sum(y_true * tf.reshape(weights, [1, -1]), axis=-1)
        
        # Standard categorical cross entropy
        ce_loss = tf.keras.losses.categorical_crossentropy(y_true, y_pred)
        
        # Apply weights
        return tf.reduce_mean(ce_loss * sample_weights)
    
    return loss_fn

def trainNonCausalNN(filename_X='srA1_logp_combined_all.npy', 
                    filename_Y='Phonemes39consecutive.npy', 
                    file_identifier_out='srA2_a', 
                    epochs_to_save=1, 
                    epochs_total=100, 
                    batch_size=1024, 
                    reduce_factor=1, 
                    load_model=None,
                    validation_positions_path=None):
    
    # Create output directory if needed
    save_dir = os.path.dirname(file_identifier_out)
    if save_dir:
        os.makedirs(save_dir, exist_ok=True)
    
    # Load data
    print(f"Loading data from {filename_X} and {filename_Y}")
    X = np.load(filename_X)
    Y = np.load(filename_Y)
    Y = Y[50:]  # 50 timesteps in first causal NN
    
    print(f"X shape: {X.shape}, Y shape: {Y.shape}")
    
    # Compute class weights
    class_weight = sklearn.utils.class_weight.compute_class_weight(
        class_weight='balanced',
        classes=np.unique(Y),
        y=Y
    )
    
    # Model parameters
    num_features = X.shape[1]
    num_timesteps = 305  # Increased context window
    dim = (batch_size, num_timesteps, num_features)
    
    # Split data
    if validation_positions_path and os.path.exists(validation_positions_path):
        print(f"Using pre-computed validation positions from {validation_positions_path}")
        balanced_positions_path = os.path.join(os.path.dirname(validation_positions_path), "balanced_positions.npy")
        
        if os.path.exists(balanced_positions_path):
            idx_train = np.load(balanced_positions_path).flatten()
            idx_val = np.load(validation_positions_path).flatten()
        else:
            idx = np.arange(len(X))
            data_split = int(0.9 * len(idx))
            idx_train = idx[:data_split]
            idx_val = idx[data_split:]
    else:
        idx = np.arange(len(X))
        data_split = int(0.9 * len(idx))
        idx_train = idx[:data_split]
        idx_val = idx[data_split:]
    
    print(f"Data split: {len(idx_train)} training samples, {len(idx_val)} validation samples")
    
    # Define simplified model architecture
    inp = tf.keras.Input(shape=(num_timesteps, num_features), name="input")
    
    # Apply pooling to reduce sequence length
    x = tf.keras.layers.AveragePooling1D(pool_size=5, name="pool_10ms")(inp)
    
    # Bidirectional GRU layers WITHOUT excessive regularization
    x = tf.keras.layers.Bidirectional(
        tf.keras.layers.GRU(128, return_sequences=True),
        name="gru1"
    )(x)
    
    x = tf.keras.layers.Bidirectional(
        tf.keras.layers.GRU(128),
        name="gru2"
    )(x)
    
    # Output layers
    out1 = tf.keras.layers.Dense(40, activation='softmax', name="out_prev2")(x)
    out2 = tf.keras.layers.Dense(40, activation='softmax', name="out_now2")(x)
    out3 = tf.keras.layers.Dense(40, activation='softmax', name="out_next2")(x)
    
    model = tf.keras.Model(inputs=inp, outputs=[out1, out2, out3])
    
    # Print model summary
    model.summary()
    
    # Load pre-existing model if specified
    if load_model is not None:
        print(f"Loading pre-existing model from {load_model}")
        model_path = os.path.join(save_dir, load_model) if not os.path.dirname(load_model) else load_model
        
        with tf.keras.utils.custom_object_scope({
            'loss_fn': weighted_categorical_crossentropy(class_weight)
        }):
            try:
                model = tf.keras.models.load_model(model_path)
                print("Model loaded successfully")
            except Exception as e:
                print(f"Error loading model: {e}")
                print("Continuing with freshly initialized model")
    
    # Define loss functions
    losses = {
        'out_prev2': weighted_categorical_crossentropy(class_weight),
        'out_now2': weighted_categorical_crossentropy(class_weight),
        'out_next2': weighted_categorical_crossentropy(class_weight)
    }
    
    # Add metrics
    metrics = {
        'out_prev2': ['categorical_accuracy'],
        'out_now2': ['categorical_accuracy'],
        'out_next2': ['categorical_accuracy']
    }
    
    # Use a moderate learning rate
    optimizer = tf.keras.optimizers.Adam(learning_rate=0.001)
    
    # Compile model
    model.compile(
        loss=losses,
        optimizer=optimizer,
        metrics=metrics
    )
    
    # Create data generators
    print("Creating data generators...")
    
    training_generator = DataGeneratorTri(
        idx_train, X, Y, dim, 
        reduce_factor=reduce_factor, 
        non_causal_steps=int(num_timesteps/2),
        shuffle=True
    )
    
    validation_generator = DataGeneratorTri(
        idx_val, X, Y, dim, 
        reduce_factor=reduce_factor, 
        non_causal_steps=int(num_timesteps/2),
        shuffle=False
    )
    
    # Add callbacks
    callbacks = []
    
    # Early stopping
    early_stopping = tf.keras.callbacks.EarlyStopping(
        monitor='val_out_now2_categorical_accuracy',
        patience=5,
        restore_best_weights=True,
        verbose=1
    )
    callbacks.append(early_stopping)
    
    # Learning rate scheduler
    lr_scheduler = tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_out_now2_categorical_accuracy',
        factor=0.5,
        patience=3,
        min_lr=0.0001,
        verbose=1
    )
    callbacks.append(lr_scheduler)
    
    # Train model
    for i in range(int(epochs_total / epochs_to_save)):
        print(f"\nTraining epoch {i+1}/{int(epochs_total / epochs_to_save)}")
        
        model.fit(
            training_generator,
            validation_data=validation_generator,
            epochs=epochs_to_save,
            callbacks=callbacks,
            verbose=1
        )
        
        # Save model
        model_save_path = f"{file_identifier_out}_{i}.h5"
        model.save(model_save_path)
        print(f"Model saved to: {model_save_path}")
        
    return model
