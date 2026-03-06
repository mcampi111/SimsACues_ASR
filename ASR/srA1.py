"""
srA1.py — Stage 1: Causal Phoneme Classifier

Architecture (Paper Section 2.6, Appendix A):
  - Input: (batch, 50, 150) — 50 causal frames × 150 frequency channels
  - 3 unidirectional GRU layers (128 units each)
  - Residual connection between GRU layers 1 and 2
  - Multi-head self-attention (4 heads, key_dim=32)
  - Dense classification head (256 → 128 with skip connection)
  - Output: 9-class softmax

Training:
  - Focal loss (γ=2.0, α=0.25)
  - Adam optimizer (lr=1e-3, gradient clipping at 1.0)
  - Batch size 32
  - Early stopping (patience 20, monitor val_categorical_accuracy)
  - LR reduction (factor 0.5, patience 10)

Expected parameter count: 456,073
"""

import os
import numpy as np
import tensorflow as tf

from data_generators import CausalDataGenerator
from phoneme_categories import NUM_CATEGORIES


def focal_loss(alpha=0.25, gamma=2.0):
    """
    Focal loss for class-imbalanced classification.

    Paper: "Focal loss (γ = 2.0) was used to address class imbalance."
    """
    def loss_fn(y_true, y_pred):
        y_pred = tf.clip_by_value(y_pred, 1e-7, 1.0 - 1e-7)
        ce_loss = -tf.reduce_sum(y_true * tf.math.log(y_pred), axis=-1)
        pt = tf.reduce_sum(y_true * y_pred, axis=-1)
        focal_weight = alpha * tf.pow(1.0 - pt, gamma)
        return tf.reduce_mean(focal_weight * ce_loss)
    return loss_fn


def build_srA1(input_shape=(50, 150), num_classes=NUM_CATEGORIES):
    """
    Build the Stage 1 causal classifier.

    Architecture matches paper Section 2.6 and Appendix A:
      - 3 GRU(128) layers, unidirectional
      - Residual connection: GRU1 + GRU2
      - Multi-head attention: 4 heads, key_dim=32, dropout=0.1
      - GRU3 (return final state)
      - Dense(256, relu) → Dropout(0.4)
      - Dense(128, relu) → Dropout(0.3) + skip connection
      - Dense(9, softmax)

    GRU dropout: 0.2, recurrent_dropout: 0.1
    """
    input_layer = tf.keras.Input(shape=input_shape, name='input')

    # GRU layer 1
    x1 = tf.keras.layers.GRU(
        128, return_sequences=True,
        dropout=0.2, recurrent_dropout=0.1, name='gru1'
    )(input_layer)
    x1 = tf.keras.layers.LayerNormalization()(x1)

    # GRU layer 2
    x2 = tf.keras.layers.GRU(
        128, return_sequences=True,
        dropout=0.2, recurrent_dropout=0.1, name='gru2'
    )(x1)
    x2 = tf.keras.layers.LayerNormalization()(x2)

    # Residual connection (GRU1 + GRU2)
    x = tf.keras.layers.Add()([x1, x2])

    # Multi-head self-attention (4 heads, key_dim=32)
    attention = tf.keras.layers.MultiHeadAttention(
        num_heads=4, key_dim=32, dropout=0.1
    )(x, x)
    x = tf.keras.layers.Add()([x, attention])
    x = tf.keras.layers.LayerNormalization()(x)

    # GRU layer 3 (returns final hidden state)
    x = tf.keras.layers.GRU(
        128, dropout=0.2, recurrent_dropout=0.1, name='gru3'
    )(x)
    x = tf.keras.layers.Dropout(0.3)(x)

    # Dense classification head
    x_dense1 = tf.keras.layers.Dense(256, activation='relu')(x)
    x_dense1 = tf.keras.layers.Dropout(0.4)(x_dense1)

    x_dense2 = tf.keras.layers.Dense(128, activation='relu')(x_dense1)
    x_dense2 = tf.keras.layers.Dropout(0.3)(x_dense2)

    # Skip connection from GRU output to final dense
    x_skip = tf.keras.layers.Dense(128, activation='relu')(x)
    x_combined = tf.keras.layers.Add()([x_dense2, x_skip])

    # Output
    output = tf.keras.layers.Dense(
        num_classes, activation='softmax', name='output'
    )(x_combined)

    model = tf.keras.Model(inputs=input_layer, outputs=output)
    return model


def train_srA1(X_path, Y_path, output_dir,
               epochs=50, batch_size=32, num_classes=NUM_CATEGORIES):
    """
    Train srA1 with configuration matching the paper.

    Parameters
    ----------
    X_path : str
        Path to neurogram features .npy file, shape (N, 150).
    Y_path : str
        Path to 9-category labels .npy file, shape (N,).
    output_dir : str
        Directory to save model weights and logs.
    epochs : int
        Maximum training epochs. Default 50.
    batch_size : int
        Training batch size. Paper specifies 32.
    num_classes : int
        Number of output categories. Default 9.
    """
    os.makedirs(output_dir, exist_ok=True)

    # Load data
    X = np.load(X_path)
    Y = np.load(Y_path)
    print(f"Loaded data: X={X.shape}, Y={Y.shape}")

    # Train/validation split (85/15)
    indices = np.arange(len(X))
    np.random.seed(42)
    np.random.shuffle(indices)
    split = int(0.85 * len(indices))
    train_idx = indices[:split]
    val_idx = indices[split:]
    print(f"Train: {len(train_idx):,}, Val: {len(val_idx):,}")

    # Data generators
    train_gen = CausalDataGenerator(
        train_idx, X, Y,
        batch_size=batch_size, num_timesteps=50,
        num_classes=num_classes, shuffle=True, apply_noise=True
    )
    val_gen = CausalDataGenerator(
        val_idx, X, Y,
        batch_size=batch_size, num_timesteps=50,
        num_classes=num_classes, shuffle=False, apply_noise=False
    )

    # Build model
    model = build_srA1(input_shape=(50, X.shape[1]), num_classes=num_classes)
    model.summary()
    print(f"Total parameters: {model.count_params():,}")

    # Compile — paper specifies focal loss, Adam lr=1e-3, clipnorm=1.0
    model.compile(
        loss=focal_loss(alpha=0.25, gamma=2.0),
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3, clipnorm=1.0),
        metrics=['categorical_accuracy']
    )

    # Callbacks — paper specifies patience 20, LR factor 0.5 patience 10
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
            os.path.join(output_dir, 'srA1_best.h5'),
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
    model.save_weights(os.path.join(output_dir, 'srA1_final.h5'))
    print(f"Training complete. Best val accuracy: "
          f"{max(history.history['val_categorical_accuracy']):.4f}")

    return model, history


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Train srA1')
    parser.add_argument('--x-path', type=str, required=True)
    parser.add_argument('--y-path', type=str, required=True)
    parser.add_argument('--output-dir', type=str, required=True)
    parser.add_argument('--epochs', type=int, default=50)
    parser.add_argument('--batch-size', type=int, default=32)
    args = parser.parse_args()

    train_srA1(args.x_path, args.y_path, args.output_dir,
               epochs=args.epochs, batch_size=args.batch_size)
