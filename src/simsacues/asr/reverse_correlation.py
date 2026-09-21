"""
reverse_correlation.py — Template (Misclassification) Analysis

Paper Section 2.8: "For each combination of true phoneme φ, predicted category c,
perturbation type p, and population model m, we compute the confidence-weighted
average neurogram template."

    T(c, φ, p, m) = Σ_i P(c|X_i) · X_i / Σ_i P(c|X_i)

where the sum is over all test neurograms X_i of true phoneme φ that the model m
classified as category c under perturbation p.

Difference templates:
    ΔT = T(c_wrong, φ, p, m) − T(c_correct, φ, p, m)

Red regions = increased activity in misclassified; Blue = decreased.
"""

import os
import json
import numpy as np
from pathlib import Path
from collections import defaultdict

from simsacues.phoneme_categories import CATEGORY_NAMES, PHONEME_TO_CATEGORY_NAME


EXPECTED_TIME_FRAMES = 50
EXPECTED_FREQ_CHANNELS = 150


def pad_or_trim_neurogram(neurogram, target_time=EXPECTED_TIME_FRAMES,
                          target_freq=EXPECTED_FREQ_CHANNELS):
    """Ensure neurogram has consistent dimensions."""
    t, f = neurogram.shape

    # Frequency axis
    if f < target_freq:
        neurogram = np.pad(neurogram, ((0, 0), (0, target_freq - f)))
    elif f > target_freq:
        neurogram = neurogram[:, :target_freq]

    # Time axis (center-crop or pad)
    t = neurogram.shape[0]
    if t < target_time:
        neurogram = np.pad(neurogram, ((0, target_time - t), (0, 0)))
    elif t > target_time:
        start = (t - target_time) // 2
        neurogram = neurogram[start:start + target_time, :]

    return neurogram


def compute_templates(neurograms, metadata, predictions, probabilities,
                      stratify_by_phoneme=True):
    """
    Compute confidence-weighted average templates.

    Paper formula:
      T(c, φ, p, m) = Σ P(c|X_i) · X_i / Σ P(c|X_i)

    Parameters
    ----------
    neurograms : list of np.ndarray
        Test neurograms, each (time, freq).
    metadata : list of dict
        Each dict has keys: 'phoneme', 'category', 'perturbation'.
    predictions : list of str
        Predicted category name for each neurogram.
    probabilities : np.ndarray
        Confidence (max softmax probability) for each prediction.
    stratify_by_phoneme : bool
        If True, compute templates per (perturbation, predicted_category, true_phoneme).
        If False, compute per (perturbation, predicted_category) only.

    Returns
    -------
    dict
        Nested dict: templates[perturbation][predicted_category][true_phoneme] = template
        (If stratify_by_phoneme=False, true_phoneme key is 'all'.)
    """
    templates = {}
    counts = {}

    perturbations = sorted(set(m['perturbation'] for m in metadata))
    categories = CATEGORY_NAMES

    for pert in perturbations:
        templates[pert] = {}
        counts[pert] = {}

        for pred_cat in categories:
            templates[pert][pred_cat] = {}
            counts[pert][pred_cat] = {}

            if stratify_by_phoneme:
                # Group by true phoneme
                phoneme_groups = defaultdict(list)
                for i, m in enumerate(metadata):
                    if m['perturbation'] == pert and predictions[i] == pred_cat:
                        true_phoneme = m['phoneme']
                        phoneme_groups[true_phoneme].append(i)

                for phoneme, indices in phoneme_groups.items():
                    if len(indices) > 0:
                        selected = np.array([neurograms[i] for i in indices])
                        weights = probabilities[indices]
                        weight_sum = np.sum(weights)

                        if weight_sum > 0:
                            template = np.average(
                                selected, axis=0, weights=weights
                            )
                            templates[pert][pred_cat][phoneme] = template
                            counts[pert][pred_cat][phoneme] = len(indices)
            else:
                # Group all true phonemes together
                indices = [
                    i for i, m in enumerate(metadata)
                    if m['perturbation'] == pert and predictions[i] == pred_cat
                ]
                if len(indices) > 0:
                    selected = np.array([neurograms[i] for i in indices])
                    weights = probabilities[np.array(indices)]
                    weight_sum = np.sum(weights)

                    if weight_sum > 0:
                        template = np.average(selected, axis=0, weights=weights)
                        templates[pert][pred_cat]['all'] = template
                        counts[pert][pred_cat]['all'] = len(indices)

    return templates, counts


def compute_difference_templates(templates):
    """
    Compute difference templates: ΔT = T(wrong) − T(correct).

    For each perturbation and each true phoneme, computes the difference
    between misclassified and correctly classified templates.

    Returns
    -------
    dict
        diff_templates[perturbation][true_category][confused_as] = ΔT array
    """
    diff_templates = {}

    for pert in templates:
        diff_templates[pert] = {}

        for true_cat in CATEGORY_NAMES:
            diff_templates[pert][true_cat] = {}

            # Get correctly classified template for this category
            correct_template = templates[pert].get(true_cat, {}).get(true_cat, None)
            if correct_template is None:
                # Try 'all' key if not stratified by phoneme
                correct_template = templates[pert].get(true_cat, {}).get('all', None)

            if correct_template is None:
                continue

            # For each wrong prediction category
            for wrong_cat in CATEGORY_NAMES:
                if wrong_cat == true_cat:
                    continue

                wrong_template = templates[pert].get(wrong_cat, {}).get(true_cat, None)
                if wrong_template is None:
                    wrong_template = templates[pert].get(wrong_cat, {}).get('all', None)

                if wrong_template is not None:
                    diff_templates[pert][true_cat][wrong_cat] = wrong_template - correct_template

    return diff_templates


def save_templates(templates, counts, output_dir, model_name):
    """Save templates to disk."""
    model_dir = Path(output_dir) / model_name
    model_dir.mkdir(parents=True, exist_ok=True)

    for pert in templates:
        pert_dir = model_dir / pert
        pert_dir.mkdir(exist_ok=True)

        for pred_cat in templates[pert]:
            for phoneme_key, template in templates[pert][pred_cat].items():
                filename = f"{pred_cat}_from_{phoneme_key}_template.npy"
                np.save(pert_dir / filename, template)

    # Save metadata
    meta = {
        'model': model_name,
        'perturbations': list(templates.keys()),
        'categories': CATEGORY_NAMES,
        'counts': {
            pert: {
                cat: {ph: int(n) for ph, n in phonemes.items()}
                for cat, phonemes in cats.items()
            }
            for pert, cats in counts.items()
        }
    }
    with open(model_dir / 'metadata.json', 'w') as f:
        json.dump(meta, f, indent=2)

    print(f"Templates saved to {model_dir}")


def compute_confusion_analysis(predictions, metadata):
    """
    Compute full confusion analysis matching paper Section 3.5.

    Returns confusion rates as percentages for each true→predicted pair,
    broken down by perturbation type.
    """
    results = {}

    perturbations = sorted(set(m['perturbation'] for m in metadata))

    for pert in perturbations:
        pert_indices = [i for i, m in enumerate(metadata) if m['perturbation'] == pert]

        confusion = {}
        for true_cat in CATEGORY_NAMES:
            true_indices = [
                i for i in pert_indices
                if metadata[i]['category'] == true_cat
            ]
            if not true_indices:
                continue

            total = len(true_indices)
            confusion[true_cat] = {}
            for pred_cat in CATEGORY_NAMES:
                count = sum(1 for i in true_indices if predictions[i] == pred_cat)
                confusion[true_cat][pred_cat] = round(count / total * 100, 1)

        results[pert] = confusion

    return results
