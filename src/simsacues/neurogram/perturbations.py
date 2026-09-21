"""
perturbations.py — ANSD Neurogram Perturbations

Implements the four perturbation types described in the paper (Section 2.2):
  1. Uniform temporal jitter
  2. Scattered temporal jitter
  3. Selective fiber loss
  4. Amplitude truncation

All perturbations operate on downsampled neurograms at 500 Hz (2 ms bins).

CRITICAL: The sampling_rate parameter must match the neurogram sampling rate (500 Hz),
NOT the original audio sampling rate (16 kHz) or the model sampling rate (100 kHz).
"""

import numpy as np


NEUROGRAM_SAMPLING_RATE = 500  # Hz — neurograms are downsampled to this rate


def apply_uniform_jitter(neurogram, max_jitter_ms=None, sampling_rate=NEUROGRAM_SAMPLING_RATE):
    """
    Uniform temporal jitter, identical across all frequency channels.

    A maximum displacement ``max_jitter_ms`` (default drawn from U(3, 10) ms)
    is converted to K = round(max_jitter_ms / sample period) samples. Each time
    frame t is then moved forward by an independent integer shift drawn from
    U{0, ..., K}, the same for every channel at that frame.

    Frames whose shifted positions coincide overwrite one another (the later
    frame wins), and positions that receive no frame remain zero. The output
    therefore combines temporal desynchronisation with a loss of activity; on
    synthetic input roughly a third of frames are left silent.

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Input neurogram at 500 Hz sampling rate.
    max_jitter_ms : float or None
        Maximum displacement in milliseconds. If None, drawn from U(3, 10).
    sampling_rate : float
        Neurogram sampling rate in Hz. Default 500 Hz.

    Returns
    -------
    np.ndarray
        Jittered neurogram, same shape as input.
    """
    if max_jitter_ms is None:
        max_jitter_ms = np.random.uniform(3.0, 10.0)

    neurogram_jittered = np.zeros_like(neurogram)
    num_time_frames, num_freq_channels = neurogram.shape
    max_jitter_samples = max(1, int(np.round((max_jitter_ms / 1000.0) * sampling_rate)))

    for t in range(num_time_frames):
        # Single jitter value for ALL channels at this time step
        jitter = np.random.randint(0, max_jitter_samples + 1)
        new_t = t + jitter
        if 0 <= new_t < num_time_frames:
            neurogram_jittered[new_t, :] = neurogram[t, :]

    return neurogram_jittered


def apply_scattered_jitter(neurogram, max_jitter_ms=None, sampling_rate=NEUROGRAM_SAMPLING_RATE):
    """
    Scattered temporal jitter, drawn independently per frequency channel.

    Same procedure as :func:`apply_uniform_jitter`, but every (t, f) cell gets
    its own shift from U{0, ..., K}. This desynchronises fibre populations tuned
    to different frequencies. As with uniform jitter, colliding cells overwrite
    one another and unfilled cells remain zero.

    NOTE: This is purely temporal jitter — no frequency-domain displacement.

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Input neurogram at 500 Hz sampling rate.
    max_jitter_ms : float or None
        Maximum displacement in milliseconds. If None, drawn from U(3, 10).
    sampling_rate : float
        Neurogram sampling rate in Hz. Default 500 Hz.

    Returns
    -------
    np.ndarray
        Jittered neurogram, same shape as input.
    """
    if max_jitter_ms is None:
        max_jitter_ms = np.random.uniform(3.0, 10.0)

    neurogram_jittered = np.zeros_like(neurogram)
    num_time_frames, num_freq_channels = neurogram.shape
    max_jitter_samples = max(1, int(np.round((max_jitter_ms / 1000.0) * sampling_rate)))

    for t in range(num_time_frames):
        for f in range(num_freq_channels):
            # Independent jitter per channel
            jitter = np.random.randint(0, max_jitter_samples + 1)
            new_t = t + jitter
            if 0 <= new_t < num_time_frames:
                neurogram_jittered[new_t, f] = neurogram[t, f]

    return neurogram_jittered


def apply_fiber_loss(neurogram, num_channels_to_remove=None):
    """
    Selective fiber loss: 1–4 randomly selected frequency channels are zeroed.

    Models loss of inner hair cell or auditory nerve fiber populations at
    specific cochlear locations.

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Input neurogram.
    num_channels_to_remove : int or None
        Number of channels to zero. If None, sampled from {1, 2, 3, 4}.

    Returns
    -------
    np.ndarray
        Neurogram with selected channels zeroed.
    """
    if num_channels_to_remove is None:
        num_channels_to_remove = np.random.randint(1, 5)  # 1, 2, 3, or 4

    neurogram_lost = neurogram.copy()
    num_freq_channels = neurogram.shape[1]

    # Ensure we don't try to remove more channels than available
    num_channels_to_remove = min(num_channels_to_remove, num_freq_channels)

    channels_to_remove = np.random.choice(
        num_freq_channels, num_channels_to_remove, replace=False
    )
    neurogram_lost[:, channels_to_remove] = 0.0

    return neurogram_lost


def apply_truncation(neurogram, truncation_ratio=None):
    """
    Amplitude truncation: amplitude limited at α * max(neurogram),
    where α ~ U(0.3, 0.7).

    Models reduced dynamic range of neural responses, as observed in
    auditory neuropathy where neural saturation occurs at lower levels.

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Input neurogram.
    truncation_ratio : float or None
        Ratio of maximum amplitude to use as threshold.
        If None, sampled from U(0.3, 0.7).

    Returns
    -------
    np.ndarray
        Truncated neurogram.
    """
    if truncation_ratio is None:
        truncation_ratio = np.random.uniform(0.3, 0.7)

    neurogram_truncated = neurogram.copy()
    threshold = truncation_ratio * np.max(neurogram)
    neurogram_truncated[neurogram_truncated > threshold] = threshold

    return neurogram_truncated


def apply_random_perturbation(neurogram, sampling_rate=NEUROGRAM_SAMPLING_RATE):
    """
    Apply one of the four perturbation types with equal probability (25% each).

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Input neurogram at 500 Hz.
    sampling_rate : float
        Neurogram sampling rate in Hz.

    Returns
    -------
    perturbed : np.ndarray
        Perturbed neurogram.
    perturbation_type : str
        One of 'jitter', 'scattered_jitter', 'loss', 'truncation'.
    params : dict
        Parameters used for the perturbation.
    """
    perturbation_type = np.random.choice(
        ['jitter', 'scattered_jitter', 'loss', 'truncation']
    )

    params = {}

    if perturbation_type == 'jitter':
        max_jitter_ms = np.random.uniform(3.0, 10.0)
        params['max_jitter_ms'] = max_jitter_ms
        perturbed = apply_uniform_jitter(neurogram, max_jitter_ms, sampling_rate)

    elif perturbation_type == 'scattered_jitter':
        max_jitter_ms = np.random.uniform(3.0, 10.0)
        params['max_jitter_ms'] = max_jitter_ms
        perturbed = apply_scattered_jitter(neurogram, max_jitter_ms, sampling_rate)

    elif perturbation_type == 'loss':
        num_channels = np.random.randint(1, 5)  # 1–4
        params['num_channels_to_remove'] = num_channels
        perturbed = apply_fiber_loss(neurogram, num_channels)

    else:  # truncation
        ratio = np.random.uniform(0.3, 0.7)
        params['truncation_ratio'] = ratio
        perturbed = apply_truncation(neurogram, ratio)

    return perturbed, perturbation_type, params
