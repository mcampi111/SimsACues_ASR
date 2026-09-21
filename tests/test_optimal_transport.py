"""The refactored OT module must reproduce the original outputs exactly."""

import json

import numpy as np
import pandas as pd
import pytest

from simsacues.ot import optimal_transport as ot_new


# float64 inputs agree to machine precision. float32 inputs agree to float32
# precision: the vectorised sum adds the window terms in a different order, which
# can move the last bit of a float32 result (~1e-8) and nothing more.
@pytest.mark.parametrize("dtype, tol", [(np.float64, 1e-12), (np.float32, 1e-6)])
@pytest.mark.parametrize("shape", [(25, 30), (60, 150), (3, 3), (1, 20)])
def test_wpew_matches_original(original_ot, dtype, tol, shape):
    rng = np.random.default_rng(0)
    a = rng.random(shape).astype(dtype)
    b = rng.random(shape).astype(dtype)
    assert ot_new.wpew_neurogram_distance(a, b) == pytest.approx(
        original_ot.wpew_neurogram_distance(a, b), rel=tol, abs=tol
    )


def test_wpew_shape_mismatch_still_returns_inf(original_ot):
    a, b = np.zeros((5, 6)), np.zeros((5, 7))
    assert ot_new.wpew_neurogram_distance(a, b) == np.inf
    assert original_ot.wpew_neurogram_distance(a, b) == np.inf


def _json_tolerant_of_numpy_scalars(monkeypatch, module):
    """The original writes numpy booleans to JSON, which raises TypeError after
    the GW table has been saved. Let the reference run to completion so the two
    outputs can be compared."""
    import json as _json
    import types

    shim = types.SimpleNamespace(
        dump=lambda obj, f, **kw: _json.dump(obj, f, default=lambda x: x.item(), **kw)
    )
    monkeypatch.setattr(module, "json", shim)


def test_full_pipeline_output_identical(original_ot, synthetic_ot_frame, tmp_path, monkeypatch):
    """End-to-end: same GW table and same statistics as the original code."""
    _json_tolerant_of_numpy_scalars(monkeypatch, original_ot)
    old = original_ot.run_ot_analysis(synthetic_ot_frame, str(tmp_path / "old"))
    new = ot_new.run_ot_analysis(synthetic_ot_frame, str(tmp_path / "new"))
    pd.testing.assert_frame_equal(old.reset_index(drop=True), new.reset_index(drop=True))

    stats_old = json.loads((tmp_path / "old" / "statistical_tests.json").read_text())
    stats_new = json.loads((tmp_path / "new" / "statistical_tests.json").read_text())
    assert stats_old == stats_new


def test_neurogram_matrix_is_reused_across_formants(synthetic_ot_frame, tmp_path, monkeypatch):
    """F1 and F3 keep the same tokens here, so the neural matrix is computed once
    for them; F2 drops a token and gets its own matrix."""
    calls = []
    original = ot_new.compute_pairwise_distances

    def counting(items, fn, *args, **kwargs):
        if fn is ot_new.wpew_neurogram_distance:
            calls.append(len(items))
        return original(items, fn, *args, **kwargs)

    monkeypatch.setattr(ot_new, "compute_pairwise_distances", counting)
    ot_new.run_ot_analysis(synthetic_ot_frame, str(tmp_path))
    # 2 categories x 2 perturbations x (one shared F1/F3 matrix + one F2 matrix)
    assert len(calls) == 8
    assert sorted(set(calls)) == [11, 12]
