"""
optimal_transport.py — Gromov-Wasserstein analysis of formant–neurogram coupling

Paper Section 2.5: Optimal Transport Framework

Distance functions:
  - Formant space: DTW (Dynamic Time Warping) for formant trajectories
  - Neurogram space: wPEW (weighted Persistent Entropy-based Wasserstein)
    with 5×5 neighborhood windows and exponential weighting
  - Coupling: Gromov-Wasserstein distance with entropic regularization

Key parameters (from paper):
  - wPEW neighborhood: 5×5 (time × frequency)
  - wPEW weighting: exponential decay from center
  - GW entropic regularization: ε = 0.01
  - GW max outer iterations: 100 (tolerance 1e-6)
  - GW Sinkhorn iterations: 100 (tolerance 1e-8)
  - Distance matrices normalized by maximum values
  - Sample sizes N: 100–500 per phoneme category

CRITICAL: All 150 frequency channels are used. No downsampling to 6 channels.
"""

import json
import numpy as np
import ot
from dtaidistance import dtw
from scipy import stats
import pandas as pd


# ============================================================================
# DISTANCE FUNCTIONS
# ============================================================================

def _weighted_persistence_map(neurogram, kernel, half_w):
    """
    Kernel-weighted squared deviation of each point's in-bounds neighbours
    from the point itself.

    Equivalent to looping over every (t, f) and summing
    ``kernel * (window - centre) ** 2`` over the cropped window, but computed
    by accumulating one shifted copy of the array per kernel offset. The
    result is returned in the dtype of the input, as in the original loop,
    which wrote each value into an array created with ``np.zeros_like``.
    """
    x = np.asarray(neurogram)
    xf = x.astype(np.float64)
    time_frames, freq_channels = x.shape
    padded = np.pad(xf, half_w, mode='constant')
    inside = np.pad(np.ones((time_frames, freq_channels)), half_w, mode='constant')
    acc = np.zeros((time_frames, freq_channels), dtype=np.float64)
    size = kernel.shape[0]
    for i in range(size):
        for j in range(size):
            rows = slice(i, i + time_frames)
            cols = slice(j, j + freq_channels)
            acc += kernel[i, j] * inside[rows, cols] * (padded[rows, cols] - xf) ** 2
    return acc.astype(x.dtype, copy=False)


def wpew_neurogram_distance(neurogram1, neurogram2, neighborhood_size=5):
    """
    Weighted Persistent Entropy-based Wasserstein (wPEW) distance for neurograms.

    Paper: "The wPEW distance operates on the full 150-channel neurogram
    representation. For each time-frequency point (t, f), a 5×5 neighborhood
    window is defined. Within this window, exponentially-weighted persistence
    is computed."

    With 150 log-spaced channels, a 5-channel window spans approximately
    1–2 critical bands, consistent with auditory filter bandwidth.

    Parameters
    ----------
    neurogram1, neurogram2 : np.ndarray, shape (time_frames, 150)
        Full 150-channel neurograms.
    neighborhood_size : int
        Size of the neighborhood window. Default 5 (as per paper).

    Returns
    -------
    float
        wPEW distance between the two neurograms.
    """
    if neurogram1.shape != neurogram2.shape:
        return np.inf

    if neurogram1.ndim != 2:
        return np.inf

    time_frames, freq_channels = neurogram1.shape
    half_w = neighborhood_size // 2

    # Pre-compute exponential weight kernel
    t_range = np.arange(neighborhood_size) - half_w
    f_range = np.arange(neighborhood_size) - half_w
    # Exponential weighting based on distance from center
    kernel = np.exp(-0.5 * (t_range[:, None] ** 2 + f_range[None, :] ** 2))

    # Compute persistence maps for both neurograms (vectorised; see
    # _weighted_persistence_map -- numerically identical to the point-by-point loop)
    persistence1 = _weighted_persistence_map(neurogram1, kernel, half_w)
    persistence2 = _weighted_persistence_map(neurogram2, kernel, half_w)

    # Normalize persistence maps to [0, 1]
    def normalize(arr):
        mn, mx = arr.min(), arr.max()
        if mx - mn > 1e-10:
            return (arr - mn) / (mx - mn)
        return np.zeros_like(arr)

    persistence1 = normalize(persistence1)
    persistence2 = normalize(persistence2)

    # Distance between persistence patterns
    return np.mean((persistence1 - persistence2) ** 2)


def dtw_formant_distance(traj1, traj2):
    """
    DTW distance for formant trajectories.

    Paper: "Formant trajectories were compared using Dynamic Time Warping (DTW),
    which accommodates temporal variability in speech production."

    Trajectories are z-score normalized before comparison.

    Parameters
    ----------
    traj1, traj2 : array-like
        1D formant frequency trajectories over time.

    Returns
    -------
    float
        DTW distance.
    """
    traj1 = np.array(traj1).flatten()
    traj2 = np.array(traj2).flatten()

    # Remove NaN values
    traj1 = traj1[~np.isnan(traj1)]
    traj2 = traj2[~np.isnan(traj2)]

    if len(traj1) == 0 or len(traj2) == 0:
        return np.inf

    # Z-score normalization
    def zscore(x):
        mu, sigma = np.mean(x), np.std(x)
        return (x - mu) / sigma if sigma > 1e-10 else x - mu

    traj1 = zscore(traj1)
    traj2 = zscore(traj2)

    try:
        return dtw.distance(traj1, traj2)
    except Exception:
        # Fallback: Euclidean on truncated/padded
        n = min(len(traj1), len(traj2))
        return float(np.sqrt(np.mean((traj1[:n] - traj2[:n]) ** 2)))


# ============================================================================
# GROMOV-WASSERSTEIN COMPUTATION
# ============================================================================

def compute_gw_distance(formant_dist_matrix, neurogram_dist_matrix):
    """
    Compute Gromov-Wasserstein distance between formant and neurogram metric spaces.

    Paper: "GW optimization was solved using entropic regularization with the
    POT library. Parameters: entropic regularization ε = 0.01, maximum 100
    outer iterations (tolerance 10^−6), 100 Sinkhorn iterations (tolerance 10^−8)."

    Parameters
    ----------
    formant_dist_matrix : np.ndarray, shape (N, N)
        Pairwise DTW distances in formant space.
    neurogram_dist_matrix : np.ndarray, shape (N, N)
        Pairwise wPEW distances in neurogram space.

    Returns
    -------
    float
        Entropic Gromov-Wasserstein distance.
    """
    n = formant_dist_matrix.shape[0]

    # Normalize distance matrices by maximum (paper appendix)
    max_f = np.nanmax(formant_dist_matrix)
    max_n = np.nanmax(neurogram_dist_matrix)
    if max_f > 0:
        formant_dist_matrix = formant_dist_matrix / max_f
    if max_n > 0:
        neurogram_dist_matrix = neurogram_dist_matrix / max_n

    # Uniform marginals
    p = ot.unif(n)
    q = ot.unif(n)

    # Entropic Gromov-Wasserstein (as described in paper)
    gw_dist = ot.gromov.entropic_gromov_wasserstein2(
        formant_dist_matrix, neurogram_dist_matrix,
        p, q,
        loss_fun='square_loss',
        epsilon=0.01,           # Entropic regularization
        max_iter=100,           # Max outer iterations
        tol=1e-6,               # Outer tolerance
        # Sinkhorn parameters are controlled internally by POT
        verbose=False,
        log=False
    )

    return float(gw_dist)


# ============================================================================
# MAIN ANALYSIS PIPELINE
# ============================================================================

def compute_pairwise_distances(items, distance_fn, max_samples=500):
    """
    Compute pairwise distance matrix.

    Paper: "N ranged from 100 to 500 samples per phoneme category."

    Parameters
    ----------
    items : list
        Items to compare (trajectories or neurograms).
    distance_fn : callable
        Distance function taking two items.
    max_samples : int
        Maximum number of samples to use.

    Returns
    -------
    np.ndarray, shape (N, N)
        Symmetric distance matrix.
    """
    if len(items) > max_samples:
        np.random.seed(42)
        indices = np.random.choice(len(items), max_samples, replace=False)
        items = [items[i] for i in indices]

    n = len(items)
    dist_matrix = np.zeros((n, n))

    for i in range(n):
        for j in range(i + 1, n):
            d = distance_fn(items[i], items[j])
            dist_matrix[i, j] = d
            dist_matrix[j, i] = d

    return dist_matrix


def run_ot_analysis(merged_df, output_dir, category_col='Category',
                    max_samples_per_group=500):
    """
    Run the full OT analysis pipeline.

    For each (category, perturbation_type, formant) combination:
      1. Compute DTW distance matrix for formant trajectories
      2. Compute wPEW distance matrix for full 150-channel neurograms
      3. Compute entropic GW distance

    Parameters
    ----------
    merged_df : pd.DataFrame
        Merged dataframe with columns:
          - 'Original': full 150-channel neurogram arrays
          - 'f1', 'f2', 'f3': formant trajectory lists
          - 'PerturbationType': perturbation label
          - category_col: phoneme category
    output_dir : str
        Output directory for results.
    category_col : str
        Column name for phoneme category.
    max_samples_per_group : int
        Maximum samples per group for distance computation.

    Returns
    -------
    pd.DataFrame
        Results with columns: Category, Formant, GW_Distance, PerturbationType, N
    """
    import os
    os.makedirs(output_dir, exist_ok=True)

    results = []
    # Neurogram distance matrices keyed by the exact rows used. The neural
    # matrix does not depend on the formant, so F1/F2/F3 share it whenever they
    # retain the same tokens; if NaN trajectories drop different rows for
    # different formants, the key differs and the matrix is recomputed.
    neurogram_cache = {}
    categories = merged_df[category_col].dropna().unique()
    perturbation_types = merged_df['PerturbationType'].dropna().unique()

    print(f"Categories: {len(categories)}")
    print(f"Perturbation types: {list(perturbation_types)}")

    for category in sorted(categories):
        for pert_type in sorted(perturbation_types):
            # Filter data
            mask = (merged_df[category_col] == category) & \
                   (merged_df['PerturbationType'] == pert_type)
            subset = merged_df[mask]

            if len(subset) < 2:
                continue

            # Limit sample size
            if len(subset) > max_samples_per_group:
                subset = subset.sample(n=max_samples_per_group, random_state=42)

            n_samples = len(subset)

            for formant_name in ['f1', 'f2', 'f3']:
                print(f"  {category} × {pert_type} × {formant_name.upper()} "
                      f"(N={n_samples})...")

                # Extract valid formant trajectories
                formant_trajs = []
                neurogram_list = []
                row_ids = []

                for row_id, row in subset.iterrows():
                    traj = row[formant_name]
                    neuro = row['Original']

                    if (isinstance(traj, (list, np.ndarray)) and len(traj) > 0 and
                            isinstance(neuro, np.ndarray) and neuro.ndim == 2):
                        traj_arr = np.array(traj)
                        if not np.all(np.isnan(traj_arr)):
                            formant_trajs.append(traj_arr)
                            neurogram_list.append(neuro)
                            row_ids.append(row_id)

                if len(formant_trajs) < 2:
                    continue

                # Compute distance matrices
                try:
                    formant_dists = compute_pairwise_distances(
                        formant_trajs, dtw_formant_distance, max_samples_per_group
                    )
                    cache_key = (category, pert_type, tuple(row_ids))
                    if cache_key not in neurogram_cache:
                        neurogram_cache[cache_key] = compute_pairwise_distances(
                            neurogram_list, wpew_neurogram_distance,
                            max_samples_per_group
                        )
                    neurogram_dists = neurogram_cache[cache_key]

                    # Compute GW distance
                    gw_dist = compute_gw_distance(formant_dists, neurogram_dists)

                    results.append({
                        'Category': category,
                        'Formant': formant_name.upper(),
                        'GW_Distance': round(gw_dist, 4),
                        'PerturbationType': pert_type,
                        'NumSamples': len(formant_trajs),
                    })

                    print(f"    GW = {gw_dist:.4f}")

                except Exception as e:
                    print(f"    Error: {e}")

    # Save results
    results_df = pd.DataFrame(results)
    results_df.to_csv(os.path.join(output_dir, 'gw_distances.csv'), index=False)
    results_df.to_pickle(os.path.join(output_dir, 'gw_distances.pkl'))
    print(f"\nSaved {len(results_df)} GW distance results to {output_dir}")

    # Run statistical comparisons
    if len(results_df) > 0:
        stats_results = kruskal_wallis_gw_comparisons(results_df)
        with open(os.path.join(output_dir, 'statistical_tests.json'), 'w') as f:
            json.dump(stats_results, f, indent=2)
        print(f"Saved statistical tests to {output_dir}/statistical_tests.json")

    return results_df


# ============================================================================
# STATISTICAL TESTS
# ============================================================================

def kruskal_wallis_gw_comparisons(results_df):
    """
    Kruskal-Wallis H test for GW distance comparisons across perturbation types.

    Paper (Section 2.7): "Kruskal-Wallis H test was used to compare
    GW distances across perturbation types within each phoneme category."

    For each (category, formant) group, tests whether the GW distance
    distributions differ significantly across perturbation types.

    Also performs pairwise Mann-Whitney U tests between perturbation types
    as post-hoc comparisons.

    Parameters
    ----------
    results_df : pd.DataFrame
        Results from run_ot_analysis with columns:
        Category, Formant, GW_Distance, PerturbationType, NumSamples

    Returns
    -------
    dict
        Statistical test results per (category, formant) group.
    """
    all_results = {}

    categories = sorted(results_df['Category'].unique())
    formants = sorted(results_df['Formant'].unique())

    print("\nKruskal-Wallis H tests (GW distance ~ perturbation type):")
    print("=" * 70)

    for category in categories:
        all_results[category] = {}

        for formant in formants:
            mask = (results_df['Category'] == category) & \
                   (results_df['Formant'] == formant)
            subset = results_df[mask]

            if len(subset) < 2:
                continue

            # Group GW distances by perturbation type
            groups = {}
            for pert in sorted(subset['PerturbationType'].unique()):
                values = subset[subset['PerturbationType'] == pert]['GW_Distance'].values
                if len(values) > 0:
                    groups[pert] = values

            if len(groups) < 2:
                continue

            # Kruskal-Wallis H test
            group_arrays = list(groups.values())
            try:
                h_stat, p_value = stats.kruskal(*group_arrays)
            except ValueError:
                h_stat, p_value = 0.0, 1.0

            result = {
                'H_statistic': float(h_stat),
                'p_value': float(p_value),
                'significant_0.05': bool(p_value < 0.05),
                'n_groups': len(groups),
                'group_sizes': {k: len(v) for k, v in groups.items()},
                'group_medians': {k: float(np.median(v)) for k, v in groups.items()},
            }

            sig = '**' if p_value < 0.01 else ('*' if p_value < 0.05 else '')
            print(f"  {category:12s} × {formant}: H={h_stat:.2f}, p={p_value:.4f} {sig}")

            # Pairwise Mann-Whitney U post-hoc tests
            pert_names = sorted(groups.keys())
            pairwise = {}
            for i in range(len(pert_names)):
                for j in range(i + 1, len(pert_names)):
                    a, b = pert_names[i], pert_names[j]
                    if len(groups[a]) > 0 and len(groups[b]) > 0:
                        try:
                            u_stat, u_p = stats.mannwhitneyu(
                                groups[a], groups[b], alternative='two-sided'
                            )
                        except ValueError:
                            u_stat, u_p = 0.0, 1.0

                        pair_key = f"{a}_vs_{b}"
                        pairwise[pair_key] = {
                            'U_statistic': float(u_stat),
                            'p_value': float(u_p),
                            'significant_0.05': bool(u_p < 0.05),
                        }

            result['pairwise_mannwhitney'] = pairwise
            all_results[category][formant] = result

    return all_results
