import numpy as np
import tensorflow as tf
import os
from DataGenTimitTri import DataGeneratorTri
import time

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

def trainNonCausalNN(filename_X, filename_Y, file_identifier_out, 
                    epochs_to_save=1, epochs_total=60, batch_size=1024, 
                    load_model=None, validation_positions_path=None,
                    reduce_factor=1, validation_split=0.2, patience=5):
    """
    Train the non-causal neural network (bidirectional GRU with attention)
    
    Parameters:
    -----------
    filename_X : str
        Path to the input features (neurogram or causal predictions)
    filename_Y : str
        Path to the phoneme labels
    file_identifier_out : str
        Prefix for saving model files
    epochs_to_save : int
        How often to save the model
    epochs_total : int
        Total number of epochs to train
    batch_size : int
        Batch size for training
    load_model : str
        Path to pre-trained model to continue training
    validation_positions_path : str
        Path to pre-computed validation positions
    reduce_factor : int
        Reduction factor for dataset size
    validation_split : float
        Fraction of data to use for validation
    patience : int
        Patience for early stopping
    """
    print(f"Loading data from {filename_X} and {filename_Y}")
    
    # Load data
    X = np.load(filename_X)
    y = np.load(filename_Y)
    
    print(f"X shape: {X.shape}, Y shape: {y.shape}")
    
    # Parameters for the model
    time_window = 305  # 50ms context on each side
    non_causal_steps = time_window // 2
    n_features = 40  # Number of phoneme probabilities from srA1
    pool_size = 5  # For 10ms frames
    
    # Split data into training and validation
    if validation_positions_path is not None and os.path.exists(validation_positions_path):
        print(f"Using pre-computed validation positions from {validation_positions_path}")
        val_positions = np.load(validation_positions_path)
        # Generate training positions (all positions not in validation set)
        all_positions = np.arange(len(y))
        train_positions = np.setdiff1d(all_positions, val_positions)
        
        # Take a subset of the training data if reduce_factor > 1
        if reduce_factor > 1:
            train_positions = train_positions[::reduce_factor]
    else:
        # Split positions randomly if no validation file provided
        indices = np.arange(len(y))
        np.random.shuffle(indices)
        split = int(len(indices) * (1 - validation_split))
        train_positions = indices[:split]
        val_positions = indices[split:]
        
        # Take a subset of the training data if reduce_factor > 1
        if reduce_factor > 1:
            train_positions = train_positions[::reduce_factor]
    
    print(f"Data split: {len(train_positions)} training samples, {len(val_positions)} validation samples")
    
    # Build the model
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
    
    # Print model summary
    model.summary()
    
    # If loading a pre-existing model
    if load_model is not None:
        print(f"Loading pre-existing model from {load_model}")
        try:
            model.load_weights(load_model)
            print("Model loaded successfully")
        except:
            print("Error loading model weights, starting from scratch")
    
    # Calculate class weights for the loss function
    unique_classes = np.unique(y)
    class_weights = {}
    for cl in unique_classes:
        class_weights[cl] = 1.0 / (np.sum(y == cl) / len(y))
    
    # Normalize weights
    weight_values = list(class_weights.values())
    weight_values = np.array(weight_values) / np.mean(weight_values)
    
    # Define initial learning rate (fixed value instead of schedule)
    initial_learning_rate = 0.001
    
    # Compile model with optimizer, loss functions, and metrics
    optimizer = tf.keras.optimizers.legacy.Adam(learning_rate=initial_learning_rate)
    
    model.compile(
        optimizer=optimizer,
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
    
    # Callbacks
    callbacks = [
        # Save model checkpoint after each specified number of epochs
        tf.keras.callbacks.ModelCheckpoint(
            filepath=file_identifier_out + '_{epoch}.h5',
            save_weights_only=True,
            save_freq='epoch',
            period=epochs_to_save
        ),
        # Learning rate scheduler (simpler implementation that won't cause type errors)
        tf.keras.callbacks.LearningRateScheduler(
            lambda epoch, lr: lr * 0.75 if epoch > 0 and epoch % 3 == 0 else lr,
            verbose=1
        ),
        # Early stopping
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=patience,
            restore_best_weights=True,
            verbose=1
        )
    ]
    
    # Create data generators
    print("Creating data generators...")
    
    # Define output dimensions for the DataGeneratorTri
    out_dim = (batch_size, time_window, n_features)
    
    # Create generators with the correct parameters
    train_generator = DataGeneratorTri(
        train_positions, X, y, 
        out_dim=out_dim,
        shuffle=True,
        reduce_factor=1,
        non_causal_steps=non_causal_steps
    )
    
    val_generator = DataGeneratorTri(
        val_positions, X, y, 
        out_dim=out_dim,
        shuffle=False,
        reduce_factor=1,
        non_causal_steps=non_causal_steps
    )
    
    # Train the model
    for epoch in range(1, epochs_total + 1):
        print(f"\nTraining epoch {epoch}/{epochs_total}")
        
        # Fit the model for one epoch
        history = model.fit(
            train_generator,
            validation_data=val_generator,
            epochs=1,
            callbacks=callbacks,
            verbose=1
        )
        
        # Save the model after each specified number of epochs
        if epoch % epochs_to_save == 0:
            model.save_weights(f"{file_identifier_out}_{epoch-1}.h5")
            print(f"Model saved to: {file_identifier_out}_{epoch-1}.h5")
            
    return model
