"""Model architectures build with the input shapes used in the paper."""

import pytest

tf = pytest.importorskip("tensorflow")

from simsacues.asr.srA1 import build_srA1  # noqa: E402
from simsacues.asr.srA2 import build_srA2  # noqa: E402
from simsacues.phoneme_categories import NUM_CATEGORIES  # noqa: E402


def test_srA1_builds_with_reported_size():
    model = build_srA1()
    assert model.input_shape == (None, 50, 150)
    assert model.output_shape[-1] == NUM_CATEGORIES
    assert model.count_params() == 456_073


def test_srA2_builds():
    model = build_srA2()
    assert model.input_shape == (None, 305, 9)
    assert model.output_shape[-1] == NUM_CATEGORIES
