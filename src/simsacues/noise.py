"""Cognitive (pink, 1/f) noise added to neurograms (paper Section 2.3).

Previously duplicated in ``asr/data_generators.py`` and
``neurogram/process_ansd_neurograms.py``; the two copies were computationally
identical and are now a single function.
"""

import numpy as np


def add_cognitive_noise(neurogram, snr_db=None):
    """
    Add pink (1/f) noise to a neurogram batch sample.

    Paper: "Cognitive noise was modeled as additive pink noise at 5–15 dB SNR,
    representing neural variability in cortical processing."

    Parameters
    ----------
    neurogram : np.ndarray, shape (time_frames, freq_channels)
        Single neurogram sample.
    snr_db : float or None
        Target SNR in dB. If None, sampled from U(5, 15).

    Returns
    -------
    np.ndarray
        Noisy neurogram, same shape.
    """
    if snr_db is None:
        snr_db = np.random.uniform(5.0, 15.0)

    num_time, num_freq = neurogram.shape

    # Generate 1/f (pink) noise via spectral shaping
    noise = np.random.randn(num_time, num_freq)
    for f_ch in range(num_freq):
        fft_vals = np.fft.rfft(noise[:, f_ch])
        freqs = np.fft.rfftfreq(num_time)
        freqs[0] = 1.0  # avoid div-by-zero at DC
        fft_vals *= 1.0 / np.sqrt(freqs)
        noise[:, f_ch] = np.fft.irfft(fft_vals, n=num_time)

    noise -= np.mean(noise)

    signal_power = np.mean(neurogram ** 2)
    noise_power = np.mean(noise ** 2)
    if noise_power > 0 and signal_power > 0:
        scaling = np.sqrt(signal_power / (noise_power * 10 ** (snr_db / 10)))
        noise *= scaling

    return neurogram + noise
