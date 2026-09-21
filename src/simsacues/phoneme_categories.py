"""
phoneme_categories.py — TIMIT phoneme-to-category mapping

Maps TIMIT's 39 phonemes into 9 perceptual categories as described in the paper
(Table A4, Section 2.1).

Categories (matching training label encoding):
    0 = Nasal
    1 = Vowel
    2 = Liquid
    3 = Glide
    4 = Fricative
    5 = Stop
    6 = Affricate
    7 = Flap
    8 = Silence
"""

# TIMIT phoneme set → category mapping
# Includes all TIMIT phonemes (standard 39 + variants)
# NOTE: Category ordering matches the training label encoding
PHONEME_GROUPS = {
    'nasal': ['m', 'n', 'ng'],
    'vowel': [
        'aa', 'ae', 'ah', 'ao', 'aw', 'ax', 'axr', 'ay',
        'eh', 'el', 'em', 'en', 'er', 'ey',
        'ih', 'ix', 'iy',
        'ow', 'oy',
        'uh', 'uw', 'ux',
    ],
    # NOTE: 'el' appears in both vowel and liquid; 'em','en' in both nasal and vowel.
    # This matches the original HPC code. In PHONEME_TO_CATEGORY_IDX, the LAST
    # category to claim a phoneme wins (dict overwrite), so:
    #   em → vowel(1), en → vowel(1)  (vowel overwrites nasal)
    #   el → liquid(2)                 (liquid overwrites vowel)
    'liquid': ['l', 'r', 'el'],
    'glide': ['w', 'y'],
    'fricative': ['f', 'v', 'th', 'dh', 's', 'z', 'sh', 'zh', 'hh', 'hv'],
    'stop': ['p', 'b', 't', 'd', 'k', 'g',
             'pcl', 'bcl', 'tcl', 'dcl', 'kcl', 'gcl'],
    'affricate': ['ch', 'jh'],
    'flap': ['dx'],
    'silence': ['h#', 'pau', 'epi', 'q'],
}

# Ordered list of category names — index = numeric label
# CRITICAL: This ordering must match the label encoding used during training
CATEGORY_NAMES = [
    'nasal',      # 0
    'vowel',      # 1
    'liquid',     # 2
    'glide',      # 3
    'fricative',  # 4
    'stop',       # 5
    'affricate',  # 6
    'flap',       # 7
    'silence',    # 8
]

NUM_CATEGORIES = len(CATEGORY_NAMES)

# Build phoneme → category index mapping
PHONEME_TO_CATEGORY_IDX = {}
for cat_name, phonemes in PHONEME_GROUPS.items():
    cat_idx = CATEGORY_NAMES.index(cat_name)
    for phoneme in phonemes:
        PHONEME_TO_CATEGORY_IDX[phoneme] = cat_idx

# Build phoneme → category name mapping
PHONEME_TO_CATEGORY_NAME = {}
for cat_name, phonemes in PHONEME_GROUPS.items():
    for phoneme in phonemes:
        PHONEME_TO_CATEGORY_NAME[phoneme] = cat_name


def convert_39_to_9(labels_39, phoneme_list_39):
    """
    Convert 39-class phoneme labels to 9-category labels.

    Parameters
    ----------
    labels_39 : np.ndarray of int
        Array of phoneme indices (0–38) from TIMIT's 39-phoneme set.
    phoneme_list_39 : list of str
        Ordered list of the 39 phoneme names, where index = label value.

    Returns
    -------
    np.ndarray of int
        Array of 9-category labels.
    """
    import numpy as np
    labels_9 = np.zeros_like(labels_39)
    for i, label in enumerate(labels_39):
        phoneme_name = phoneme_list_39[int(label)]
        labels_9[i] = PHONEME_TO_CATEGORY_IDX.get(phoneme_name, 8)  # default to silence
    return labels_9


def convert_40_to_9_categories(labels_40):
    """
    Convert 40-class phoneme indices to 9-category labels.

    This uses the numeric index mapping from the TIMIT 40-phoneme encoding.
    The mapping must match the phoneme list ordering used during data preparation.

    Parameters
    ----------
    labels_40 : np.ndarray of int
        Array of phoneme indices (0–39).

    Returns
    -------
    np.ndarray of int
        Array of 9-category labels.
    """
    import numpy as np

    # Mapping from 40-class phoneme index → 9-category index
    # This must match the Phonemes39_posindex_labels encoding
    phoneme_map = {
        22: 0, 23: 0, 24: 0,  # Nasals (m, n, ng)
        0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 11: 1, 12: 1, 13: 1,
        17: 1, 18: 1, 25: 1, 26: 1, 33: 1, 34: 1,  # Vowels
        21: 2, 28: 2,  # Liquids (l, r)
        36: 3, 37: 3,  # Glides (w, y)
        14: 4, 16: 4, 29: 4, 30: 4, 32: 4, 35: 4, 38: 4,  # Fricatives
        6: 5, 8: 5, 15: 5, 20: 5, 27: 5, 31: 5,  # Stops
        7: 6, 19: 6,  # Affricates (ch, jh)
        10: 7,  # Flap (dx)
        39: 8,  # Silence
    }

    labels_9 = np.array([phoneme_map.get(int(label), 8) for label in labels_40])
    return labels_9
