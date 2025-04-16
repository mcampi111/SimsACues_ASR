import numpy as np

def get_phoneme_groups():
    """
    Define phoneme groupings for rare classes.
    Returns a dictionary mapping original phoneme IDs to group IDs.
    """
    # Define the mapping for rare phonemes with lower group IDs
    mapping = {
        7: 40,   # 'v' -> fricatives group
        33: 40,  # 'th' -> fricatives group
        39: 40,  # 'z' -> fricatives group
        
        28: 41,  # 'q' -> special consonants
        29: 41,  # 'r' -> special consonants
        
        38: 42,  # 'ng' -> nasals
        
        25: 43   # 'ow' -> round vowels
    }
    
    return mapping

def map_phonemes(phonemes):
    """
    Map phoneme IDs to grouped IDs for rare phonemes.
    Args:
        phonemes: NumPy array of original phoneme IDs
    Returns:
        NumPy array with mapped phoneme IDs
    """
    mapping = get_phoneme_groups()
    
    # Convert to integers and create a copy
    phonemes_int = phonemes.astype(int).copy()
    
    # Apply mapping
    for orig_id, new_id in mapping.items():
        phonemes_int[phonemes_int == orig_id] = new_id
    
    return phonemes_int

def get_group_name(phoneme_id):
    """
    Get the display name for a phoneme group.
    """
    group_names = {
        40: "Fricatives (v/th/z)",
        41: "Special Consonants (q/r)",
        42: "Nasals (ng)",
        43: "Round Vowels (ow)"
    }
    return group_names.get(phoneme_id, f"Phoneme {phoneme_id}")

def reverse_map_for_evaluation(predictions, true_labels):
    """
    For evaluation, map both predictions and true labels to the same space.
    This allows proper evaluation of the rare phoneme groups.
    """
    mapping = get_phoneme_groups()
    
    # Create copies to avoid modifying originals
    pred_mapped = predictions.copy()
    true_mapped = true_labels.copy()
    
    # Apply mapping to both predictions and true labels
    for orig_id, new_id in mapping.items():
        # Map in predictions
        pred_mapped[pred_mapped == orig_id] = new_id
        # Map in true labels
        true_mapped[true_mapped == orig_id] = new_id
        
    return pred_mapped, true_mapped
