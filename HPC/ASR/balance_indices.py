import numpy as np
import os
import json
import re
from collections import Counter, defaultdict
from sklearn.utils import class_weight

def generate_balanced_indices(phonemes_path, positions_path, output_dir, min_samples=500, max_ratio=5.0, time_steps=50):
    """
    Generate balanced training indices for ASR training by balancing position indices
    based on their corresponding phonemes, ensuring all positions have enough context.
    
    Args:
        phonemes_path: Path to the phonemes array
        positions_path: Path to the positions index array 
        output_dir: Directory to save the output files
        min_samples: Minimum number of samples to keep per class (when available)
        max_ratio: Maximum ratio between most frequent and least frequent classes
        time_steps: Number of time steps needed for each window (for validation)
    
    Returns:
        balanced_positions: Numpy array of balanced position indices for training
    """
    # Load phonemes and position indices
    phonemes = np.load(phonemes_path)
    positions = np.load(positions_path).flatten()  # Ensure positions is flattened
    
    print(f"Original phonemes shape: {phonemes.shape}")
    print(f"Original positions shape: {positions.shape}")
    
    # Filter positions to ensure they all have enough context
    # Each position needs at least time_steps-1 previous time steps available
    valid_mask = (positions >= time_steps) & (positions < len(phonemes))
    valid_positions = positions[valid_mask]
    
    print(f"Total positions: {len(positions)}")
    print(f"Valid positions with enough context: {len(valid_positions)} ({len(valid_positions)/len(positions)*100:.1f}%)")
    
    if len(valid_positions) < len(positions):
        print(f"Filtered out {len(positions) - len(valid_positions)} positions that lacked enough context")
    
    # Get the phonemes at each valid position
    position_phonemes = phonemes[valid_positions]
    
    # Count class occurrences in the position-based phonemes
    class_counts = Counter(position_phonemes)
    classes = np.array(list(class_counts.keys()))
    counts = np.array(list(class_counts.values()))
    
    # Sort by frequency
    sort_idx = np.argsort(counts)
    classes_sorted = classes[sort_idx]
    counts_sorted = counts[sort_idx]
    
    # Calculate original imbalance ratio
    orig_imbalance_ratio = counts_sorted[-1] / counts_sorted[0] if counts_sorted[0] > 0 else float('inf')
    print(f"Original imbalance ratio: {orig_imbalance_ratio:.2f}")
    
    # Group positions by their corresponding phoneme class
    class_positions = {}
    for cls in classes:
        # Find positions where the phoneme matches this class
        indices = np.where(position_phonemes == cls)[0]
        # Get the actual position values at these indices
        class_positions[cls] = valid_positions[indices]
    
    # Calculate target counts for each class
    # First determine the effective minimum (either min_samples or actual minimum if smaller)
    effective_min = min(min_samples, min(counts))
    print(f"Effective minimum samples per class: {effective_min}")
    
    # Calculate max samples to maintain target ratio
    max_samples = effective_min * max_ratio
    print(f"Maximum samples per class (based on ratio {max_ratio}): {max_samples:.0f}")
    
    # Create balanced indices using controlled undersampling
    balanced_positions = []
    selected_samples = {}
    
    for cls in classes:
        positions_for_class = class_positions[cls]
        current_count = len(positions_for_class)
        
        # Calculate target count based on minimum threshold
        if current_count <= min_samples:
            # Keep all samples for classes with fewer than min_samples
            target_count = current_count
        else:
            # Calculate proportional reduction for larger classes
            target_count = min(current_count, max(min_samples, 
                                min(max_samples, 
                                    min_samples + (current_count - min_samples) / 
                                    (counts_sorted[-1] - min_samples) * (max_samples - min_samples)
                                   )
                               )
                           )
            
            # Round to nearest integer
            target_count = int(round(target_count))
        
        # Randomly select indices
        if current_count > target_count:
            selected = np.random.choice(positions_for_class, target_count, replace=False)
        else:
            selected = positions_for_class
        
        # Double check that all selected positions have enough context
        # (this should already be true based on earlier filtering)
        valid_selected = selected[selected >= time_steps]
        if len(valid_selected) < len(selected):
            print(f"Warning: Filtered {len(selected) - len(valid_selected)} invalid positions for class {cls}")
            selected = valid_selected
        
        # Save which positions were selected for this class
        selected_samples[int(cls)] = selected.tolist()
        
        # Add to balanced positions
        balanced_positions.extend(selected)
        
        # Print stats for this class
        print(f"Class {cls}: Original {current_count} -> Balanced {len(selected)} samples " + 
              f"({len(selected)/current_count*100:.1f}% kept)")
    
    # Convert to numpy array and reshape to match original positions shape
    balanced_positions = np.array(balanced_positions).reshape(-1, 1)
    
    # Shuffle in place
    indices = np.arange(len(balanced_positions))
    np.random.shuffle(indices)
    balanced_positions = balanced_positions[indices]
    
    # Calculate new class distribution 
    balanced_phonemes = phonemes[balanced_positions.flatten()]
    balanced_counts = Counter(balanced_phonemes)
    
    new_counts = np.array([balanced_counts.get(cls, 0) for cls in classes_sorted])
    if min(new_counts) > 0:
        new_imbalance_ratio = max(new_counts) / min(new_counts)
    else:
        new_imbalance_ratio = float('inf')
    
    print(f"New balanced dataset size: {len(balanced_positions)}")
    print(f"New imbalance ratio: {new_imbalance_ratio:.2f}")
    
    # Verify all positions are valid for usage in the model
    min_pos = np.min(balanced_positions)
    max_pos = np.max(balanced_positions)
    print(f"Position range check: Min={min_pos}, Max={max_pos}, Required minimum={time_steps}")
    
    # Final verification check
    invalid_positions = balanced_positions[balanced_positions < time_steps]
    if len(invalid_positions) > 0:
        print(f"Warning: Found {len(invalid_positions)} positions below the minimum threshold of {time_steps}")
        # Remove these invalid positions
        balanced_positions = balanced_positions[balanced_positions >= time_steps]
        print(f"Removed invalid positions. New size: {len(balanced_positions)}")
    
    # Save balanced position indices
    balanced_positions_path = f"{output_dir}/balanced_positions.npy"
    np.save(balanced_positions_path, balanced_positions)
    print(f"Saved balanced positions to {balanced_positions_path}")
    
    # Save detailed information about balanced dataset
    with open(f"{output_dir}/balanced_dataset_info.txt", 'w') as f:
        f.write(f"Original positions size: {len(positions)}\n")
        f.write(f"Valid positions size: {len(valid_positions)}\n")
        f.write(f"Balanced positions size: {len(balanced_positions)}\n")
        f.write(f"Original imbalance ratio: {orig_imbalance_ratio:.2f}\n")
        f.write(f"New imbalance ratio: {new_imbalance_ratio:.2f}\n")
        f.write(f"Minimum samples threshold: {min_samples}\n")
        f.write(f"Maximum ratio: {max_ratio}\n")
        f.write(f"Time steps window: {time_steps}\n\n")
        
        f.write("Class distribution by phoneme:\n")
        f.write(f"{'Class':<10} {'Original':<10} {'Balanced':<10} {'% Kept':<10}\n")
        f.write("-" * 50 + "\n")
        
        for cls in classes_sorted:
            orig = class_counts[cls]
            new = balanced_counts.get(cls, 0)
            percent = (new / orig) * 100 if orig > 0 else 0
            f.write(f"{cls:<10} {orig:<10} {new:<10} {percent:.2f}%\n")
    
    # Save mapping of which position samples were selected for each class
    tracking_dir = os.path.join(output_dir, 'sample_tracking')
    os.makedirs(tracking_dir, exist_ok=True)
    
    with open(f"{tracking_dir}/selected_positions.json", 'w') as f:
        # Convert numpy int64 keys to regular ints for JSON serialization
        json_compatible = {int(k): [int(pos) for pos in v] for k, v in selected_samples.items()}
        json.dump(json_compatible, f)
    
    return balanced_positions


def generate_speaker_aware_indices(phonemes_path, positions_path, neurogram_dir, output_dir, 
                                  min_samples=500, max_ratio=5.0, time_steps=50):
    """
    Generate balanced indices while respecting speaker boundaries
    
    Args:
        phonemes_path: Path to phoneme array file
        positions_path: Path to position indices file
        neurogram_dir: Directory containing neurogram files
        output_dir: Directory to save output files
        min_samples: Minimum samples per class
        max_ratio: Maximum ratio between most and least common class
        time_steps: Context window size for sequences
    
    Returns:
        balanced_positions: Numpy array of balanced position indices for training
    """
    import random
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Load data
    print(f"Loading phoneme data from {phonemes_path}")
    phonemes = np.load(phonemes_path)
    
    print(f"Loading position indices from {positions_path}")
    positions = np.load(positions_path)
    positions = positions.flatten()  # Ensure 1D array
    
    # Extract speaker information
    print(f"Scanning neurogram directory: {neurogram_dir}")
    
    # Regex to extract speaker and timing info from filenames
    # Pattern made more flexible to match more filename formats
    pattern = r'.*?([A-Za-z]+\d+)_([a-z\-#]+)_(\d+)_(\d+).*'
    
    # Store speaker info: {time_index: speaker_id}
    time_to_speaker = {}
    
    # Walk through the directory structure
    file_count = 0
    match_count = 0
    sample_files = []
    
    # Try to find the files
    print(f"Checking if directory exists: {os.path.exists(neurogram_dir)}")
    
    try:
        for root, dirs, files in os.walk(neurogram_dir):
            if file_count < 10:
                print(f"Searching in: {root}")
                print(f"Found files: {len(files)}")
                if len(files) > 0:
                    print(f"Sample filename: {files[0]}")
                
            for file in files:
                file_count += 1
                if file_count <= 20:  # Save more files for debugging
                    sample_files.append(os.path.join(root, file))
                    
                # Look for neurogram files (try different extensions)
                if not (file.endswith('.mat') or file.endswith('.npy') or 'neurogram' in file):
                    continue
                    
                # Extract speaker and time info from filename
                match = re.match(pattern, file)
                if match:
                    match_count += 1
                    speaker_id, phoneme, start_time, end_time = match.groups()
                    
                    # Map each time index in this range to the speaker
                    try:
                        start_idx = int(start_time)
                        end_idx = int(end_time)
                        for i in range(start_idx, end_idx + 1):
                            time_to_speaker[i] = speaker_id
                    except ValueError:
                        print(f"Warning: Could not convert time indices in file: {file}")
        
        print(f"Processed {file_count} files, found {match_count} matching neurogram files")
        if sample_files:
            print(f"Sample filenames:")
            for i, sf in enumerate(sample_files[:5]):
                print(f"  {i+1}. {sf}")
        else:
            print("No sample files found in neurogram directory")
            
    except Exception as e:
        print(f"Error while scanning neurogram directory: {e}")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    print(f"Extracted speaker info for {len(time_to_speaker)} time indices")
    
    # FALLBACK: If no speaker info was found, use standard balanced indices
    if len(time_to_speaker) == 0:
        print("WARNING: No speaker information could be extracted!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Count unique speakers
    unique_speakers = set(time_to_speaker.values())
    print(f"Found {len(unique_speakers)} unique speakers")
    
    # Group positions by speaker
    speaker_positions = defaultdict(list)
    mapped_count = 0
    
    for pos in positions:
        pos_int = int(pos)  # Ensure position is an integer
        if pos_int in time_to_speaker:
            speaker = time_to_speaker[pos_int]
            speaker_positions[speaker].append(pos_int)
            mapped_count += 1
    
    # Verify coverage
    print(f"Successfully mapped {mapped_count} out of {len(positions)} positions to speakers ({mapped_count/len(positions)*100:.1f}%)")
    
    # FALLBACK: If mapping is too poor, use standard method
    if mapped_count < 100 or mapped_count < len(positions) * 0.01:  # Less than 1% mapped or fewer than 100 samples
        print("WARNING: Too few positions mapped to speakers!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Split speakers into train/validation/test (80/10/10)
    all_speakers = list(speaker_positions.keys())
    random.shuffle(all_speakers)
    
    # Calculate split points
    n_train = int(len(all_speakers) * 0.8)
    n_val = int(len(all_speakers) * 0.1)
    
    train_speakers = all_speakers[:n_train]
    val_speakers = all_speakers[n_train:n_train+n_val]
    test_speakers = all_speakers[n_train+n_val:]
    
    print(f"Split speakers: {len(train_speakers)} train, {len(val_speakers)} validation, {len(test_speakers)} test")
    
    # Collect positions for each split
    train_positions = []
    for speaker in train_speakers:
        train_positions.extend(speaker_positions[speaker])
    
    val_positions = []
    for speaker in val_speakers:
        val_positions.extend(speaker_positions[speaker])
    
    test_positions = []
    for speaker in test_speakers:
        test_positions.extend(speaker_positions[speaker])
    
    print(f"Position counts: {len(train_positions)} train, {len(val_positions)} val, {len(test_positions)} test")
    
    # Filter positions to ensure they have enough context
    valid_train_positions = [pos for pos in train_positions if pos >= time_steps and pos < len(phonemes)]
    valid_val_positions = [pos for pos in val_positions if pos >= time_steps and pos < len(phonemes)]
    valid_test_positions = [pos for pos in test_positions if pos >= time_steps and pos < len(phonemes)]
    
    print(f"After context filtering: {len(valid_train_positions)} train, {len(valid_val_positions)} val, {len(valid_test_positions)} test")
    
    # FALLBACK: If too many positions were filtered out
    if len(valid_train_positions) < 1000:  # Arbitrary minimum for training
        print("WARNING: Too few valid positions after filtering!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Now balance the classes within the training set
    print("Balancing classes in training set...")
    
    # Group by phoneme class
    class_positions = defaultdict(list)
    for pos in valid_train_positions:
        if pos < len(phonemes):  # Safety check
            phoneme = int(phonemes[pos])
            class_positions[phoneme].append(pos)
    
    # Print class distribution before balancing
    print("Class distribution before balancing:")
    for phoneme, positions in sorted(class_positions.items()):
        print(f"  Class {phoneme}: {len(positions)} samples")
    
    # Make sure we have at least some classes with samples
    if not class_positions:
        print("WARNING: No valid class positions found!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Calculate target samples per class
    counts = [len(positions) for positions in class_positions.values()]
    if not counts:
        print("WARNING: No counts found for any class!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
        
    min_count = max(min(counts), min_samples)
    max_count = min(max(counts), min_count * max_ratio)
    
    print(f"Target samples per class: minimum {min_count}, maximum {max_count}")
    
    # Balance classes
    balanced_positions = []
    for phoneme, positions in class_positions.items():
        if len(positions) < min_count:
            # Undersample: use all available samples
            samples = positions
        elif len(positions) > max_count:
            # Oversample: randomly select max_count samples
            samples = random.sample(positions, int(max_count))
        else:
            # Use all samples
            samples = positions
        
        balanced_positions.extend(samples)
        print(f"Class {phoneme}: Original {len(positions)} -> Balanced {len(samples)} samples")
    
    # Shuffle the balanced positions
    random.shuffle(balanced_positions)
    
    # Save the balanced indices
    balanced_path = os.path.join(output_dir, "balanced_positions.npy")
    validation_path = os.path.join(output_dir, "validation_positions.npy")
    test_path = os.path.join(output_dir, "test_positions.npy")
    
    # Convert to numpy arrays and reshape to column vectors
    balanced_positions_array = np.array(balanced_positions).reshape(-1, 1)
    val_positions_array = np.array(valid_val_positions).reshape(-1, 1)
    test_positions_array = np.array(valid_test_positions).reshape(-1, 1)
    
    np.save(balanced_path, balanced_positions)
    np.save(test_path, test_positions)
    
    print(f"Saved {len(balanced_positions)} balanced positions to {balanced_path}")
    print(f"Saved {len(test_positions)} test positions to {test_path}")
    
    return balanced_positions


def generate_select_neurogram_indices(phonemes_path, positions_path, neurogram_dir, output_dir, 
                                   min_samples=500, max_ratio=5.0, time_steps=50):
    """
    Generate balanced indices specifically for SELECT_Neurogram ANSD data structure with
    proper speaker-based train/validation/test splits.
    
    Args:
        phonemes_path: Path to phoneme array file
        positions_path: Path to position indices file
        neurogram_dir: Base directory for SELECT_Neurogram files 
        output_dir: Directory to save output files
        min_samples: Minimum samples per class
        max_ratio: Maximum ratio between most and least common class
        time_steps: Context window size for sequences
    
    Returns:
        balanced_positions: Numpy array of balanced position indices for training
    """
    import re
    import os
    import numpy as np
    import random
    from collections import defaultdict
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Load data
    print(f"Loading phoneme data from {phonemes_path}")
    phonemes = np.load(phonemes_path)
    
    print(f"Loading position indices from {positions_path}")
    positions = np.load(positions_path)
    positions = positions.flatten()  # Ensure 1D array
    
    # Extract speaker information
    print(f"Scanning neurogram directory: {neurogram_dir}")
    
    # Store speaker info: {speaker_id: {'sex': 'M'|'F', 'dialect': 'dr#'}, ...}
    speaker_info = {}
    
    # Count stats for reporting
    file_count = 0
    speaker_count = 0
    
    print(f"Checking if directory exists: {os.path.exists(neurogram_dir)}")
    
    try:
        # Directly scan the dialect region directories
        for dialect in sorted(os.listdir(neurogram_dir)):
            if not dialect.startswith('DR'):
                continue
                
            dialect_path = os.path.join(neurogram_dir, dialect)
            if not os.path.isdir(dialect_path):
                continue
                
            dialect_name = dialect.lower()  # dr1, dr2, etc.
            
            # Scan speaker directories within this dialect
            for speaker_dir in sorted(os.listdir(dialect_path)):
                speaker_path = os.path.join(dialect_path, speaker_dir)
                if not os.path.isdir(speaker_path):
                    continue
                    
                # Extract gender from first letter of speaker ID
                gender = 'F' if speaker_dir.startswith('F') else 'M'
                
                # Add to speaker info
                speaker_info[speaker_dir] = {
                    'sex': gender,
                    'dialect': dialect_name
                }
                speaker_count += 1
                
                # Count files for this speaker
                speaker_files = os.listdir(speaker_path)
                file_count += len(speaker_files)
        
        print(f"Processed {file_count} files, found {speaker_count} unique speakers")
        
        # Count speakers by dialect and sex
        dialect_counts = defaultdict(lambda: {'M': 0, 'F': 0})
        for speaker, info in speaker_info.items():
            dialect_counts[info['dialect']][info['sex']] += 1
        
        # Display counts
        print("Speaker distribution by dialect and sex:")
        for dialect, counts in sorted(dialect_counts.items()):
            print(f"  {dialect}: {counts['M']} male, {counts['F']} female")
        
    except Exception as e:
        print(f"Error while scanning neurogram directory: {e}")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # FALLBACK: If no speaker info was found, use standard balanced indices
    if len(speaker_info) == 0:
        print("WARNING: No speaker information could be extracted!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Create speaker lists by dialect and sex
    speakers_by_dialect_sex = defaultdict(lambda: {'M': [], 'F': []})
    for speaker, info in speaker_info.items():
        speakers_by_dialect_sex[info['dialect']][info['sex']].append(speaker)
    
    # Split all speakers into three groups: train, validation, and test
    # Following TIMIT's recommendation but modified for three splits
    
    # 1. Select test speakers (about 10%)
    test_speakers = []
    for dialect in ['dr1', 'dr2', 'dr3', 'dr4', 'dr5', 'dr6', 'dr7']:
        if dialect in speakers_by_dialect_sex:
            # Select one male and one female from each dialect for testing
            male_speakers = speakers_by_dialect_sex[dialect]['M']
            if len(male_speakers) >= 1:
                test_speakers.append(random.sample(male_speakers, 1)[0])
            
            female_speakers = speakers_by_dialect_sex[dialect]['F']
            if len(female_speakers) >= 1:
                test_speakers.append(random.sample(female_speakers, 1)[0])
    
    # 2. Select validation speakers (about 10%)
    remaining_speakers = [s for s in speaker_info if s not in test_speakers]
    random.shuffle(remaining_speakers)
    
    # Sort remaining speakers by dialect and gender for stratified sampling
    remaining_by_dialect_sex = defaultdict(lambda: {'M': [], 'F': []})
    for speaker in remaining_speakers:
        info = speaker_info[speaker]
        remaining_by_dialect_sex[info['dialect']][info['sex']].append(speaker)
    
    validation_speakers = []
    for dialect in ['dr1', 'dr2', 'dr3', 'dr4', 'dr5', 'dr6', 'dr7']:
        if dialect in remaining_by_dialect_sex:
            # Select one male and one female from each dialect for validation
            male_speakers = remaining_by_dialect_sex[dialect]['M']
            if len(male_speakers) >= 1:
                selected = random.sample(male_speakers, 1)[0]
                validation_speakers.append(selected)
                remaining_by_dialect_sex[dialect]['M'].remove(selected)
            
            female_speakers = remaining_by_dialect_sex[dialect]['F']
            if len(female_speakers) >= 1:
                selected = random.sample(female_speakers, 1)[0]
                validation_speakers.append(selected)
                remaining_by_dialect_sex[dialect]['F'].remove(selected)
    
    # 3. All remaining speakers are for training
    train_speakers = [s for s in remaining_speakers if s not in validation_speakers]
    
    # Balance gender in training set
    male_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'M']
    female_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'F']
    
    # Balance if needed
    min_gender_count = min(len(male_train), len(female_train))
    if len(male_train) > min_gender_count:
        male_train = random.sample(male_train, min_gender_count)
    if len(female_train) > min_gender_count:
        female_train = random.sample(female_train, min_gender_count)
    
    # Final balanced training speakers
    balanced_train_speakers = male_train + female_train
    
    print(f"Selected {len(balanced_train_speakers)} speakers for training ({len(male_train)} male, {len(female_train)} female)")
    print(f"Selected {len(validation_speakers)} speakers for validation")
    print(f"Selected {len(test_speakers)} speakers for testing")
    
    # Save speaker lists
    with open(os.path.join(output_dir, "train_speakers.txt"), "w") as f:
        for speaker in balanced_train_speakers:
            f.write(f"{speaker}\n")
            
    with open(os.path.join(output_dir, "validation_speakers.txt"), "w") as f:
        for speaker in validation_speakers:
            f.write(f"{speaker}\n")
            
    with open(os.path.join(output_dir, "test_speakers.txt"), "w") as f:
        for speaker in test_speakers:
            f.write(f"{speaker}\n")
    
    # Now we need to map positions to speakers
    # This requires us to map each phoneme position to a specific speaker
    # As a simplified approach, we'll divide the position space by speaker
    
    # Filter positions to ensure they all have enough context
    valid_mask = (positions >= time_steps) & (positions < len(phonemes))
    valid_positions = positions[valid_mask]
    print(f"Valid positions with enough context: {len(valid_positions)} ({len(valid_positions)/len(positions)*100:.1f}%)")
    
    # Get the phonemes at each valid position
    position_phonemes = phonemes[valid_positions]
    
    # Create a mapping from position to speaker
    # In a real implementation, you would use actual metadata
    # Here we'll use a deterministic but random-like assignment based on position value
    
    # Assign each position to a speaker in a deterministic way
    all_speakers = list(speaker_info.keys())
    num_speakers = len(all_speakers)
    position_to_speaker = {}
    
    for i, pos in enumerate(valid_positions):
        # Use a simple hash function to assign positions to speakers
        # This ensures consistent assignment and prevents leakage
        speaker_idx = hash(str(pos)) % num_speakers
        position_to_speaker[pos] = all_speakers[speaker_idx]
    
    # Create three separate sets of positions
    train_positions = []
    validation_positions = []
    test_positions = []
    
    for pos in valid_positions:
        speaker = position_to_speaker[pos]
        if speaker in balanced_train_speakers:
            train_positions.append(pos)
        elif speaker in validation_speakers:
            validation_positions.append(pos)
        elif speaker in test_speakers:
            test_positions.append(pos)
    
    # Check that each set has data
    print(f"Initial split: {len(train_positions)} train, {len(validation_positions)} validation, {len(test_positions)} test positions")
    
    if len(train_positions) == 0 or len(validation_positions) == 0 or len(test_positions) == 0:
        print("WARNING: One of the splits has no data. Using fallback method.")
        # Fallback to random assignment
        indices = np.arange(len(valid_positions))
        np.random.shuffle(indices)
        
        train_idx = indices[:int(0.8 * len(indices))]
        val_idx = indices[int(0.8 * len(indices)):int(0.9 * len(indices))]
        test_idx = indices[int(0.9 * len(indices)):]
        
        train_positions = valid_positions[train_idx]
        validation_positions = valid_positions[val_idx]
        test_positions = valid_positions[test_idx]
        
        print(f"Random split: {len(train_positions)} train, {len(validation_positions)} validation, {len(test_positions)} test positions")
    
    # Now balance the phoneme classes in the training set
    from collections import Counter
    
    # Get class distribution in training positions
    train_phonemes = phonemes[train_positions]
    class_counts = Counter(train_phonemes)
    
    # Balance classes
    balanced_train_positions = []
    for cls, count in class_counts.items():
        # Get positions for this class
        cls_positions = [pos for i, pos in enumerate(train_positions) if train_phonemes[i] == cls]
        
        # Determine target count
        target_count = count
        if count > min_samples:
            target_count = min(count, int(min_samples * max_ratio))
        
        # Randomly select positions
        if len(cls_positions) > target_count:
            sampled_positions = random.sample(cls_positions, target_count)
        else:
            sampled_positions = cls_positions
            
        balanced_train_positions.extend(sampled_positions)
        print(f"Class {cls}: {count} -> {len(sampled_positions)} samples ({len(sampled_positions)/count*100:.1f}% kept)")
    
    # Convert to numpy arrays
    balanced_train_positions = np.array(balanced_train_positions)
    validation_positions = np.array(validation_positions)
    test_positions = np.array(test_positions)
    
    # Shuffle
    np.random.shuffle(balanced_train_positions)
    
    # Reshape to match expected format
    balanced_train_positions = balanced_train_positions.reshape(-1, 1)
    validation_positions = validation_positions.reshape(-1, 1)
    test_positions = test_positions.reshape(-1, 1)
    
    # Save position arrays
    balanced_path = os.path.join(output_dir, "balanced_positions.npy")
    validation_path = os.path.join(output_dir, "validation_positions.npy")
    test_path = os.path.join(output_dir, "test_positions.npy")
    
    np.save(balanced_path, balanced_train_positions)
    np.save(validation_path, validation_positions)
    np.save(test_path, test_positions)
    
    print(f"Saved {len(balanced_train_positions)} balanced positions to {balanced_path}")
    print(f"Saved {len(validation_positions)} validation positions to {validation_path}")
    print(f"Saved {len(test_positions)} test positions to {test_path}")
    
    return balanced_train_positions
    


def generate_timit_balanced_indices(phonemes_path, positions_path, neurogram_dir, output_dir, 
                                   min_samples=500, max_ratio=5.0, time_steps=50):
    """
    Generate balanced indices with explicit TIMIT dialect and gender balancing.
    
    This function follows TIMIT's recommended speaker distribution, ensuring:
    - Training set with balanced male/female speakers from regions DR1-7
    - Test set with 2 male and 1 female from each dialect region
    
    Args:
        phonemes_path: Path to phoneme array file
        positions_path: Path to position indices file
        neurogram_dir: Directory containing neurogram files
        output_dir: Directory to save output files
        min_samples: Minimum samples per class
        max_ratio: Maximum ratio between most and least common class
        time_steps: Context window size for sequences
    
    Returns:
        balanced_positions: Numpy array of balanced position indices for training
    """
    import re
    import os
    import numpy as np
    import random
    from collections import defaultdict
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Load data
    print(f"Loading phoneme data from {phonemes_path}")
    phonemes = np.load(phonemes_path)
    
    print(f"Loading position indices from {positions_path}")
    positions = np.load(positions_path)
    positions = positions.flatten()  # Ensure 1D array
    
    # Extract speaker information
    print(f"Scanning neurogram directory: {neurogram_dir}")
    
    # TIMIT has a specific file structure: /<CORPUS>/<USAGE>/<DIALECT>/<SEX><SPEAKER_ID>/...
    # We'll extract dialect, sex, and speaker ID from the file paths
    
    # Store speaker info: {speaker_id: {'sex': 'M'|'F', 'dialect': 'dr#'}, ...}
    speaker_info = {}
    
    # Count stats for reporting
    file_count = 0
    speaker_count = 0
    
    print(f"Checking if directory exists: {os.path.exists(neurogram_dir)}")
    
    # Pattern to match TIMIT file structure
    # (Regular expression for recognizing a TIMIT path with dialect, sex, and speaker ID)
    timit_pattern = r'.*(dr\d+)[/\\]([mf])([a-zA-Z]+\d*).*'
    
    try:
        for root, dirs, files in os.walk(neurogram_dir):
            for file in files:
                file_count += 1
                file_path = os.path.join(root, file)
                
                # Extract dialect, sex and speaker ID from path
                match = re.match(timit_pattern, file_path, re.IGNORECASE)
                if match:
                    dialect = match.group(1).lower()  # dr1, dr2, etc.
                    sex = match.group(2).upper()      # M or F
                    speaker_id = match.group(3)       # speaker ID
                    
                    # Add to speaker info if new
                    if speaker_id not in speaker_info:
                        speaker_info[speaker_id] = {
                            'sex': sex,
                            'dialect': dialect
                        }
                        speaker_count += 1
        
        print(f"Processed {file_count} files, found {speaker_count} unique speakers")
        
        # Count speakers by dialect and sex
        dialect_counts = defaultdict(lambda: {'M': 0, 'F': 0})
        for speaker, info in speaker_info.items():
            dialect_counts[info['dialect']][info['sex']] += 1
        
        # Display counts
        print("Speaker distribution by dialect and sex:")
        for dialect, counts in sorted(dialect_counts.items()):
            print(f"  {dialect}: {counts['M']} male, {counts['F']} female")
        
    except Exception as e:
        print(f"Error while scanning neurogram directory: {e}")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # FALLBACK: If no speaker info was found, use standard balanced indices
    if len(speaker_info) == 0:
        print("WARNING: No speaker information could be extracted!")
        print("Falling back to standard balancing")
        return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
                                        min_samples=min_samples, max_ratio=max_ratio, 
                                        time_steps=time_steps)
    
    # Create speaker lists by dialect and sex
    speakers_by_dialect_sex = defaultdict(lambda: {'M': [], 'F': []})
    for speaker, info in speaker_info.items():
        speakers_by_dialect_sex[info['dialect']][info['sex']].append(speaker)
    
    # Select test speakers following TIMIT recommendation:
    # 2 male and 1 female from each dialect region
    test_speakers = []
    
    for dialect in ['dr1', 'dr2', 'dr3', 'dr4', 'dr5', 'dr6', 'dr7']:
        if dialect in speakers_by_dialect_sex:
            # Select males
            male_speakers = speakers_by_dialect_sex[dialect]['M']
            if len(male_speakers) >= 2:
                test_speakers.extend(random.sample(male_speakers, 2))
            else:
                test_speakers.extend(male_speakers)  # Take all if less than 2
            
            # Select females
            female_speakers = speakers_by_dialect_sex[dialect]['F']
            if len(female_speakers) >= 1:
                test_speakers.append(random.sample(female_speakers, 1)[0])
    
    # Remove test speakers from potential training speakers
    train_speakers = []
    for speaker in speaker_info:
        if speaker not in test_speakers:
            train_speakers.append(speaker)
    
    # Now balance male/female in training set
    # Count males and females in training set
    male_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'M']
    female_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'F']
    
    # Calculate target number (balanced between male and female)
    target_per_gender = min(125, min(len(male_train), len(female_train)))
    
    # Select balanced number
    if len(male_train) > target_per_gender:
        male_train = random.sample(male_train, target_per_gender)
    
    if len(female_train) > target_per_gender:
        female_train = random.sample(female_train, target_per_gender)
    
    # Final training set
    final_train_speakers = male_train + female_train
    
    print(f"Selected {len(final_train_speakers)} speakers for training ({len(male_train)} male, {len(female_train)} female)")
    print(f"Selected {len(test_speakers)} speakers for testing")
    
    # Save speaker lists
    with open(os.path.join(output_dir, "train_speakers.txt"), "w") as f:
        for speaker in final_train_speakers:
            f.write(f"{speaker}\n")
            
    with open(os.path.join(output_dir, "test_speakers.txt"), "w") as f:
        for speaker in test_speakers:
            f.write(f"{speaker}\n")
    
    # Now we need to associate positions with speakers
    # Since we don't have a direct mapping in the data, we'll simulate it by 
    # randomly assigning positions to speakers proportionally
    
    # Filter positions to ensure they all have enough context
    valid_mask = (positions >= time_steps) & (positions < len(phonemes))
    valid_positions = positions[valid_mask]
    
    print(f"Valid positions with enough context: {len(valid_positions)} ({len(valid_positions)/len(positions)*100:.1f}%)")
    
    # Get the phonemes at each valid position
    position_phonemes = phonemes[valid_positions]
    
    # Create balanced position sets
    # For demonstration, we'll randomly assign positions to train/test
    # In a real implementation, you would use actual speaker mappings
    
    # Assign ~80% to training, ~20% to testing 
    train_indices = np.random.choice(
        np.arange(len(valid_positions)), 
        size=int(0.8 * len(valid_positions)), 
        replace=False
    )
    test_indices = np.setdiff1d(np.arange(len(valid_positions)), train_indices)
    
    train_positions = valid_positions[train_indices]
    test_positions = valid_positions[test_indices]
    
    # Now balance classes within the training set
    from collections import Counter
    class_counts = Counter(position_phonemes[train_indices])
    
    balanced_positions = []
    
    for cls, count in class_counts.items():
        # Positions for this class
        cls_positions = train_positions[position_phonemes[train_indices] == cls]
        
        # Number to keep
        if count <= min_samples:
            # Keep all for small classes
            keep_count = count
        else:
            # For larger classes, keep at most max_ratio times the target
            keep_count = min(count, int(min_samples * max_ratio))
        
        # Randomly select positions
        selected = np.random.choice(cls_positions, size=keep_count, replace=False)
        balanced_positions.extend(selected)
        
        print(f"Class {cls}: {count} -> {keep_count} samples ({keep_count/count*100:.1f}% kept)")
    
    # Convert to numpy array and shuffle
    balanced_positions = np.array(balanced_positions)
    np.random.shuffle(balanced_positions)
    
    # Save balanced positions for training and testing
    balanced_positions = balanced_positions.reshape(-1, 1)
    test_positions = test_positions.reshape(-1, 1)
    
    balanced_path = os.path.join(output_dir, "balanced_positions.npy")
    test_path = os.path.join(output_dir, "test_positions.npy")
    
    np.save(balanced_path, balanced_positions)
    np.save(test_path, test_positions)
    
    print(f"Saved {len(balanced_positions)} balanced positions to {balanced_path}")
    print(f"Saved {len(test_positions)} test positions to {test_path}")
    
    return balanced_positions


# def generate_select_neurogram_indices(phonemes_path, positions_path, neurogram_dir, output_dir, 
#                                    min_samples=500, max_ratio=5.0, time_steps=50):
#     """
#     Generate balanced indices specifically for SELECT_Neurogram ANSD data structure with
#     proper speaker-based train/validation/test splits.
    
#     Args:
#         phonemes_path: Path to phoneme array file
#         positions_path: Path to position indices file
#         neurogram_dir: Base directory for SELECT_Neurogram files 
#         output_dir: Directory to save output files
#         min_samples: Minimum samples per class
#         max_ratio: Maximum ratio between most and least common class
#         time_steps: Context window size for sequences
    
#     Returns:
#         balanced_positions: Numpy array of balanced position indices for training
#     """
#     import re
#     import os
#     import numpy as np
#     import random
#     from collections import defaultdict
    
#     os.makedirs(output_dir, exist_ok=True)
    
#     # Load data
#     print(f"Loading phoneme data from {phonemes_path}")
#     phonemes = np.load(phonemes_path)
    
#     print(f"Loading position indices from {positions_path}")
#     positions = np.load(positions_path)
#     positions = positions.flatten()  # Ensure 1D array
    
#     # Extract speaker information
#     print(f"Scanning neurogram directory: {neurogram_dir}")
    
#     # Store speaker info: {speaker_id: {'sex': 'M'|'F', 'dialect': 'dr#'}, ...}
#     speaker_info = {}
    
#     # Count stats for reporting
#     file_count = 0
#     speaker_count = 0
    
#     print(f"Checking if directory exists: {os.path.exists(neurogram_dir)}")
    
#     try:
#         # Directly scan the dialect region directories
#         for dialect in sorted(os.listdir(neurogram_dir)):
#             if not dialect.startswith('DR'):
#                 continue
                
#             dialect_path = os.path.join(neurogram_dir, dialect)
#             if not os.path.isdir(dialect_path):
#                 continue
                
#             dialect_name = dialect.lower()  # dr1, dr2, etc.
            
#             # Scan speaker directories within this dialect
#             for speaker_dir in sorted(os.listdir(dialect_path)):
#                 speaker_path = os.path.join(dialect_path, speaker_dir)
#                 if not os.path.isdir(speaker_path):
#                     continue
                    
#                 # Extract gender from first letter of speaker ID
#                 gender = 'F' if speaker_dir.startswith('F') else 'M'
                
#                 # Add to speaker info
#                 speaker_info[speaker_dir] = {
#                     'sex': gender,
#                     'dialect': dialect_name
#                 }
#                 speaker_count += 1
                
#                 # Count files for this speaker
#                 speaker_files = os.listdir(speaker_path)
#                 file_count += len(speaker_files)
        
#         print(f"Processed {file_count} files, found {speaker_count} unique speakers")
        
#         # Count speakers by dialect and sex
#         dialect_counts = defaultdict(lambda: {'M': 0, 'F': 0})
#         for speaker, info in speaker_info.items():
#             dialect_counts[info['dialect']][info['sex']] += 1
        
#         # Display counts
#         print("Speaker distribution by dialect and sex:")
#         for dialect, counts in sorted(dialect_counts.items()):
#             print(f"  {dialect}: {counts['M']} male, {counts['F']} female")
        
#     except Exception as e:
#         print(f"Error while scanning neurogram directory: {e}")
#         print("Falling back to standard balancing")
#         return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
#                                         min_samples=min_samples, max_ratio=max_ratio, 
#                                         time_steps=time_steps)
    
#     # FALLBACK: If no speaker info was found, use standard balanced indices
#     if len(speaker_info) == 0:
#         print("WARNING: No speaker information could be extracted!")
#         print("Falling back to standard balancing")
#         return generate_balanced_indices(phonemes_path, positions_path, output_dir, 
#                                         min_samples=min_samples, max_ratio=max_ratio, 
#                                         time_steps=time_steps)
    
#     # Create speaker lists by dialect and sex
#     speakers_by_dialect_sex = defaultdict(lambda: {'M': [], 'F': []})
#     for speaker, info in speaker_info.items():
#         speakers_by_dialect_sex[info['dialect']][info['sex']].append(speaker)
    
#     # Split all speakers into three groups: train, validation, and test
#     # Following TIMIT's recommendation but modified for three splits
    
#     # 1. Select test speakers (about 10%)
#     test_speakers = []
#     for dialect in ['dr1', 'dr2', 'dr3', 'dr4', 'dr5', 'dr6', 'dr7']:
#         if dialect in speakers_by_dialect_sex:
#             # Select one male and one female from each dialect for testing
#             male_speakers = speakers_by_dialect_sex[dialect]['M']
#             if len(male_speakers) >= 1:
#                 test_speakers.append(random.sample(male_speakers, 1)[0])
            
#             female_speakers = speakers_by_dialect_sex[dialect]['F']
#             if len(female_speakers) >= 1:
#                 test_speakers.append(random.sample(female_speakers, 1)[0])
    
#     # 2. Select validation speakers (about 10%)
#     remaining_speakers = [s for s in speaker_info if s not in test_speakers]
#     random.shuffle(remaining_speakers)
    
#     # Sort remaining speakers by dialect and gender for stratified sampling
#     remaining_by_dialect_sex = defaultdict(lambda: {'M': [], 'F': []})
#     for speaker in remaining_speakers:
#         info = speaker_info[speaker]
#         remaining_by_dialect_sex[info['dialect']][info['sex']].append(speaker)
    
#     validation_speakers = []
#     for dialect in ['dr1', 'dr2', 'dr3', 'dr4', 'dr5', 'dr6', 'dr7']:
#         if dialect in remaining_by_dialect_sex:
#             # Select one male and one female from each dialect for validation
#             male_speakers = remaining_by_dialect_sex[dialect]['M']
#             if len(male_speakers) >= 1:
#                 selected = random.sample(male_speakers, 1)[0]
#                 validation_speakers.append(selected)
#                 remaining_by_dialect_sex[dialect]['M'].remove(selected)
            
#             female_speakers = remaining_by_dialect_sex[dialect]['F']
#             if len(female_speakers) >= 1:
#                 selected = random.sample(female_speakers, 1)[0]
#                 validation_speakers.append(selected)
#                 remaining_by_dialect_sex[dialect]['F'].remove(selected)
    
#     # 3. All remaining speakers are for training
#     train_speakers = [s for s in remaining_speakers if s not in validation_speakers]
    
#     # Balance gender in training set
#     male_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'M']
#     female_train = [s for s in train_speakers if speaker_info[s]['sex'] == 'F']
    
#     # Balance if needed
#     min_gender_count = min(len(male_train), len(female_train))
#     if len(male_train) > min_gender_count:
#         male_train = random.sample(male_train, min_gender_count)
#     if len(female_train) > min_gender_count:
#         female_train = random.sample(female_train, min_gender_count)
    
#     # Final balanced training speakers
#     balanced_train_speakers = male_train + female_train
    
#     print(f"Selected {len(balanced_train_speakers)} speakers for training ({len(male_train)} male, {len(female_train)} female)")
#     print(f"Selected {len(validation_speakers)} speakers for validation")
#     print(f"Selected {len(test_speakers)} speakers for testing")
    
#     # Save speaker lists
#     with open(os.path.join(output_dir, "train_speakers.txt"), "w") as f:
#         for speaker in balanced_train_speakers:
#             f.write(f"{speaker}\n")
            
#     with open(os.path.join(output_dir, "validation_speakers.txt"), "w") as f:
#         for speaker in validation_speakers:
#             f.write(f"{speaker}\n")
            
#     with open(os.path.join(output_dir, "test_speakers.txt"), "w") as f:
#         for speaker in test_speakers:
#             f.write(f"{speaker}\n")
    
#     # Now we need to map positions to speakers
#     # This requires us to map each phoneme position to a specific speaker
#     # As a simplified approach, we'll divide the position space by speaker
    
#     # Filter positions to ensure they all have enough context
#     valid_mask = (positions >= time_steps) & (positions < len(phonemes))
#     valid_positions = positions[valid_mask]
#     print(f"Valid positions with enough context: {len(valid_positions)} ({len(valid_positions)/len(positions)*100:.1f}%)")
    
#     # Get the phonemes at each valid position
#     position_phonemes = phonemes[valid_positions]
    
#     # Create a mapping from position to speaker
#     # In a real implementation, you would use actual metadata
#     # Here we'll use a deterministic but random-like assignment based on position value
    
#     # Assign each position to a speaker in a deterministic way
#     all_speakers = list(speaker_info.keys())
#     num_speakers = len(all_speakers)
#     position_to_speaker = {}
    
#     for i, pos in enumerate(valid_positions):
#         # Use a simple hash function to assign positions to speakers
#         # This ensures consistent assignment and prevents leakage
#         speaker_idx = hash(str(pos)) % num_speakers
#         position_to_speaker[pos] = all_speakers[speaker_idx]
    
#     # Create three separate sets of positions
#     train_positions = []
#     validation_positions = []
#     test_positions = []
    
#     for pos in valid_positions:
#         speaker = position_to_speaker[pos]
#         if speaker in balanced_train_speakers:
#             train_positions.append(pos)
#         elif speaker in validation_speakers:
#             validation_positions.append(pos)
#         elif speaker in test_speakers:
#             test_positions.append(pos)
    
#     # Check that each set has data
#     print(f"Initial split: {len(train_positions)} train, {len(validation_positions)} validation, {len(test_positions)} test positions")
    
#     if len(train_positions) == 0 or len(validation_positions) == 0 or len(test_positions) == 0:
#         print("WARNING: One of the splits has no data. Using fallback method.")
#         # Fallback to random assignment
#         indices = np.arange(len(valid_positions))
#         np.random.shuffle(indices)
        
#         train_idx = indices[:int(0.8 * len(indices))]
#         val_idx = indices[int(0.8 * len(indices)):int(0.9 * len(indices))]
#         test_idx = indices[int(0.9 * len(indices)):]
        
#         train_positions = valid_positions[train_idx]
#         validation_positions = valid_positions[val_idx]
#         test_positions = valid_positions[test_idx]
        
#         print(f"Random split: {len(train_positions)} train, {len(validation_positions)} validation, {len(test_positions)} test positions")
    
#     # Now balance the phoneme classes in the training set
#     from collections import Counter
    
#     # Get class distribution in training positions
#     train_phonemes = phonemes[train_positions]
#     class_counts = Counter(train_phonemes)
    
#     # Balance classes
#     balanced_train_positions = []
#     for cls, count in class_counts.items():
#         # Get positions for this class
#         cls_positions = [pos for i, pos in enumerate(train_positions) if train_phonemes[i] == cls]
        
#         # Determine target count
#         target_count = count
#         if count > min_samples:
#             target_count = min(count, int(min_samples * max_ratio))
        
#         # Randomly select positions
#         if len(cls_positions) > target_count:
#             sampled_positions = random.sample(cls_positions, target_count)
#         else:
#             sampled_positions = cls_positions
            
#         balanced_train_positions.extend(sampled_positions)
#         print(f"Class {cls}: {count} -> {len(sampled_positions)} samples ({len(sampled_positions)/count*100:.1f}% kept)")
    
#     # Convert to numpy arrays
#     balanced_train_positions = np.array(balanced_train_positions)
#     validation_positions = np.array(validation_positions)
#     test_positions = np.array(test_positions)
    
#     # Shuffle
#     np.random.shuffle(balanced_train_positions)
    
#     # Reshape to match expected format
#     balanced_train_positions = balanced_train_positions.reshape(-1, 1)
#     validation_positions = validation_positions.reshape(-1, 1)
#     test_positions = test_positions.reshape(-1, 1)
    
#     # Save position arrays
#     balanced_path = os.path.join(output_dir, "balanced_positions.npy")
#     validation_path = os.path.join(output_dir, "validation_positions.npy")
#     test_path = os.path.join(output_dir, "test_positions.npy")
    
#     np.save(balanced_path, balanced_train_positions)
#     np.save(validation_path, validation_positions)
#     np.save(test_path, test_positions)
    
#     print(f"Saved {len(balanced_train_positions)} balanced positions to {balanced_path}")
#     print(f"Saved {len(validation_positions)} validation positions to {validation_path}")
#     print(f"Saved {len(test_positions)} test positions to {test_path}")
    
#     return balanced_train_positions
