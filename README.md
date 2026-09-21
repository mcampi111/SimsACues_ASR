# Which phonetic contrasts recover information lost to aggregate speech scoring in auditory nerve disorders: a computational framework

Code for: *"Which phonetic contrasts recover information lost to aggregate speech scoring in auditory nerve disorders: a computational framework"*

> **Version used in the manuscript.** The exact code submitted with the paper is
> preserved under the tag [`plos-submission`](https://github.com/mcampi111/SimsACues_ASR/tree/plos-submission).
> The `main` branch has since been restructured into an installable, tested package;
> the refactor does not change any result (see *Tests* below).

## Project Structure

```
SimsACues_ASR/
├── src/simsacues/
│   ├── phoneme_categories.py        # TIMIT → 9-category mapping (Table A4)
│   ├── noise.py                     # Cognitive (pink) noise (Section 2.3)
│   ├── asr/                         # Speech recognition pipeline
│   │   ├── data_generators.py       # Training data generators
│   │   ├── losses.py                # Focal loss (shared by srA1/srA2)
│   │   ├── srA1.py                  # Stage 1: causal classifier (Section 2.6)
│   │   ├── srA2.py                  # Stage 2: hierarchical classifier (Section 2.6)
│   │   ├── test_pipeline.py         # Evaluation: matched, cross-pop, per-perturbation
│   │   └── reverse_correlation.py   # Template/misclassification analysis (Section 2.8)
│   ├── neurogram/                   # Neurogram perturbation
│   │   ├── perturbations.py         # Four ANSD perturbation types (Section 2.2)
│   │   └── process_ansd_neurograms.py  # Batch processing pipeline for HPC
│   └── ot/
│       └── optimal_transport.py     # GW distance: DTW + wPEW (Section 2.5)
├── matlab/
│   └── generate_neurograms.m        # Zilany2014 AN model (Section 2.1)
├── tests/                           # Test suite (see below)
├── pyproject.toml
└── README.md
```

## Installation

```bash
git clone https://github.com/mcampi111/SimsACues_ASR.git
cd SimsACues_ASR
pip install -e ".[asr,dev]"      # drop "asr" if you do not need TensorFlow
```

The neurogram generator (`matlab/generate_neurograms.m`) requires MATLAB and
AMToolbox v1.6.0; everything else is pure Python.

## Tests

```bash
pytest
```

The optimal-transport module is tested end to end against the original
implementation, kept unchanged in `tests/reference/`: the refactored code must
produce the same GW distance table and the same statistical output. Perturbations
and cognitive noise are tested for their documented behaviour (shape, target SNR,
channel counts, truncation threshold, reproducibility under a fixed seed). The ASR
tests build both models and are skipped when TensorFlow is not installed.

## Key Parameters (Paper ↔ Code Correspondence)

### Neurogram Generation (Section 2.1)
- Zilany 2014 model: 150 log-spaced CFs (125 Hz – 10 kHz)
- Fiber type: high-SR (100 sp/s), fiberType=3
- Stimulus level: 65 dB SPL
- Model sampling rate: 100 kHz → downsampled to 500 Hz (2 ms bins)
- **Implemented in**: `matlab/generate_neurograms.m`
  - `generate_neurograms(task_id, num_tasks, true)` → noisy (WHAM! mixed)
  - `generate_neurograms(task_id, num_tasks, false)` → clean (silence condition)

### ANSD Perturbations (Section 2.2)
- **Uniform jitter**: a maximum displacement *J* ~ U(3, 10) ms is drawn per neurogram and
  converted to *K* = round(*J* / 2 ms) samples (*K* ∈ {2, …, 5}); each time frame is then
  shifted forward by an independent integer δ_t ~ U{0, …, *K*} samples, identical across all
  channels
- **Scattered jitter**: the same procedure with δ_{t,f} drawn independently per channel
  (temporal only)
- Because displacements are independent across frames, shifted frames can overwrite one another
  and some positions receive no frame and stay silent. Jitter therefore combines temporal
  desynchronisation with a loss of neural activity — roughly a third of frames are left silent
  on synthetic input — in line with the view of auditory neuropathy as desynchronised and/or
  reduced auditory-nerve activity (Zeng et al., 2005, *J Neurophysiol* 93:3050). At the 2 ms
  resolution of the neurogram, displacements act on the temporal envelope rather than on
  temporal fine structure, which waveform-level simulations jitter at sub-millisecond scale
  (Pichora-Fuller et al., 2007, *Hear Res* 223:114).
- **Fiber loss**: 1–4 randomly selected channels zeroed
- **Truncation**: amplitude capped at α·max, α ~ U(0.3, 0.7)
- Equal probability assignment (25% each)
- **CRITICAL**: sampling_rate = 500 Hz (neurogram rate, not audio rate)
- **Implemented in**: `src/simsacues/neurogram/perturbations.py`

### Cognitive Noise (Section 2.3)
- Pink (1/f) noise via spectral shaping
- SNR: U(5, 15) dB
- Applied during training data generation
- **Implemented in**: `src/simsacues/noise.py`

### ASR Architecture (Section 2.6, Appendix A)

**srA1 (Stage 1 — Causal)**
- Input: (50, 150) = 100 ms × 150 CFs
- 3 GRU layers (128 units each), unidirectional
- Residual connection between GRU1 and GRU2
- Multi-head attention: 4 heads, key_dim=32
- Dense: 256 → 128 with skip connection
- Expected parameters: 456,073

**srA2 (Stage 2 — Hierarchical)**
- Input: (305, 9) = 610 ms × 9 log-probabilities from srA1
- 3 BiGRU layers (192, 192, 128 units)
- Residual connection between BiGRU1 and BiGRU2
- Multi-head attention: 6 heads, key_dim=64
- Dense: 512 → 256 → 128 with skip connection
- Expected parameters: 405,513

**Training (both stages)**
- Focal loss: γ=2.0, α=0.25
- Adam: lr=1e-3, gradient clipping at 1.0
- Batch size: 32
- Early stopping: patience 20 (val_categorical_accuracy)
- LR reduction: factor 0.5, patience 10

### Four Training Configurations (Section 2.4)
1. **Healthy-Silence**: clean neurograms, no environmental noise
2. **Healthy-Noise**: clean neurograms + WHAM! noise (0–20 dB SNR)
3. **ANSD-Silence**: perturbed neurograms, no environmental noise
4. **ANSD-Noise**: perturbed neurograms + WHAM! noise (0–20 dB SNR)

### Optimal Transport (Section 2.5)
- **Formant space**: DTW distance on z-normalized trajectories
- **Neurogram space**: wPEW distance on FULL 150-channel neurograms
  - 5×5 neighborhood window
  - Exponential weighting from center
- **GW coupling**: entropic regularization
  - ε = 0.01
  - Max 100 outer iterations (tol 1e-6)
  - 100 Sinkhorn iterations (tol 1e-8)
- Distance matrices normalized by maximum values
- N: 100–500 samples per category
- **Implemented in**: `src/simsacues/ot/optimal_transport.py`

### Template Analysis (Section 2.8)
- Confidence-weighted averaging: T = Σ P(c|X_i)·X_i / Σ P(c|X_i)
- Stratified by: perturbation × predicted category × true phoneme
- Difference templates: ΔT = T(wrong) − T(correct)
- **Implemented in**: `src/simsacues/asr/reverse_correlation.py`

### Statistical Methods (Section 2.7)
- Bootstrap 95% CIs: 10,000 resamples, percentile method
- McNemar's test (with continuity correction) for category-specific srA1 vs srA2 differences
- Kruskal-Wallis H test for GW distance comparisons across perturbation types
- Post-hoc pairwise Mann-Whitney U tests
- **Implemented in**: `src/simsacues/asr/test_pipeline.py` (McNemar's, bootstrap), `src/simsacues/ot/optimal_transport.py` (Kruskal-Wallis)

## Dataset
- TIMIT corpus (LDC93S1): 462 train / 168 test speakers
- Training: 95,891 phoneme tokens
- Test: 10,731 phoneme tokens
- WHAM! noise: http://wham.whisper.ai/
- Formant extraction: Shrem et al. (2022) deep learning method

## Trained Model Weights

Pre-trained weights are not included in this repository due to file size.
They can be made available on request. The expected directory layout is:

```
results/
├── healthy/
│   ├── silence/          # Healthy-Silence configuration
│   │   ├── srA1_best.h5
│   │   └── srA2_best.h5
│   └── noise/            # Healthy-Noise configuration
│       ├── srA1_best.h5
│       └── srA2_best.h5
├── ansd/
│   ├── silence/          # ANSD-Silence configuration
│   │   ├── srA1_best.h5
│   │   └── srA2_best.h5
│   └── noise/            # ANSD-Noise configuration
│       ├── srA1_best.h5
│       └── srA2_best.h5
└── perturbation_testing/ # Per-mechanism evaluation outputs
```

To train from scratch, run `srA1.py` then `srA2.py` for each of the four
configurations. See `test_pipeline.py` for matched, cross-population, and
per-perturbation evaluation.

## Reproducibility

The AMToolbox version used for neurogram generation is v1.6.0. The `fiberType=3`
parameter corresponds to high spontaneous-rate fibers (~100 spikes/s).

MATLAB R2023a was used for neurogram generation. Python 3.10 with
TensorFlow 2.12 was used for ASR training and evaluation.
