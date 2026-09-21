"""Loss functions shared by srA1 and srA2.

Previously duplicated in ``srA1.py`` and ``srA2.py`` with identical code.
"""

import tensorflow as tf


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
