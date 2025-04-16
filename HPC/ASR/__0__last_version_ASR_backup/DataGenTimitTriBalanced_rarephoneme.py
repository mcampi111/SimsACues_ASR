"""
DataGenTimitTriBalanced.py - Enhanced data generator for TIMIT dataset with balanced batch sampling

This version has improved efficiency and detailed progress reporting to help diagnose performance issues.
It fixes the issue with float class indices and numpy arrays as dictionary keys.
It improves handling of rare phoneme classes by increasing their representation in batches.
"""

import numpy as np
import tensorflow as tf
import time
from collections import defaultdict
import sys

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

class BalancedDataGenerator(tf.keras.utils.Sequence):
    """
    Generate data with balanced class distribution for TIMIT dataset.
    Ensures every batch contains examples from all classes (or as many as possible).
    """
    def __init__(self, idx, X, Y, out_dim=(64,128,2,192), shuffle=True, reduce_factor=1, non_causal_steps=0):
        """
        Initialize the balanced data generator
        
        Args:
            idx: array of indices to use
            X: input data
            Y: target phoneme labels
            out_dim: output dimensions (batch_size, time_steps, features)
            shuffle: whether to shuffle data between epochs
            reduce_factor: factor to reduce dataset size
            non_causal_steps: number of steps to look ahead (0 for causal model)
        """
        print("Initializing BalancedDataGenerator...")
        self.X = X
        self.Y = Y
        self.out_dim = out_dim
        self.batch_size = out_dim[0]
        self.time_dim = tuple(out_dim[1:-1])
        self.out_dim_nobatch = tuple(out_dim[1:])
        self.num_time_steps = 1
        for i in range(1, len(out_dim)-1):
            self.num_time_steps *= out_dim[i]
            
        self.num_classes = 40  # Fixed number of phoneme classes
        self.shuffle = shuffle
        
        # Convert idx to numpy array and ensure it's 1D
        if isinstance(idx, np.ndarray):
            idx = idx.flatten()
        else:
            idx = np.array(idx, dtype=np.int64).flatten()
        
        # Filter positions that have enough context
        print(f"Filtering {len(idx)} indices for sufficient context...")
        self.idx = np.array([int(pos) for pos in idx if pos >= self.num_time_steps - 1], dtype=np.int64)
        
        self.non_causal_steps = non_causal_steps
        self.reduce_factor = reduce_factor
        
        # Group indices by class
        self.class_indices = self._group_by_class()
        
        # Calculate class weights for improved sampling
        self._calculate_class_weights()
        
        # Initialize indexes for batch creation
        self.on_epoch_end()

    def _calculate_class_weights(self):
        """
        Calculate weights for each class based on inverse frequency
        """
        self.class_weights = {}
        total_samples = sum(len(indices) for indices in self.class_indices.values())
        
        for cls, indices in self.class_indices.items():
            # Weight is inversely proportional to class frequency
            self.class_weights[cls] = total_samples / (len(indices) * len(self.class_indices))
            
        # Define thresholds for rare classes
        class_sizes = {cls: len(indices) for cls, indices in self.class_indices.items()}
        self.rare_threshold = 300  # Classes with fewer than this many samples are considered rare
        
        # Print class size statistics
        print("\nClass size statistics:")
        print(f"Rare threshold: {self.rare_threshold} samples")
        rare_classes = [cls for cls, size in class_sizes.items() if size < self.rare_threshold]
        print(f"Rare classes: {rare_classes}")
        print(f"Number of rare classes: {len(rare_classes)} out of {len(self.class_indices)}")

    def _group_by_class(self):
        """
        Group position indices by their corresponding phoneme class.
        Uses a two-pass approach for efficiency and handles float and array class labels.
        
        Returns:
            Dictionary mapping class labels to lists of position indices
        """
        print("Starting to group indices by phoneme class...")
        start_time = time.time()
        
        # Use a dictionary instead of numpy array to handle float/array class labels
        class_indices = defaultdict(list)
        
        # Process in chunks to show progress
        chunk_size = 5000
        num_chunks = (len(self.idx) + chunk_size - 1) // chunk_size
        
        print("First pass: Counting class occurrences...")
        for chunk_idx in range(num_chunks):
            start_idx = chunk_idx * chunk_size
            end_idx = min((chunk_idx + 1) * chunk_size, len(self.idx))
            chunk = self.idx[start_idx:end_idx]
            
            print(f"Processing chunk {chunk_idx+1}/{num_chunks} ({start_idx}-{end_idx})...")
            
            for pos in chunk:
                # Check bounds to prevent index errors
                if pos < len(self.Y) and pos - self.non_causal_steps >= 0:
                    # Get class label for this position
                    cls = self.Y[pos - self.non_causal_steps]
                    
                    # Convert numpy arrays/non-hashable types to hashable versions
                    if isinstance(cls, np.ndarray):
                        cls = float(cls.item())  # Convert to native Python type
                    else:
                        cls = float(cls)  # Ensure it's a native Python float for use as dict key
                    
                    # Add position to the class list (ensure it's an integer)
                    class_indices[cls].append(int(pos))
                
        # Report statistics
        elapsed = time.time() - start_time
        print(f"Grouped {len(self.idx)} indices into {len(class_indices)} classes in {elapsed:.2f} seconds")
        
        # Report class distribution
        for cls in sorted(class_indices.keys()):
            count = len(class_indices[cls])
            print(f"Class {cls}: {count} samples")
            
        return class_indices

    def __len__(self):
        """Return the number of batches per epoch"""
        # Calculate how many complete batches we can create
        # We want to ensure we have at least one sample from each available class in each batch
        num_available_classes = len(self.class_indices)
        
        if num_available_classes == 0:
            return 0
            
        total_samples = sum(len(indices) for indices in self.class_indices.values())
        
        # Determine number of batches based on total samples and batch size
        # We need at least one sample from each class in each batch
        num_batches = max(1, total_samples // self.batch_size)
        
        # Adjust for reduce_factor if needed
        return max(1, int(num_batches // self.reduce_factor))

    def __getitem__(self, index):
        """Generate one batch of data with balanced class distribution"""
        # Create balanced batch with samples from all classes
        batch_indices = self._create_balanced_batch(index)
        
        # Generate data for this batch
        X, Y = self._data_generation(batch_indices)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
            
        return X, Y

    def _create_balanced_batch(self, batch_index):
        """
        Create a balanced batch ensuring better representation of rare classes.
        
        Args:
            batch_index: Index of the batch to create
            
        Returns:
            List of position indices for the batch
        """
        batch_indices = []
        available_classes = list(self.class_indices.keys())
        
        if not available_classes:
            raise ValueError("No classes available for batch creation")
            
        # IMPROVEMENT 1: Give more representation to rare classes
        for cls in available_classes:
            if self.class_indices[cls]:  # If there are samples for this class
                cls_indices = self.class_indices[cls]
                
                # For rare classes, include more samples per batch
                if len(cls_indices) < self.rare_threshold:  # Threshold for "rare"
                    # Take more samples for rare classes
                    samples_to_use = min(5, len(cls_indices))  # Take up to 5 samples per rare class
                    for j in range(samples_to_use):
                        # Use different indices for each batch and sample
                        idx_in_class = (batch_index * 7 + j) % len(cls_indices)
                        batch_indices.append(cls_indices[idx_in_class])
                else:
                    # For common classes, just take one sample
                    idx_in_class = (batch_index * 7) % len(cls_indices)
                    batch_indices.append(cls_indices[idx_in_class])
                
                # Stop if batch is full
                if len(batch_indices) >= self.batch_size:
                    break
        
        # If batch is not full, add more samples with weighted selection
        if len(batch_indices) < self.batch_size:
            # IMPROVEMENT 2: Create flat arrays for weighted sampling that are guaranteed to be 1D
            all_indices = []
            all_weights = []
            
            # Build flat lists of indices and their corresponding weights
            for cls in available_classes:
                for idx in self.class_indices[cls]:
                    if idx not in batch_indices:  # Avoid duplicates
                        all_indices.append(idx)
                        all_weights.append(self.class_weights[cls])
            
            # If we have indices to sample from
            if all_indices:
                # Convert to NumPy arrays
                all_indices = np.array(all_indices, dtype=np.int64)
                all_weights = np.array(all_weights, dtype=np.float32)
                
                # Normalize weights
                if np.sum(all_weights) > 0:
                    all_weights = all_weights / np.sum(all_weights)
                    
                    # Use weighted sampling for remaining indices
                    num_remaining = self.batch_size - len(batch_indices)
                    if num_remaining > 0:
                        try:
                            # Weighted random choice
                            chosen_indices = np.random.choice(
                                all_indices,
                                size=min(num_remaining, len(all_indices)),
                                replace=False,
                                p=all_weights
                            )
                            batch_indices.extend(chosen_indices.tolist())
                        except Exception as e:
                            print(f"Weighted sampling failed: {e}")
                            print(f"Falling back to unweighted sampling")
                            # Fallback to unweighted sampling
                            chosen_indices = np.random.choice(
                                all_indices,
                                size=min(num_remaining, len(all_indices)),
                                replace=False
                            )
                            batch_indices.extend(chosen_indices.tolist())
                else:
                    # Fallback to unweighted sampling if weights sum to zero
                    num_remaining = self.batch_size - len(batch_indices)
                    chosen_indices = np.random.choice(
                        all_indices,
                        size=min(num_remaining, len(all_indices)),
                        replace=False
                    )
                    batch_indices.extend(chosen_indices.tolist())
        
        # Ensure batch size is correct
        if len(batch_indices) < self.batch_size:
            # If we still don't have enough samples, repeat existing ones
            shortage = self.batch_size - len(batch_indices)
            # Make sure batch_indices is not empty
            if batch_indices:
                indices_to_repeat = np.array(batch_indices, dtype=np.int64)
                batch_indices.extend(np.random.choice(indices_to_repeat, size=shortage).tolist())
            else:
                # Fallback if we have no indices at all - use random values
                print("Warning: No valid indices available for batch creation")
                # Use first index if available, otherwise 0
                if len(self.idx) > 0:
                    batch_indices = [int(self.idx[0])] * self.batch_size 
                else:
                    batch_indices = [0] * self.batch_size
            
        return batch_indices

    def _data_generation(self, list_idx_temp):
        """
        Generate data containing batch_size samples
        
        Args:
            list_idx_temp: List of position indices for this batch
            
        Returns:
            X, Y data for the batch
        """
        X = np.empty(self.out_dim)
        Y = np.empty((self.batch_size), dtype=int)
                
        for i, ID in enumerate(list_idx_temp):
            # Convert ID to integer to ensure proper indexing
            ID_int = int(ID) if isinstance(ID, (float, np.float32, np.float64)) else ID
            if hasattr(ID, 'item'):
                ID_int = int(ID.item())  # Handle numpy scalars
                
            # Check bounds to prevent errors
            if ID_int >= self.num_time_steps - 1 and ID_int < len(self.X):
                # Get the input data window
                X[i,] = self.X[ID_int-self.num_time_steps+1:ID_int+1, ].reshape(self.out_dim_nobatch)
                
                # Get the target class - use proper bounds checking
                target_idx = min(ID_int-self.non_causal_steps, len(self.Y) - 1)
                target_idx = max(0, target_idx)  # Ensure not negative
                Y[i] = self.Y[target_idx]
            else:
                print(f"Warning: Index {ID_int} out of bounds for X shape {self.X.shape}")
                # Use zeros as fallback
                X[i,] = np.zeros(self.out_dim_nobatch)
                Y[i] = 0
        
        return X, tf.keras.utils.to_categorical(Y, num_classes=self.num_classes, dtype='float32')

    def on_epoch_end(self):
        """Update indexes after each epoch"""
        # If shuffle is enabled, shuffle the samples within each class
        if self.shuffle:
            for cls in self.class_indices:
                np.random.shuffle(self.class_indices[cls])


class BalancedDataGeneratorTri(BalancedDataGenerator):
    """
    Enhanced balanced generator for tri-phoneme prediction
    """
    def __init__(self, idx, X, Y, out_dim=(64,128,2,192), shuffle=True, reduce_factor=1, non_causal_steps=0,
                 Y_tri=None, Y_weights=None):
        # Store tri-phoneme data
        self.Y_tri = Y_tri
        self.Y_weights = Y_weights
        
        # Initialize the base generator
        super(BalancedDataGeneratorTri, self).__init__(
            idx, X, Y, out_dim, shuffle, reduce_factor, non_causal_steps
        )

    def __getitem__(self, index):
        """Generate one batch of data with tri-phoneme targets"""
        batch_indices = self._create_balanced_batch(index)
        X, Y, Y_tri = self._data_generation_tri(batch_indices)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
            
        return X, [Y, Y_tri]

    def _data_generation_tri(self, list_idx_temp):
        """
        Generate data containing batch_size samples with tri-phoneme targets
        
        Args:
            list_idx_temp: List of position indices for this batch
            
        Returns:
            X, Y, Y_tri data for the batch
        """
        X = np.empty(self.out_dim)
        Y = np.empty((self.batch_size), dtype=int)
        
        # Initialize Y_tri output - use the same shape as in original code
        if self.Y_tri is not None:
            Y_tri = np.empty((self.batch_size), dtype=int)
        else:
            # Fallback if Y_tri not provided
            Y_tri = np.copy(Y)
                
        for i, ID in enumerate(list_idx_temp):
            # FIX: Convert ID to integer to ensure proper indexing
            ID_int = int(ID) if isinstance(ID, (float, np.float32, np.float64)) else ID
            if hasattr(ID, 'item'):
                ID_int = int(ID.item())  # Handle numpy scalars
                
            # Check bounds to prevent errors
            if ID_int >= self.num_time_steps - 1 and ID_int < len(self.X):
                # Get the input data window
                X[i,] = self.X[ID_int-self.num_time_steps+1:ID_int+1, ].reshape(self.out_dim_nobatch)
                
                # Get the target classes - use proper bounds checking
                target_idx = min(ID_int-self.non_causal_steps, len(self.Y) - 1)
                target_idx = max(0, target_idx)  # Ensure not negative
                
                Y[i] = int(self.Y[target_idx])  # FIX: Ensure integer type
                
                if self.Y_tri is not None:
                    # Check bounds for Y_tri
                    if target_idx < len(self.Y_tri):
                        Y_tri[i] = int(self.Y_tri[target_idx])  # FIX: Ensure integer type
                    else:
                        Y_tri[i] = 0  # Fallback for out of bounds
                else:
                    Y_tri[i] = Y[i]  # Use the same class as fallback
            else:
                print(f"Warning: Index {ID_int} out of bounds for X shape {self.X.shape}")
                # Use zeros as fallback
                X[i,] = np.zeros(self.out_dim_nobatch)
                Y[i] = 0
                Y_tri[i] = 0
        
        # Convert to categorical - Ensure values are valid for to_categorical
        # FIX: Ensure all values are in valid range before conversion
        # For Y_cat, ensure all values are in range 0-39
        Y = np.clip(Y, 0, self.num_classes-1)
        Y_cat = tf.keras.utils.to_categorical(Y, num_classes=self.num_classes, dtype='float32')
        
        # For Y_tri, determine the number of tri-phoneme classes, default to regular num_classes
        num_tri_classes = self.num_classes
        if self.Y_tri is not None:
            # Clip to ensure valid range
            Y_tri = np.clip(Y_tri, 0, self.num_classes-1)
            
        # Create categorical with proper number of classes
        Y_tri_cat = tf.keras.utils.to_categorical(Y_tri, num_classes=num_tri_classes, dtype='float32')
            
        return X, Y_cat, Y_tri_cat


class BalancedHierarchicalDataGenerator(BalancedDataGeneratorTri):
    """
    Enhanced balanced generator with hierarchical classification
    Supports both regular phoneme classes and higher-level phoneme groups
    """
    def __init__(self, idx, X, Y, out_dim=(64,128,2,192), shuffle=True, reduce_factor=1, non_causal_steps=0,
                Y_tri=None, Y_weights=None, num_groups=5):
        self.num_groups = num_groups
        
        # Initialize the base generator
        super(BalancedHierarchicalDataGenerator, self).__init__(
            idx, X, Y, out_dim, shuffle, reduce_factor, non_causal_steps, Y_tri, Y_weights
        )

    def __getitem__(self, index):
        """Generate one batch of data with hierarchical targets"""
        batch_indices = self._create_balanced_batch(index)
        X, Y, Y_tri, Y_groups = self._data_generation_hierarchical(batch_indices)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
            
        # FIX: Return 4 outputs matching the model's 4 output heads
        # The model expects: [phoneme_group, out_prev2, out_now2, out_next2]
        # So we return: [Y_groups, Y, Y, Y_tri] where Y is used both for prev and now
        return X, [Y_groups, Y, Y, Y_tri]

    def _data_generation_hierarchical(self, list_idx_temp):
        """
        Generate data with hierarchical classification targets
        
        Args:
            list_idx_temp: List of position indices for this batch
            
        Returns:
            X, Y, Y_tri, Y_groups data for the batch
        """
        # Get regular data
        X, Y_cat, Y_tri_cat = self._data_generation_tri(list_idx_temp)
        
        # Create group labels (phoneme groups)
        Y = np.argmax(Y_cat, axis=1)
        Y_groups = np.zeros((self.batch_size, self.num_groups), dtype='float32')
        
        # Assign each phoneme to its group based on index
        for i in range(len(Y)):
            # Convert to int to safely use as index and prevent float issues
            phoneme = int(Y[i])
            # Calculate group index (e.g., for 5 groups with 40 phonemes: 0-7=0, 8-15=1, etc.)
            group_idx = min(phoneme // (40 // self.num_groups), self.num_groups - 1)
            Y_groups[i, group_idx] = 1.0
            
        return X, Y_cat, Y_tri_cat, Y_groups
