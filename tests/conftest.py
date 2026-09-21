"""Shared fixtures. The original, pre-refactor OT module is loaded from
``tests/reference/`` so the refactored code can be checked against it."""

import importlib.util
import pathlib

import numpy as np
import pandas as pd
import pytest

REFERENCE = pathlib.Path(__file__).parent / "reference" / "original_optimal_transport.py"


@pytest.fixture(scope="session")
def original_ot():
    spec = importlib.util.spec_from_file_location("original_optimal_transport", REFERENCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def synthetic_ot_frame():
    """Small cohort: 2 categories x 2 perturbations x 12 tokens, with some NaN
    formant trajectories so that F1/F2/F3 keep different token subsets."""
    rng = np.random.default_rng(7)
    rows = []
    for category in ["vowel", "stop"]:
        for pert in ["loss", "truncation"]:
            for k in range(12):
                f1 = rng.normal(500, 80, 30)
                f2 = rng.normal(1500, 150, 30)
                f3 = rng.normal(2500, 200, 30)
                if k == 3:
                    f2[:] = np.nan  # this token drops out of the F2 analysis only
                rows.append({
                    "Category": category,
                    "PerturbationType": pert,
                    "f1": list(f1), "f2": list(f2), "f3": list(f3),
                    "Original": rng.random((25, 30)).astype(np.float32),
                })
    return pd.DataFrame(rows)
