"""The label encoding must match the one used for training."""

from simsacues.phoneme_categories import CATEGORY_NAMES, NUM_CATEGORIES, PHONEME_TO_CATEGORY_NAME


def test_nine_categories_in_training_order():
    assert NUM_CATEGORIES == 9
    assert CATEGORY_NAMES == [
        "nasal", "vowel", "liquid", "glide", "fricative",
        "stop", "affricate", "flap", "silence",
    ]


def test_documented_overlap_resolution():
    """Phonemes listed in two groups resolve to the last group, as documented."""
    assert PHONEME_TO_CATEGORY_NAME["em"] == "vowel"
    assert PHONEME_TO_CATEGORY_NAME["en"] == "vowel"
    assert PHONEME_TO_CATEGORY_NAME["el"] == "liquid"


def test_every_phoneme_maps_to_a_known_category():
    assert set(PHONEME_TO_CATEGORY_NAME.values()) <= set(CATEGORY_NAMES)
