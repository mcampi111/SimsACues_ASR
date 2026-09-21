"""
test_pipeline.py — Evaluate trained srA1 + srA2 models

Supports:
  1. Matched testing (train/test on same population)
  2. Cross-population transfer (train on one population, test on another)
  3. Perturbation-specific testing (test ANSD models per mechanism)

Computes:
  - srA1-only accuracy (srA1)
  - Full pipeline accuracy (srA2)
  - Hierarchical benefit (Δ = srA2 − srA1)
  - Confusion matrices
  - Category-specific accuracies
  - Bootstrap 95% CIs (10,000 resamples, percentile method)
  - McNemar's test for category-specific srA1 vs srA2 differences
  - Per-perturbation accuracy breakdown

Paper references: Section 2.7, Tables 2–5
"""

import os
import json
import numpy as np
import tensorflow as tf
from collections import Counter
from scipy import stats

from simsacues.asr.srA1 import build_srA1
from simsacues.asr.srA2 import build_srA2
from simsacues.phoneme_categories import CATEGORY_NAMES, NUM_CATEGORIES


# ============================================================================
# STATISTICAL TESTS
# ============================================================================

def bootstrap_ci(y_true, y_pred, n_bootstrap=10000, ci=0.95):
    """
    Compute bootstrap confidence interval for accuracy.

    Paper (Section 2.7): "Bootstrap 95% CIs with 10,000 resamples, percentile method."
    """
    n = len(y_true)
    accuracies = np.zeros(n_bootstrap)
    for i in range(n_bootstrap):
        idx = np.random.choice(n, n, replace=True)
        accuracies[i] = np.mean(y_true[idx] == y_pred[idx])
    lower = np.percentile(accuracies, (1 - ci) / 2 * 100)
    upper = np.percentile(accuracies, (1 + ci) / 2 * 100)
    return lower, upper


def mcnemar_test(y_true, preds_A, preds_B):
    """
    McNemar's test comparing two classifiers on the same data.

    Paper (Section 2.7): "McNemar's test for category-specific differences
    between srA1 and srA2 classifiers."

    Constructs a 2×2 contingency table:
        - b: A correct, B wrong
        - c: A wrong, B correct
    Under H0 (no difference), b and c are equally likely.

    Parameters
    ----------
    y_true : np.ndarray
        True labels.
    preds_A : np.ndarray
        Predictions from classifier A (e.g., srA1).
    preds_B : np.ndarray
        Predictions from classifier B (e.g., srA2).

    Returns
    -------
    statistic : float
        McNemar chi-squared statistic (with continuity correction).
    p_value : float
        Two-sided p-value.
    contingency : dict
        The four cells of the contingency table.
    """
    correct_A = (preds_A == y_true)
    correct_B = (preds_B == y_true)

    # Contingency table
    b = np.sum(correct_A & ~correct_B)   # A right, B wrong
    c = np.sum(~correct_A & correct_B)   # A wrong, B right

    contingency = {
        'both_correct': int(np.sum(correct_A & correct_B)),
        'A_correct_B_wrong': int(b),
        'A_wrong_B_correct': int(c),
        'both_wrong': int(np.sum(~correct_A & ~correct_B)),
    }

    # McNemar's test with continuity correction
    if b + c == 0:
        return 0.0, 1.0, contingency

    statistic = (abs(b - c) - 1) ** 2 / (b + c)
    p_value = 1.0 - stats.chi2.cdf(statistic, df=1)

    return float(statistic), float(p_value), contingency


def mcnemar_category_specific(y_true, preds_A, preds_B):
    """
    Run McNemar's test per phoneme category.

    For each category, tests whether srA1 and srA2 differ in their ability
    to correctly classify samples of that category.

    Returns
    -------
    dict
        Per-category results with statistic, p-value, and contingency table.
    """
    results = {}
    for cat_idx, cat_name in enumerate(CATEGORY_NAMES):
        mask = (y_true == cat_idx)
        if mask.sum() < 2:
            continue

        # For this category: "correct" = predicted this category when true
        cat_preds_A = (preds_A[mask] == cat_idx)
        cat_preds_B = (preds_B[mask] == cat_idx)

        b = np.sum(cat_preds_A & ~cat_preds_B)
        c = np.sum(~cat_preds_A & cat_preds_B)

        if b + c == 0:
            stat, p = 0.0, 1.0
        else:
            stat = (abs(b - c) - 1) ** 2 / (b + c)
            p = 1.0 - stats.chi2.cdf(stat, df=1)

        results[cat_name] = {
            'statistic': float(stat),
            'p_value': float(p),
            'n_samples': int(mask.sum()),
            'A_correct_B_wrong': int(b),
            'A_wrong_B_correct': int(c),
            'significant_0.05': p < 0.05,
            'significant_0.01': p < 0.01,
        }

    return results


# ============================================================================
# CONFUSION MATRIX
# ============================================================================

def compute_confusion_matrix(y_true, y_pred, num_classes=NUM_CATEGORIES):
    """Compute confusion matrix (rows=true, cols=predicted)."""
    cm = np.zeros((num_classes, num_classes), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1
    return cm


def confusion_matrix_to_percentages(cm):
    """Convert confusion matrix to row-normalized percentages."""
    row_sums = cm.sum(axis=1, keepdims=True)
    row_sums[row_sums == 0] = 1
    return cm / row_sums * 100


# ============================================================================
# MODEL INFERENCE
# ============================================================================

def run_srA1_inference(model, X, Y, batch_size=32, num_timesteps=50):
    """
    Run srA1 inference on test data.

    Returns predictions (probabilities), predicted classes, and true labels
    for all valid time indices.
    """
    valid_indices = np.arange(num_timesteps - 1, len(X))

    all_probs = []
    all_labels = []

    for start in range(0, len(valid_indices), batch_size):
        batch_idx = valid_indices[start:start + batch_size]
        batch_X = np.zeros((len(batch_idx), num_timesteps, X.shape[1]))
        batch_Y = []

        for j, idx in enumerate(batch_idx):
            batch_X[j] = X[idx - num_timesteps + 1:idx + 1]
            batch_Y.append(Y[idx])

        preds = model.predict(batch_X, verbose=0)
        all_probs.append(preds)
        all_labels.extend(batch_Y)

    probs = np.concatenate(all_probs, axis=0)
    labels = np.array(all_labels, dtype=int)
    pred_classes = np.argmax(probs, axis=1)

    return probs, pred_classes, labels


def run_srA2_inference(model, srA1_probs, labels, batch_size=32,
                       time_window=305):
    """
    Run srA2 inference on srA1 log-probability outputs.
    """
    logprobs = np.log(srA1_probs + 1e-8)
    non_causal = time_window // 2

    valid_indices = np.arange(non_causal, len(logprobs) - non_causal)
    valid_indices = valid_indices[valid_indices < len(labels)]

    all_preds = []
    all_labels = []

    for start in range(0, len(valid_indices), batch_size):
        batch_idx = valid_indices[start:start + batch_size]
        batch_X = np.zeros((len(batch_idx), time_window, srA1_probs.shape[1]))
        batch_Y = []

        for j, idx in enumerate(batch_idx):
            t_start = idx - non_causal
            t_end = t_start + time_window
            if t_end <= len(logprobs):
                batch_X[j] = logprobs[t_start:t_end]
                batch_Y.append(labels[idx])

        if batch_Y:
            batch_X = batch_X[:len(batch_Y)]
            preds = model.predict(batch_X, verbose=0)
            all_preds.append(preds)
            all_labels.extend(batch_Y)

    if not all_preds:
        return None, None, None

    probs = np.concatenate(all_preds, axis=0)
    labs = np.array(all_labels, dtype=int)
    pred_classes = np.argmax(probs, axis=1)

    return probs, pred_classes, labs


# ============================================================================
# PER-PERTURBATION ANALYSIS
# ============================================================================

def load_perturbation_indices(perturbation_map_path, test_file_list_path=None):
    """
    Load perturbation type assignments and build index-to-perturbation mapping.

    The perturbation map JSON maps filenames to perturbation types. The test
    file list (one filename per line, or a .npy of filenames) maps test sample
    indices to filenames.

    If no file list is provided, assumes the perturbation map keys are ordered
    alphabetically to match the standard TIMIT traversal order.

    Parameters
    ----------
    perturbation_map_path : str
        Path to perturbation_types.json (filename → perturbation type).
    test_file_list_path : str or None
        Path to file listing test filenames in order. If None, uses sorted
        keys from the perturbation map.

    Returns
    -------
    np.ndarray of str
        Perturbation type for each test sample index.
    """
    with open(perturbation_map_path) as f:
        pert_map = json.load(f)

    if test_file_list_path is not None:
        if test_file_list_path.endswith('.npy'):
            filenames = np.load(test_file_list_path, allow_pickle=True)
        else:
            with open(test_file_list_path) as f:
                filenames = [line.strip() for line in f]
        return np.array([pert_map.get(fn, 'unknown') for fn in filenames])
    else:
        sorted_files = sorted(pert_map.keys())
        return np.array([pert_map[fn] for fn in sorted_files])


def perturbation_specific_evaluation(y_true, y_pred, pert_labels,
                                     stage_name='srA1'):
    """
    Compute accuracy per perturbation type with bootstrap CIs.

    Parameters
    ----------
    y_true : np.ndarray
        True labels.
    y_pred : np.ndarray
        Predicted labels.
    pert_labels : np.ndarray
        Perturbation type string for each sample.
    stage_name : str
        Label for printing (e.g., 'srA1', 'pipeline').

    Returns
    -------
    dict
        Per-perturbation results.
    """
    results = {}
    perturbation_types = sorted(set(pert_labels))

    for pert in perturbation_types:
        if pert == 'unknown':
            continue
        mask = (pert_labels == pert)
        n = mask.sum()
        if n < 10:
            continue

        acc = np.mean(y_true[mask] == y_pred[mask])
        ci = bootstrap_ci(y_true[mask], y_pred[mask], n_bootstrap=10000)

        results[pert] = {
            'accuracy': float(acc),
            'ci_95': [float(ci[0]), float(ci[1])],
            'n_samples': int(n),
        }
        print(f"    {pert:20s}: {stage_name} acc={acc:.3f} "
              f"[{ci[0]:.3f}, {ci[1]:.3f}] (N={n:,})")

    return results


# ============================================================================
# MAIN EVALUATION
# ============================================================================

def evaluate_model_pair(srA1_weights, srA2_weights, X_test_path, Y_test_path,
                        output_dir, condition_name='test',
                        perturbation_map_path=None,
                        test_file_list_path=None):
    """
    Full evaluation of an srA1 + srA2 model pair.

    Parameters
    ----------
    srA1_weights : str
        Path to srA1 .h5 weights.
    srA2_weights : str
        Path to srA2 .h5 weights.
    X_test_path : str
        Path to test neurogram features .npy.
    Y_test_path : str
        Path to test 9-category labels .npy.
    output_dir : str
        Output directory for results.
    condition_name : str
        Name for this test condition (e.g., 'healthy_silence_matched').
    perturbation_map_path : str or None
        Path to perturbation_types.json for per-perturbation analysis.
    test_file_list_path : str or None
        Path to ordered test filename list (for perturbation index mapping).
    """
    os.makedirs(output_dir, exist_ok=True)

    # Load test data
    X_test = np.load(X_test_path)
    Y_test = np.load(Y_test_path)
    print(f"Test data: X={X_test.shape}, Y={Y_test.shape}")

    # Build and load srA1
    tf.keras.backend.clear_session()
    srA1 = build_srA1(input_shape=(50, X_test.shape[1]), num_classes=NUM_CATEGORIES)
    srA1.load_weights(srA1_weights)
    print(f"Loaded srA1: {srA1_weights}")

    # Build and load srA2
    srA2 = build_srA2(input_shape=(305, NUM_CATEGORIES), num_classes=NUM_CATEGORIES)
    srA2.load_weights(srA2_weights)
    print(f"Loaded srA2: {srA2_weights}")

    # --- srA1 evaluation ---
    print("\nRunning srA1 inference...")
    srA1_probs, srA1_preds, srA1_labels = run_srA1_inference(
        srA1, X_test, Y_test, batch_size=32, num_timesteps=50
    )
    srA1_acc = np.mean(srA1_preds == srA1_labels)
    srA1_ci = bootstrap_ci(srA1_labels, srA1_preds)
    print(f"srA1 accuracy: {srA1_acc:.3f} [{srA1_ci[0]:.3f}, {srA1_ci[1]:.3f}]")

    # --- srA2 evaluation ---
    print("\nRunning srA2 inference...")
    srA2_probs, srA2_preds, srA2_labels = run_srA2_inference(
        srA2, srA1_probs, srA1_labels, batch_size=32, time_window=305
    )

    if srA2_preds is not None:
        srA2_acc = np.mean(srA2_preds == srA2_labels)
        srA2_ci = bootstrap_ci(srA2_labels, srA2_preds)
        hierarchical_delta = (srA2_acc - srA1_acc) * 100
        print(f"srA2 accuracy: {srA2_acc:.3f} [{srA2_ci[0]:.3f}, {srA2_ci[1]:.3f}]")
        print(f"Hierarchical benefit: {hierarchical_delta:+.1f} pp")
    else:
        srA2_acc = 0.0
        srA2_ci = (0.0, 0.0)
        hierarchical_delta = -srA1_acc * 100
        print("srA2 inference failed")

    # --- McNemar's test: overall srA1 vs srA2 ---
    mcnemar_results = {}
    if srA2_preds is not None:
        # srA2 operates on a subset of srA1 samples (shorter due to context
        # window). Align by taking the last N srA1 predictions, where N is
        # the number of srA2 predictions.
        n_srA2 = len(srA2_labels)
        srA1_preds_aligned = srA1_preds[-n_srA2:]

        stat, p, contingency = mcnemar_test(
            srA2_labels, srA1_preds_aligned, srA2_preds
        )
        print(f"\nMcNemar's test (srA1 vs srA2): chi2={stat:.2f}, p={p:.4f}")
        mcnemar_results['overall'] = {
            'statistic': stat, 'p_value': p, 'contingency': contingency,
        }

        # Per-category McNemar's
        print("\nMcNemar's test per category (srA1 vs srA2):")
        cat_mcnemar = mcnemar_category_specific(
            srA2_labels, srA1_preds_aligned, srA2_preds
        )
        for cat_name, res in cat_mcnemar.items():
            sig = '**' if res['significant_0.01'] else ('*' if res['significant_0.05'] else '')
            print(f"  {cat_name:12s}: chi2={res['statistic']:6.2f}  "
                  f"p={res['p_value']:.4f} {sig:3s}  "
                  f"(b={res['A_correct_B_wrong']}, c={res['A_wrong_B_correct']})")
        mcnemar_results['per_category'] = cat_mcnemar

    # --- Category-specific accuracy ---
    print("\nCategory-specific accuracy (srA1 / srA2):")
    category_results = {}
    for cat_idx, cat_name in enumerate(CATEGORY_NAMES):
        mask1 = srA1_labels == cat_idx
        cat_acc1 = np.mean(srA1_preds[mask1] == cat_idx) if mask1.sum() > 0 else 0.0

        if srA2_preds is not None:
            mask2 = srA2_labels == cat_idx
            cat_acc2 = np.mean(srA2_preds[mask2] == cat_idx) if mask2.sum() > 0 else 0.0
        else:
            cat_acc2 = 0.0

        category_results[cat_name] = {
            'srA1_acc': float(cat_acc1),
            'srA2_acc': float(cat_acc2),
            'n_samples': int(mask1.sum())
        }
        print(f"  {cat_name:12s}: srA1={cat_acc1:.3f}  srA2={cat_acc2:.3f}  "
              f"(N={mask1.sum():,})")

    # --- Confusion matrices ---
    cm_srA1 = compute_confusion_matrix(srA1_labels, srA1_preds)
    cm_srA1_pct = confusion_matrix_to_percentages(cm_srA1)

    # --- Per-perturbation analysis ---
    perturbation_results = {}
    if perturbation_map_path and os.path.exists(perturbation_map_path):
        print("\nPer-perturbation analysis:")
        pert_labels = load_perturbation_indices(
            perturbation_map_path, test_file_list_path
        )

        # Align perturbation labels to srA1 output indices.
        # srA1 valid indices start at (num_timesteps - 1), so the first
        # num_timesteps - 1 samples in the original data have no prediction.
        num_timesteps = 50
        if len(pert_labels) > len(srA1_labels):
            pert_srA1 = pert_labels[
                num_timesteps - 1:num_timesteps - 1 + len(srA1_labels)
            ]
        elif len(pert_labels) == len(srA1_labels):
            pert_srA1 = pert_labels
        else:
            # If perturbation labels are fewer, pad with 'unknown'
            pert_srA1 = np.concatenate([
                pert_labels,
                np.array(['unknown'] * (len(srA1_labels) - len(pert_labels)))
            ])

        print("  srA1:")
        perturbation_results['srA1'] = perturbation_specific_evaluation(
            srA1_labels, srA1_preds, pert_srA1, stage_name='srA1'
        )

        if srA2_preds is not None:
            pert_srA2 = pert_srA1[-len(srA2_labels):]
            print("  srA2 (pipeline):")
            perturbation_results['srA2'] = perturbation_specific_evaluation(
                srA2_labels, srA2_preds, pert_srA2, stage_name='pipeline'
            )

    # --- Compile and save results ---
    results = {
        'condition': condition_name,
        'srA1_accuracy': float(srA1_acc),
        'srA1_ci_95': [float(srA1_ci[0]), float(srA1_ci[1])],
        'srA2_accuracy': float(srA2_acc),
        'srA2_ci_95': [float(srA2_ci[0]), float(srA2_ci[1])],
        'hierarchical_delta_pp': float(hierarchical_delta),
        'n_test_samples': int(len(srA1_labels)),
        'category_results': category_results,
        'srA1_confusion_matrix_pct': cm_srA1_pct.tolist(),
    }

    if mcnemar_results:
        results['mcnemar_tests'] = mcnemar_results
    if perturbation_results:
        results['perturbation_results'] = perturbation_results

    # Save arrays
    np.save(os.path.join(output_dir, f'{condition_name}_srA1_cm.npy'), cm_srA1)
    np.save(os.path.join(output_dir, f'{condition_name}_srA1_preds.npy'), srA1_preds)
    np.save(os.path.join(output_dir, f'{condition_name}_srA1_probs.npy'), srA1_probs)
    np.save(os.path.join(output_dir, f'{condition_name}_srA1_labels.npy'), srA1_labels)

    if srA2_preds is not None:
        cm_srA2 = compute_confusion_matrix(srA2_labels, srA2_preds)
        np.save(os.path.join(output_dir, f'{condition_name}_srA2_cm.npy'), cm_srA2)
        np.save(os.path.join(output_dir, f'{condition_name}_srA2_preds.npy'), srA2_preds)
        np.save(os.path.join(output_dir, f'{condition_name}_srA2_labels.npy'), srA2_labels)
        results['srA2_confusion_matrix_pct'] = \
            confusion_matrix_to_percentages(cm_srA2).tolist()

    with open(os.path.join(output_dir, f'{condition_name}_results.json'), 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to {output_dir}/{condition_name}_results.json")
    return results


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Evaluate srA1+srA2 pipeline')
    parser.add_argument('--srA1-weights', type=str, required=True)
    parser.add_argument('--srA2-weights', type=str, required=True)
    parser.add_argument('--x-test', type=str, required=True)
    parser.add_argument('--y-test', type=str, required=True)
    parser.add_argument('--output-dir', type=str, required=True)
    parser.add_argument('--condition', type=str, default='test')
    parser.add_argument('--perturbation-map', type=str, default=None,
                        help='Path to perturbation_types.json')
    parser.add_argument('--test-file-list', type=str, default=None,
                        help='Ordered test filenames for perturbation mapping')
    args = parser.parse_args()

    evaluate_model_pair(
        args.srA1_weights, args.srA2_weights,
        args.x_test, args.y_test,
        args.output_dir, args.condition,
        args.perturbation_map, args.test_file_list
    )
