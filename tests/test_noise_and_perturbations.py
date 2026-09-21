"""Behavioural tests for cognitive noise and the neurogram perturbations."""

import numpy as np
import pytest

from simsacues.noise import add_cognitive_noise
from simsacues.neurogram.perturbations import (
    apply_fiber_loss,
    apply_random_perturbation,
    apply_scattered_jitter,
    apply_truncation,
    apply_uniform_jitter,
)


@pytest.fixture
def neurogram():
    return np.random.default_rng(0).random((120, 150)) + 0.1


@pytest.mark.parametrize("snr_db", [5.0, 10.0, 15.0])
def test_cognitive_noise_hits_target_snr(neurogram, snr_db):
    np.random.seed(1)
    noisy = add_cognitive_noise(neurogram, snr_db)
    noise = noisy - neurogram
    measured = 10 * np.log10(np.mean(neurogram**2) / np.mean(noise**2))
    assert measured == pytest.approx(snr_db, abs=1e-6)


def test_cognitive_noise_preserves_shape(neurogram):
    assert add_cognitive_noise(neurogram).shape == neurogram.shape


@pytest.mark.parametrize(
    "perturb",
    [apply_uniform_jitter, apply_scattered_jitter, apply_fiber_loss, apply_truncation],
)
def test_perturbations_preserve_shape(neurogram, perturb):
    np.random.seed(2)
    assert perturb(neurogram).shape == neurogram.shape


@pytest.mark.parametrize("k", [1, 2, 3, 4])
def test_fiber_loss_zeroes_exactly_k_channels(neurogram, k):
    np.random.seed(3)
    out = apply_fiber_loss(neurogram, k)
    zeroed = np.where(np.all(out == 0, axis=0))[0]
    assert len(zeroed) == k
    untouched = np.setdiff1d(np.arange(neurogram.shape[1]), zeroed)
    np.testing.assert_array_equal(out[:, untouched], neurogram[:, untouched])


@pytest.mark.parametrize("ratio", [0.3, 0.5, 0.7])
def test_truncation_caps_at_ratio_of_max(neurogram, ratio):
    out = apply_truncation(neurogram, ratio)
    assert out.max() == pytest.approx(ratio * neurogram.max())
    below = neurogram <= ratio * neurogram.max()
    np.testing.assert_array_equal(out[below], neurogram[below])


def test_random_perturbation_is_reproducible_with_seed(neurogram):
    np.random.seed(4)
    a, type_a, params_a = apply_random_perturbation(neurogram)
    np.random.seed(4)
    b, type_b, params_b = apply_random_perturbation(neurogram)
    np.testing.assert_array_equal(a, b)
    assert (type_a, params_a) == (type_b, params_b)


def test_perturbation_types_are_balanced():
    np.random.seed(5)
    tiny = np.ones((4, 4))
    counts = {}
    for _ in range(4000):
        _, kind, _ = apply_random_perturbation(tiny)
        counts[kind] = counts.get(kind, 0) + 1
    assert set(counts) == {"jitter", "scattered_jitter", "loss", "truncation"}
    for n in counts.values():
        assert n / 4000 == pytest.approx(0.25, abs=0.03)
