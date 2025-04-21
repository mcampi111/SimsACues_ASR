"""
DataGenTimitTriBalanced.py - Enhanced data generator for TIMIT dataset with balanced batch sampling

This version combines the best aspects of both implementations:
1. Linguistic-based phoneme grouping from the successful version
2. Three-step batch creation strategy with rare class focus + natural distribution
3. Improved error handling and window processing
4. Moderate weighting to prevent extreme oversampling while still addressing class imbalance
"""

import numpy as np
import tensorflow as tf
import time
from collections import defaultdict
import sys

# TIMIT Phoneme Groups based on phonetic characteristics
PHONEME_GROUPS = {
    # Group 0: Vowels and diphthongs
    "vowels": [0, 13, 14, 16, 17, 18, 19, 20, 21, 26, 32, 33, 35],
    
    # Group 1: Stops/Plosives
    "stops": [1, 2, 3, 4, 5, 6, 7, 11],
    
    # Group 2: Fricatives 
    "fricatives": [8, 9, 10, 12, 15, 22, 23, 24, 25],
    
    # Group 3: Nasals and semivowels
    "nasals_semivowels": [27, 28, 29, 30, 31, 34, 36, 37],
    
    # Group 4: Silence and others
    "silence_other": [38, 39]
}

# Create a lookup dict for efficiency
PHONEME_TO_GROUP = {}
for group_idx, (group_name, phonemes) in enumerate(PHONEME_GROUPS.items()):
    for phoneme in phonemes:
        PHONEME_TO_GROUP[phoneme] = group_idx

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
            reduce_factor: factor to reduce dataset size (set to 1 to process ALL data)
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
        # IMPORTANT FIX: Make sure to check against both X and Y lengths to prevent index errors
        self.idx = np.array([
            int(pos) for pos in idx 
            if pos >= self.num_time_steps - 1 and pos < len(X) and pos - non_causal_steps < len(Y)
        ], dtype=np.int64)
        
        if len(self.idx) < len(idx):
            print(f"Filtered out {len(idx) - len(self.idx)} indices that didn't have enough context")
        
        self.non_causal_steps = non_causal_steps
        # IMPORTANT FIX: Set reduce_factor to 1 to process ALL data
        self.reduce_factor = 1
        
        # Group indices by class
        self.class_indices = self._group_by_class()
        
        # Calculate class weights for improved sampling
        self._calculate_class_weights()
        
        # Initialize indexes for batch creation
        self.on_epoch_end()

    def _calculate_class_weights(self):
        """
        Calculate weights for each class based on inverse frequency with moderation
        """
        self.class_weights = {}
        total_samples = sum(len(indices) for indices in self.class_indices.values())
        
        for cls, indices in self.class_indices.items():
            # Weight is inversely proportional to class frequency but capped for rare classes
            # IMPORTANT CHANGE: Use more modest weighting to avoid extreme oversampling
            weight = total_samples / (len(indices) * len(self.class_indices))
            # Cap weights to prevent extreme oversampling of rare classes
            self.class_weights[cls] = min(3.0, weight)
            
        # Define thresholds for rare classes
        class_sizes = {cls: len(indices) for cls, indices in self.class_indices.items()}
        self.rare_threshold = 300  # Classes with fewer than this many samples are considered rare
        
        # Print class size statistics
        print("\nClass size statistics:")
        print(f"Rare threshold: {self.rare_threshold} samples")
        rare_classes = [cls for cls, size in class_sizes.items() if size < self.rare_threshold]
        print(f"Rare classes: {rare_classes}")
        print(f"Number of rare classes: {len(rare_classes)} out of {len(self.class_indices)}")

    def _group_by_class(self, verbose=False):
        """
        Group position indices by their corresponding phoneme class.
        Uses a two-pass approach for efficiency and handles float and array class labels.
        
        Args:
            verbose: whether to print processing chunk messages
            
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
            
            if verbose:
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
        # IMPORTANT CHANGE: Process much more data to approach 7.7M samples
        total_samples = sum(len(indices) for indices in self.class_indices.values())
        
        # We want at least 30,000 batches (similar to original 59.8% model)
        desired_batches = 30000
        
        # But make sure we don't exceed what we have
        return min(desired_batches, max(1, total_samples // self.batch_size))

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
        Create a balanced batch with smarter rare class handling
        
        Args:
            batch_index: Index of the batch to create
            
        Returns:
            List of position indices for the batch
        """
        batch_indices = []
        available_classes = list(self.class_indices.keys())
        
        if not available_classes:
            raise ValueError("No classes available for batch creation")
        
        # Step 1: First include at least one sample from each available rare class
        rare_classes = [cls for cls in available_classes 
                      if len(self.class_indices[cls]) < self.rare_threshold]
        
        for cls in rare_classes:
            if self.class_indices[cls]:  # If there are samples for this class
                cls_indices = self.class_indices[cls]
                # Take one sample from this rare class
                idx_in_class = (batch_index * 11) % len(cls_indices)  # Prime number for better coverage
                batch_indices.append(cls_indices[idx_in_class])
                
                # For extremely rare classes (fewer than 50 samples), 
                # take an additional sample with 50% probability
                if len(cls_indices) < 50 and np.random.random() < 0.5:
                    idx_in_class = (idx_in_class + 7) % len(cls_indices)  # Another prime offset
                    batch_indices.append(cls_indices[idx_in_class])
        
        # Step 2: Fill 70% of the remainder with balanced sampling across all classes
        target_balanced = int(0.7 * (self.batch_size - len(batch_indices)))
        if target_balanced > 0:
            # Sample remaining slots from all classes with moderate weighting
            all_classes = list(available_classes)  # Copy to avoid modification during iteration
            np.random.shuffle(all_classes)  # Shuffle to avoid always starting with the same classes
            
            for cls in all_classes:
                if len(batch_indices) >= len(batch_indices) + target_balanced:
                    break  # Stop if we've filled our balanced quota
                    
                cls_indices = self.class_indices[cls]
                if not cls_indices:
                    continue
                    
                # Calculate how many samples to take based on moderate weighting
                # More samples from common classes, but still some balance
                class_weight = min(2.0, np.sqrt(self.rare_threshold / max(10, len(cls_indices))))
                samples_to_use = min(
                    int(max(1, class_weight * 3)),  # At least 1, at most 6 samples per class
                    len(cls_indices),
                    target_balanced - (len(batch_indices) - len(batch_indices))  # Don't exceed our target
                )
                
                # Take the calculated number of samples
                for j in range(samples_to_use):
                    idx_in_class = (batch_index * 13 + j * 7) % len(cls_indices)  # More prime magic
                    batch_indices.append(cls_indices[idx_in_class])
        
        # Step 3: Fill the rest (30%) with natural distribution 
        # This helps the model learn the true data distribution
        remaining = self.batch_size - len(batch_indices)
        if remaining > 0:
            # Flatten indices from all classes
            all_indices = []
            for cls in self.class_indices:
                all_indices.extend(self.class_indices[cls])
                
            if all_indices:
                # Sample randomly without replacement
                chosen_indices = np.random.choice(
                    all_indices, 
                    size=min(remaining, len(all_indices)),
                    replace=False
                )
                batch_indices.extend(chosen_indices.tolist())
        
        # Ensure we have batch_size samples
        if len(batch_indices) < self.batch_size:
            # If we still don't have enough, repeat existing samples
            shortage = self.batch_size - len(batch_indices)
            if batch_indices:
                indices_to_repeat = np.array(batch_indices)
                batch_indices.extend(np.random.choice(indices_to_repeat, size=shortage).tolist())
            else:
                # Fallback
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
                
            # CRITICAL FIX: Better bounds checking to prevent "index out of bounds" errors
            if (ID_int >= self.num_time_steps - 1 and 
                ID_int < len(self.X) and 
                ID_int - self.num_time_steps + 1 >= 0):
                
                try:
                    # Get the input data window
                    window = self.X[ID_int-self.num_time_steps+1:ID_int+1]
                    # Check if window shape matches expected shape
                    if window.shape[0] == self.out_dim_nobatch[0]:
                        X[i,] = window.reshape(self.out_dim_nobatch)
                    else:
                        # Padding if window is smaller than expected
                        print(f"Window size mismatch at ID {ID_int}, using padding")
                        padded_window = np.zeros(self.out_dim_nobatch)
                        padded_window[:window.shape[0]] = window
                        X[i,] = padded_window
                except Exception as e:
                    print(f"Error processing window at ID {ID_int}: {e}")
                    X[i,] = np.zeros(self.out_dim_nobatch)
                
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
                
            # IMPROVED BOUNDS CHECKING: Check all conditions
            if (ID_int >= self.num_time_steps - 1 and 
                ID_int < len(self.X) and 
                ID_int - self.num_time_steps + 1 >= 0):
                
                try:
                    # Get the input data window
                    window = self.X[ID_int-self.num_time_steps+1:ID_int+1]
                    # Check if window shape matches expected shape
                    if window.shape[0] == self.out_dim_nobatch[0]:
                        X[i,] = window.reshape(self.out_dim_nobatch)
                    else:
                        # Padding if window is smaller than expected
                        padded_window = np.zeros(self.out_dim_nobatch)
                        padded_window[:window.shape[0]] = window
                        X[i,] = padded_window
                except Exception as e:
                    print(f"Error processing window at ID {ID_int}: {e}")
                    X[i,] = np.zeros(self.out_dim_nobatch)
                
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
        
        # Assign each phoneme to its proper linguistic group using PHONEME_TO_GROUP
        for i in range(len(Y)):
            phoneme = int(Y[i])
            # Get group using the lookup table
            group_idx = PHONEME_TO_GROUP.get(phoneme, 0)  # Default to group 0 if not found
            Y_groups[i, group_idx] = 1.0
            
        return X, Y_cat, Y_tri_cat, Y_groups
