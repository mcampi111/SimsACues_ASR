"""
data_generators.py — Training data generators for srA1 and srA2

Implements:
  - CausalDataGenerator: for srA1 (50-frame causal windows = 100 ms)
  - HierarchicalDataGenerator: for srA2 (305-frame bidirectional windows = 610 ms)
  - Cognitive noise injection (pink noise, 5–15 dB SNR)

Paper references: Section 2.3 (cognitive noise), Section 2.6 (architecture windows)
"""

import numpy as np
import tensorflow as tf

from simsacues.noise import add_cognitive_noise


class CausalDataGenerator(tf.keras.utils.Sequence):
    """
    Data generator for srA1 (Stage 1, causal model).

    Paper: "50-frame causal windows (100 ms at 500 Hz)"

    Yields batches of (X, Y) where:
      X: (batch_size, 50, num_features)  — causal context window
      Y: (batch_size, 9)                 — one-hot category label
    """

    def __init__(self, indices, X, Y, batch_size=32, num_timesteps=50,
                 num_classes=9, shuffle=True, apply_noise=True):
        """
        Parameters
        ----------
        indices : np.ndarray
            Valid sample indices into X and Y.
        X : np.ndarray, shape (N, num_features)
            Full neurogram feature array (concatenated across utterances).
        Y : np.ndarray, shape (N,)
            Phoneme category labels (0–8).
        batch_size : int
        num_timesteps : int
            Causal window size. Default 50 (= 100 ms at 500 Hz).
        num_classes : int
            Number of output categories. Default 9.
        shuffle : bool
            Whether to shuffle indices each epoch.
        apply_noise : bool
            Whether to add cognitive noise during training.
        """
        self.X = X
        self.Y = Y
        self.batch_size = batch_size
        self.num_timesteps = num_timesteps
        self.num_classes = num_classes
        self.num_features = X.shape[1]
        self.shuffle = shuffle
        self.apply_noise = apply_noise

        # Filter indices that have enough causal context
        self.indices = indices[indices >= num_timesteps - 1]
        self.on_epoch_end()

    def __len__(self):
        return max(1, len(self.indices) // self.batch_size)

    def __getitem__(self, index):
        start = index * self.batch_size
        end = min(start + self.batch_size, len(self.indices))
        batch_indices = self.order[start:end]
        actual_batch = len(batch_indices)

        X_batch = np.zeros((actual_batch, self.num_timesteps, self.num_features))
        Y_batch = np.zeros((actual_batch,), dtype=int)

        for i, idx in enumerate(batch_indices):
            sample_idx = self.indices[idx]
            t_start = sample_idx - self.num_timesteps + 1
            t_end = sample_idx + 1
            X_batch[i] = self.X[t_start:t_end]
            Y_batch[i] = self.Y[sample_idx]

            if self.apply_noise:
                X_batch[i] = add_cognitive_noise(X_batch[i])

        Y_onehot = tf.keras.utils.to_categorical(Y_batch, num_classes=self.num_classes)
        return X_batch, Y_onehot

    def on_epoch_end(self):
        self.order = np.arange(len(self.indices))
        if self.shuffle:
            np.random.shuffle(self.order)


class HierarchicalDataGenerator(tf.keras.utils.Sequence):
    """
    Data generator for srA2 (Stage 2, non-causal/bidirectional model).

    Paper: "305-frame bidirectional windows (610 ms)"

    srA2 receives log-probability outputs from srA1, not raw neurograms.

    Yields batches of (X, Y) where:
      X: (batch_size, 305, 9)   — log-probability sequences from srA1
      Y: (batch_size, 9)        — one-hot category label
    """

    def __init__(self, indices, X_logprobs, Y, batch_size=32,
                 time_window=305, num_classes=9, shuffle=True):
        """
        Parameters
        ----------
        indices : np.ndarray
            Valid sample indices.
        X_logprobs : np.ndarray, shape (N, 9)
            Log-probability outputs from srA1 for each time step.
        Y : np.ndarray, shape (N,)
            Category labels (0–8).
        batch_size : int
        time_window : int
            Bidirectional context window. Default 305 (= 610 ms).
        num_classes : int
        shuffle : bool
        """
        self.X = X_logprobs
        self.Y = Y
        self.batch_size = batch_size
        self.time_window = time_window
        self.num_classes = num_classes
        self.shuffle = shuffle
        self.non_causal_steps = time_window // 2  # 152

        # Filter indices with enough context on both sides
        valid = (indices >= self.non_causal_steps) & \
                (indices < len(X_logprobs) - self.non_causal_steps)
        self.indices = indices[valid]
        self.on_epoch_end()

    def __len__(self):
        return max(1, len(self.indices) // self.batch_size)

    def __getitem__(self, index):
        start = index * self.batch_size
        end = min(start + self.batch_size, len(self.indices))
        batch_indices = self.order[start:end]
        actual_batch = len(batch_indices)

        X_batch = np.zeros((actual_batch, self.time_window, self.num_classes))
        Y_batch = np.zeros((actual_batch,), dtype=int)

        for i, idx in enumerate(batch_indices):
            sample_idx = self.indices[idx]
            t_start = sample_idx - self.non_causal_steps
            t_end = t_start + self.time_window
            X_batch[i] = self.X[t_start:t_end]
            Y_batch[i] = self.Y[sample_idx]

        Y_onehot = tf.keras.utils.to_categorical(Y_batch, num_classes=self.num_classes)
        return X_batch, Y_onehot

    def on_epoch_end(self):
        self.order = np.arange(len(self.indices))
        if self.shuffle:
            np.random.shuffle(self.order)
