"""
srA2.py — Stage 2: Non-Causal Hierarchical Classifier

Architecture (Paper Section 2.6, Appendix A):
  - Input: (batch, 305, 9) — log-probabilities from srA1 over 610 ms window
  - 3 bidirectional GRU layers (192, 192, 128 units)
  - Residual connection between BiGRU layers 1 and 2
  - Multi-head self-attention (6 heads, key_dim=64)
  - Dense classification head (512 → 256 → 128 with skip connection)
  - Output: 9-class softmax

Training:
  - Focal loss (γ=2.0, α=0.25)
  - Adam optimizer (lr=1e-3, gradient clipping at 1.0)
  - Batch size 32
  - Early stopping (patience 20, monitor val_categorical_accuracy)
  - LR reduction (factor 0.5, patience 10)

Expected parameter count: 405,513
"""

import os
import numpy as np
import tensorflow as tf

from simsacues.asr.data_generators import HierarchicalDataGenerator
from simsacues.phoneme_categories import NUM_CATEGORIES
from simsacues.asr.losses import focal_loss


def build_srA2(input_shape=(305, 9), num_classes=NUM_CATEGORIES):
    """
    Build the Stage 2 non-causal hierarchical classifier.

    Architecture matches paper Section 2.6 and Appendix A:
      - BiGRU(192) → LayerNorm
      - BiGRU(192) → LayerNorm + residual from layer 1 (with projection)
      - Multi-head attention: 6 heads, key_dim=64, dropout=0.2
      - BiGRU(128) → LayerNorm
      - Dense(512, relu, dropout=0.4)
      - Dense(256, relu, dropout=0.3)
      - Dense(128, relu, dropout=0.3) + skip connection
      - Dense(9, softmax)

    BiGRU merge_mode='concat', so output dims are 2×units.
    """
    input_layer = tf.keras.layers.Input(shape=input_shape, name='input')

    # BiGRU layer 1: 192 units → concat → 384 dims
    x1 = tf.keras.layers.Bidirectional(
        tf.keras.layers.GRU(192, return_sequences=True,
                            dropout=0.2, recurrent_dropout=0.1),
        merge_mode='concat'
    )(input_layer)
    x1 = tf.keras.layers.LayerNormalization()(x1)

    # BiGRU layer 2: 192 units → concat → 384 dims
    x2 = tf.keras.layers.Bidirectional(
        tf.keras.layers.GRU(192, return_sequences=True,
                            dropout=0.2, recurrent_dropout=0.1),
        merge_mode='concat'
    )(x1)
    x2 = tf.keras.layers.LayerNormalization()(x2)

    # Residual connection (project x1 if dims differ)
    x1_proj = tf.keras.layers.Dense(x2.shape[-1])(x1)
    x = tf.keras.layers.Add()([x1_proj, x2])

    # Multi-head self-attention (6 heads, key_dim=64)
    attention = tf.keras.layers.MultiHeadAttention(
        num_heads=6, key_dim=64, dropout=0.2
    )(x, x)
    x = tf.keras.layers.Add()([x, attention])
    x = tf.keras.layers.LayerNormalization()(x)

    # BiGRU layer 3: 128 units → concat → 256 dims (returns final state)
    x = tf.keras.layers.Bidirectional(
        tf.keras.layers.GRU(128, dropout=0.2, recurrent_dropout=0.1),
        merge_mode='concat'
    )(x)
    x = tf.keras.layers.LayerNormalization()(x)

    # Dense classification head
    x_dense1 = tf.keras.layers.Dense(512, activation='relu')(x)
    x_dense1 = tf.keras.layers.Dropout(0.4)(x_dense1)

    x_dense2 = tf.keras.layers.Dense(256, activation='relu')(x_dense1)
    x_dense2 = tf.keras.layers.Dropout(0.3)(x_dense2)

    x_dense3 = tf.keras.layers.Dense(128, activation='relu')(x_dense2)
    x_dense3 = tf.keras.layers.Dropout(0.3)(x_dense3)

    # Skip connection from BiGRU3 output to final dense
    x_skip = tf.keras.layers.Dense(128, activation='relu')(x)
    x_final = tf.keras.layers.Add()([x_dense3, x_skip])

    # Output
    output = tf.keras.layers.Dense(
        num_classes, activation='softmax', name='output'
    )(x_final)

    model = tf.keras.Model(inputs=input_layer, outputs=output)
    return model


def train_srA2(srA1_logprobs_path, Y_path, output_dir,
               epochs=60, batch_size=32, num_classes=NUM_CATEGORIES):
    """
    Train srA2 on log-probability outputs from srA1.

    Parameters
    ----------
    srA1_logprobs_path : str
        Path to srA1 log-probability predictions .npy, shape (N, 9).
    Y_path : str
        Path to 9-category labels .npy, shape (N,).
    output_dir : str
        Directory for saved weights and logs.
    epochs : int
        Maximum training epochs.
    batch_size : int
        Training batch size. Paper specifies 32.
    num_classes : int
        Number of categories.
    """
    os.makedirs(output_dir, exist_ok=True)

    # Load data
    X_logprobs = np.load(srA1_logprobs_path)
    Y = np.load(Y_path)
    print(f"Loaded data: X_logprobs={X_logprobs.shape}, Y={Y.shape}")

    # Train/validation split (85/15)
    indices = np.arange(len(Y))
    np.random.seed(42)
    np.random.shuffle(indices)
    split = int(0.85 * len(indices))
    train_idx = indices[:split]
    val_idx = indices[split:]
    print(f"Train: {len(train_idx):,}, Val: {len(val_idx):,}")

    # Data generators
    train_gen = HierarchicalDataGenerator(
        train_idx, X_logprobs, Y,
        batch_size=batch_size, time_window=305,
        num_classes=num_classes, shuffle=True
    )
    val_gen = HierarchicalDataGenerator(
        val_idx, X_logprobs, Y,
        batch_size=batch_size, time_window=305,
        num_classes=num_classes, shuffle=False
    )

    # Build model
    model = build_srA2(
        input_shape=(305, num_classes), num_classes=num_classes
    )
    model.summary()
    print(f"Total parameters: {model.count_params():,}")

    # Compile
    model.compile(
        loss=focal_loss(alpha=0.25, gamma=2.0),
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3, clipnorm=1.0),
        metrics=['categorical_accuracy']
    )

    # Callbacks
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_categorical_accuracy',
            patience=20,
            restore_best_weights=True,
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_categorical_accuracy',
            patience=10,
            factor=0.5,
            min_lr=1e-5,
            verbose=1
        ),
        tf.keras.callbacks.ModelCheckpoint(
            os.path.join(output_dir, 'srA2_best.h5'),
            monitor='val_categorical_accuracy',
            save_best_only=True,
            save_weights_only=True,
            verbose=1
        ),
    ]

    # Train
    history = model.fit(
        train_gen,
        validation_data=val_gen,
        epochs=epochs,
        callbacks=callbacks,
        verbose=1
    )

    # Save final weights
    model.save_weights(os.path.join(output_dir, 'srA2_final.h5'))
    print(f"Training complete. Best val accuracy: "
          f"{max(history.history['val_categorical_accuracy']):.4f}")

    return model, history


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Train srA2')
    parser.add_argument('--logprobs-path', type=str, required=True)
    parser.add_argument('--y-path', type=str, required=True)
    parser.add_argument('--output-dir', type=str, required=True)
    parser.add_argument('--epochs', type=int, default=60)
    parser.add_argument('--batch-size', type=int, default=32)
    args = parser.parse_args()

    train_srA2(args.logprobs_path, args.y_path, args.output_dir,
               epochs=args.epochs, batch_size=args.batch_size)
