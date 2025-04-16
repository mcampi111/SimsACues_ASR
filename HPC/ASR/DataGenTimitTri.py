# -*- coding: utf-8 -*-
"""
Modified DataGenTimitTri.py to handle edge cases and improve error handling
"""

import numpy as np
import tensorflow as tf

def add_cognitive_noise(neurogram, snr_db=10):
    """Add pink noise to neurogram at specified SNR level"""
    # Calculate signal power
    signal_power = np.mean(neurogram ** 2)
    
    # Generate pink noise
    noise = np.random.normal(0, 1, neurogram.shape)
    # Simple approximation of pink noise frequency characteristics
    noise = np.cumsum(noise, axis=0) * 0.02
    noise = noise - np.mean(noise, axis=0)
    
    # Scale noise to achieve target SNR
    noise_power = np.mean(noise ** 2)
    if noise_power > 0:
        scaling_factor = np.sqrt(signal_power / (noise_power * 10**(snr_db/10)))
        noise = noise * scaling_factor
    
    # Add noise to neurogram
    noisy_neurogram = neurogram + noise
    return noisy_neurogram

# Helper functions for previous and next labels
def getPreviousLabel(labels, window_size=100):
    """Get previous phoneme labels with a sliding window"""
    prev_labels = np.roll(labels, 1)
    # Handle boundary condition for first element
    prev_labels[0] = labels[0]  # Set first element's previous to itself
    return prev_labels

def getNextLabel(labels, window_size=100):
    """Get next phoneme labels with a sliding window"""
    next_labels = np.roll(labels, -1)
    # Handle boundary condition for last element
    next_labels[-1] = labels[-1]  # Set last element's next to itself
    return next_labels

class DataGenerator(tf.keras.utils.Sequence):
    """
    Base data generator for TIMIT dataset.
    Generates batches of data for a causal model.
    """
    def __init__(self, idx, X, Y, out_dim=(64, 128, 2, 192), shuffle=True, reduce_factor=1, non_causal_steps=0):
        self.X = X
        self.Y = Y
        self.out_dim = out_dim
        self.batch_size = out_dim[0]
        self.time_dim = tuple(out_dim[1:-1])
        self.out_dim_nobatch = tuple(out_dim[1:])
        self.num_time_steps = 1
        for i in range(1, len(out_dim)-1):
            self.num_time_steps *= out_dim[i]
        
        # Fixed number of phoneme classes (40)
        self.num_classes = 40
        
        self.shuffle = shuffle
        
        # Filter indices that are valid (have enough context)
        valid_indices = idx >= self.num_time_steps
        self.idx = idx[valid_indices]
        
        if len(self.idx) < len(idx):
            print(f"Filtered out {len(idx) - len(self.idx)} indices that didn't have enough context")
        
        self.non_causal_steps = non_causal_steps
        self.reduce_factor = reduce_factor
        self.on_epoch_end()
        
        # Print some debug info
        print(f"Data Generator initialized with: batch_size={self.batch_size}, time_steps={self.num_time_steps}, "
              f"features={out_dim[-1]}, non_causal_steps={non_causal_steps}")
    
    def __len__(self):
        """Number of batches per epoch"""
        return max(1, int(np.floor(len(self.idx) / self.batch_size / self.reduce_factor)))
    
    def __getitem__(self, index):
        """Generate one batch of data"""
        # Handle index out of bounds
        if index >= self.__len__():
            raise IndexError(f"Index {index} out of bounds for generator with length {self.__len__()}")
            
        # Generate indexes of the batch
        start_idx = index * self.batch_size
        end_idx = min((index + 1) * self.batch_size, len(self.idx))
        
        indexes = self.indexes[start_idx:end_idx]
        
        # Find list of IDs
        list_idx_temp = [self.idx[k] for k in indexes]
        
        # Generate data
        X, Y = self.__data_generation(list_idx_temp)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
            
        # Debug info for first batch to verify shape
        if index == 0:
            print(f"Generated batch X shape: {X.shape}, Y shape: {Y.shape if not isinstance(Y, list) else [y.shape for y in Y]}")
        
        return X, Y
    
    def on_epoch_end(self):
        """Updates indexes after each epoch"""
        self.indexes = np.arange(len(self.idx))
        if self.shuffle:
            np.random.shuffle(self.indexes)
    
    def __data_generation(self, list_idx_temp):
        """Generates data containing batch_size samples"""
        # Adjust batch size if necessary for last batch
        actual_batch_size = len(list_idx_temp)
        
        # Initialize arrays
        X = np.empty((actual_batch_size,) + self.out_dim_nobatch)
        Y = np.empty((actual_batch_size), dtype=int)
        
        # Generate data
        for i, ID in enumerate(list_idx_temp):
            # Get input context window
            start_idx = max(0, ID - self.num_time_steps + 1)
            end_idx = min(ID + 1, len(self.X))
            
            # Handle edge cases with padding if necessary
            if end_idx - start_idx < self.num_time_steps:
                # Need to pad
                context = np.zeros(self.out_dim_nobatch)
                actual_context = self.X[start_idx:end_idx]
                
                # Safely reshape context to match expected dimensions
                try:
                    context[-len(actual_context):] = actual_context.reshape(-1, self.out_dim_nobatch[-1])[-len(actual_context):]
                except ValueError:
                    # Fallback method if reshape fails
                    flat_context = context.reshape(-1)
                    flat_actual = actual_context.reshape(-1)
                    copy_len = min(len(flat_context), len(flat_actual))
                    flat_context[:copy_len] = flat_actual[:copy_len]
                
                X[i,] = context
            else:
                # Normal case
                try:
                    X[i,] = self.X[start_idx:end_idx].reshape(self.out_dim_nobatch)
                except ValueError as e:
                    # Better error handling with detailed information
                    print(f"Reshape error in data generation: {e}")
                    print(f"Trying to reshape array of shape {self.X[start_idx:end_idx].shape} to {self.out_dim_nobatch}")
                    
                    # Use zero padding as fallback
                    context = np.zeros(self.out_dim_nobatch)
                    actual_context = self.X[start_idx:end_idx]
                    # Try flattening and copying what we can
                    flat_context = context.reshape(-1)
                    flat_actual = actual_context.reshape(-1)
                    copy_len = min(len(flat_context), len(flat_actual))
                    flat_context[:copy_len] = flat_actual[:copy_len]
                    X[i,] = context
            
            # Get target label
            target_idx = min(ID - self.non_causal_steps, len(self.Y) - 1)
            target_idx = max(0, target_idx)  # Ensure index is not negative
            
            # Additional check to ensure target_idx is valid
            if target_idx < len(self.Y):
                Y[i] = self.Y[target_idx]
            else:
                print(f"Warning: target_idx {target_idx} out of bounds for Y of length {len(self.Y)}")
                Y[i] = 0  # Default to first class as fallback
        
        # Convert to one-hot encoded categorical
        Y_categorical = tf.keras.utils.to_categorical(Y, num_classes=self.num_classes, dtype='float32')
        
        return X, Y_categorical


class DataGeneratorTri(DataGenerator):
    """
    Extended data generator for tri-phoneme prediction.
    Generates batches with previous, current, and next phoneme labels.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Pre-compute previous and next labels
        self.Y_prev = getPreviousLabel(self.Y, 100)
        self.Y_next = getNextLabel(self.Y, 100)
        
        # Print debug info
        print(f"DataGeneratorTri initialized with {len(self.idx)} valid indices")
    
    def __getitem__(self, index):
        """Generate one batch of data with three targets"""
        if index >= self.__len__():
            raise IndexError(f"Index {index} out of bounds for generator with length {self.__len__()}")
            
        start_idx = index * self.batch_size
        end_idx = min((index + 1) * self.batch_size, len(self.idx))
        
        indexes = self.indexes[start_idx:end_idx]
        list_idx_temp = [self.idx[k] for k in indexes]
        
        X, [Y1, Y2, Y3] = self.__data_generation(list_idx_temp)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
        
        # Debug info only for first batch to avoid log spam
        if index == 0:
            print(f"Generated batch X shape: {X.shape}, Y1 shape: {Y1.shape}, Y2 shape: {Y2.shape}, Y3 shape: {Y3.shape}")
        
        return X, [Y1, Y2, Y3]
    
    def __data_generation(self, list_idx_temp):
        """Generates data with three targets: previous, current, and next phoneme"""
        # Adjust batch size if necessary for last batch
        actual_batch_size = len(list_idx_temp)
        
        # Initialize arrays
        X = np.empty((actual_batch_size,) + self.out_dim_nobatch)
        Y_now = np.empty((actual_batch_size), dtype=int)
        Y_prev = np.empty((actual_batch_size), dtype=int)
        Y_next = np.empty((actual_batch_size), dtype=int)
        
        # Generate data
        for i, ID in enumerate(list_idx_temp):
            # Get input context window
            start_idx = max(0, ID - self.num_time_steps + 1)
            end_idx = min(ID + 1, len(self.X))
            
            # Handle edge cases with padding if necessary
            if end_idx - start_idx < self.num_time_steps:
                # Need to pad
                context = np.zeros(self.out_dim_nobatch)
                actual_context = self.X[start_idx:end_idx]
                
                # Safely reshape context to match expected dimensions
                try:
                    context[-len(actual_context):] = actual_context.reshape(-1, self.out_dim_nobatch[-1])[-len(actual_context):]
                except ValueError:
                    # Fallback method if reshape fails
                    flat_context = context.reshape(-1)
                    flat_actual = actual_context.reshape(-1)
                    copy_len = min(len(flat_context), len(flat_actual))
                    flat_context[:copy_len] = flat_actual[:copy_len]
                
                X[i,] = context
            else:
                # Normal case
                try:
                    X[i,] = self.X[start_idx:end_idx].reshape(self.out_dim_nobatch)
                except ValueError as e:
                    # Better error handling with detailed information
                    print(f"Reshape error in data generation: {e}")
                    print(f"Trying to reshape array of shape {self.X[start_idx:end_idx].shape} to {self.out_dim_nobatch}")
                    
                    # Use zero padding as fallback
                    context = np.zeros(self.out_dim_nobatch)
                    actual_context = self.X[start_idx:end_idx]
                    # Try flattening and copying what we can
                    flat_context = context.reshape(-1)
                    flat_actual = actual_context.reshape(-1)
                    copy_len = min(len(flat_context), len(flat_actual))
                    flat_context[:copy_len] = flat_actual[:copy_len]
                    X[i,] = context
            
            # Get target indices with bounds checking
            target_idx = min(ID - self.non_causal_steps, len(self.Y) - 1)
            target_idx = max(0, target_idx)  # Ensure index is not negative
            
            if target_idx < len(self.Y):
                Y_now[i] = self.Y[target_idx]
                Y_prev[i] = self.Y_prev[target_idx]
                Y_next[i] = self.Y_next[target_idx]
            else:
                print(f"Warning: target_idx {target_idx} out of bounds for Y of length {len(self.Y)}")
                Y_now[i] = 0  # Default to first class as fallback
                Y_prev[i] = 0
                Y_next[i] = 0
        
        # Convert to one-hot encoded categorical
        Y_prev_cat = tf.keras.utils.to_categorical(Y_prev, num_classes=self.num_classes)
        Y_now_cat = tf.keras.utils.to_categorical(Y_now, num_classes=self.num_classes)
        Y_next_cat = tf.keras.utils.to_categorical(Y_next, num_classes=self.num_classes)
        
        return X, [Y_prev_cat, Y_now_cat, Y_next_cat]


class PredictGenerator(DataGenerator):
    """
    Modified generator for prediction only (no shuffling between epochs)
    """
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def on_epoch_end(self):
        """Override to prevent shuffling during prediction"""
        pass
