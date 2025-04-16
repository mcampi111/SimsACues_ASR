import numpy as np
import tensorflow as tf
import os
from DataGenTimitTri import DataGeneratorTri
# Import the new balanced hierarchical data generator
from DataGenTimitTriBalanced import BalancedHierarchicalDataGenerator
import time

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

def weighted_categorical_crossentropy(weights):
    """Weighted categorical crossentropy loss function (original implementation kept for reference)."""
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
                    balanced_positions_path=None,  # NEW parameter for balanced positions
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
    balanced_positions_path : str
        Path to balanced position indices (NEW)
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
    
    # Get validation positions
    if validation_positions_path is not None and os.path.exists(validation_positions_path):
        print(f"Using pre-computed validation positions from {validation_positions_path}")
        val_positions = np.load(validation_positions_path)
    else:
        # Split positions randomly if no validation file provided
        indices = np.arange(len(y))
        np.random.shuffle(indices)
        split = int(len(indices) * (1 - validation_split))
        val_positions = indices[split:]
        
    # NEW: Use balanced positions if provided
    if balanced_positions_path is not None and os.path.exists(balanced_positions_path):
        print(f"Using balanced positions from {balanced_positions_path}")
        train_positions = np.load(balanced_positions_path)
        # Take a subset of the training data if reduce_factor > 1
        if reduce_factor > 1:
            train_positions = train_positions[::reduce_factor]
        print(f"Using {len(train_positions)} balanced training positions")
    else:
        # Generate training positions (all positions not in validation set)
        all_positions = np.arange(len(y))
        train_positions = np.setdiff1d(all_positions, val_positions)
        
        # Take a subset of the training data if reduce_factor > 1
        if reduce_factor > 1:
            train_positions = train_positions[::reduce_factor]
    
    print(f"Data split: {len(train_positions)} training samples, {len(val_positions)} validation samples")
    
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
        
        # New: Add phoneme category classifier first (hierarchical approach)
        # Group the 40 phoneme classes into fewer categories (e.g., vowels, stops, fricatives, etc.)
        num_phoneme_groups = 5  # Example: 5 major phoneme categories
        phoneme_group = tf.keras.layers.Dense(num_phoneme_groups, activation='softmax', name='phoneme_group')(x)
        
        # Create a feature representation enriched with phoneme group information
        x_with_group = tf.keras.layers.Concatenate()([x, phoneme_group])
        
        # Three output heads for predicting previous, current, and next phoneme
        output_prev = tf.keras.layers.Dense(n_features, activation='softmax', name='out_prev2')(x_with_group)
        output_now = tf.keras.layers.Dense(n_features, activation='softmax', name='out_now2')(x_with_group)
        output_next = tf.keras.layers.Dense(n_features, activation='softmax', name='out_next2')(x_with_group)
        
        # Create model
        model = tf.keras.Model(inputs=input_layer, outputs=[phoneme_group, output_prev, output_now, output_next])
    
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
    
    # Calculate class frequencies and weights for focal loss
    class_frequencies = np.bincount(y.astype(np.int32), minlength=n_features)
    total_samples = len(y)
    
    # Extremely aggressive alpha to compensate for the 99%/1% imbalance
    alpha = np.ones(n_features)
    for i in range(len(class_frequencies)):
        if i < len(alpha) and class_frequencies[i] > 0:
            # Inverse frequency with heavy smoothing
            alpha[i] = (1 - (class_frequencies[i] / total_samples)) ** 0.5
    
    # Normalize alpha
    alpha = alpha / np.mean(alpha)
    
    print("Class frequencies:", class_frequencies)
    print("Alpha weights for focal loss:", alpha)
    
    # Define initial learning rate
    initial_learning_rate = 0.001
    
    # Compile model with optimizer, focal loss functions, and metrics
    optimizer = tf.keras.optimizers.legacy.Adam(learning_rate=initial_learning_rate)
    
    # Define phoneme group weights - assume uniform weighting
    group_weights = np.ones(num_phoneme_groups) / num_phoneme_groups
    
    model.compile(
        optimizer=optimizer,
        loss={
            'phoneme_group': 'categorical_crossentropy',  # For phoneme group
            'out_prev2': focal_loss(gamma=2.0, alpha=alpha),
            'out_now2': focal_loss(gamma=2.0, alpha=alpha),
            'out_next2': focal_loss(gamma=2.0, alpha=alpha)
        },
        loss_weights={
            'phoneme_group': 0.2,  # Lower weight for group classification
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
    
    # Create custom y_group for phoneme groups (simplified mapping example)
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
    y_groups = create_phoneme_groups(y)
    
    # Create generators with the correct parameters
    # Comment out original hierarchical data generator
    """
    class HierarchicalDataGenerator(DataGeneratorTri):
        def **init**(self, idx, X, Y, Y_groups, out_dim=(64, 128, 2, 192), shuffle=True, reduce_factor=1, non_causal_steps=0):
            super().__init__(idx, X, Y, out_dim, shuffle, reduce_factor, non_causal_steps)
            self.Y_groups = Y_groups
            
        def **getitem**(self, index):
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
    """
    
    # Use balanced hierarchical data generator instead
    print("Using balanced batch sampling with hierarchical data generator")
    
    # Create generators with balanced batching
    # FIX: Remove the out_dim positional argument and keep only the keyword argument
    train_generator = BalancedHierarchicalDataGenerator(
        train_positions, X, y, 
        shuffle=True,
        reduce_factor=1,
        non_causal_steps=non_causal_steps,
        out_dim=out_dim,
        Y_tri=None,
        Y_weights=None,
        num_groups=num_phoneme_groups
    )
    
    val_generator = BalancedHierarchicalDataGenerator(
        val_positions, X, y, 
        shuffle=False,
        reduce_factor=1,
        non_causal_steps=non_causal_steps,
        out_dim=out_dim,
        Y_tri=None,
        Y_weights=None,
        num_groups=num_phoneme_groups
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
