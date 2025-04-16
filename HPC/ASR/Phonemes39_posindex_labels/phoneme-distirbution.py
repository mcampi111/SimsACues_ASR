#!/usr/bin/env python3
import os
import sys
import numpy as np
from collections import Counter
from pathlib import Path

def load_phoneme_mapping(mapping_file):
    """Load phoneme mapping from a text file."""
    mapping = {}
    with open(mapping_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("Phoneme Mapping"):
                continue
            try:
                idx, phoneme = line.split(': ')
                # Store using integer key
                mapping[int(idx)] = phoneme
            except ValueError:
                continue
    return mapping

def analyze_phoneme_distribution(npy_file, mapping_file, output_file=None):
    """Analyze the distribution of phonemes in the given NumPy array."""
    # Load the phoneme mapping
    phoneme_mapping = load_phoneme_mapping(mapping_file)
    if not phoneme_mapping:
        print(f"Error: Could not load phoneme mapping from {mapping_file}")
        return None
    
    # Load the phoneme indices
    try:
        # Try loading the consecutive phonemes file if available
        if 'consecutive' in npy_file:
            phoneme_indices = np.load(npy_file)
        # Otherwise, use the position index file
        else:
            position_indices = np.load(npy_file)
            # Convert position indices to phoneme indices (just take the values)
            phoneme_indices = position_indices
    except Exception as e:
        print(f"Error loading NumPy file {npy_file}: {e}")
        return None
    
    # Count the phoneme occurrences
    if phoneme_indices.ndim > 1:
        # Flatten the array if it's multi-dimensional
        phoneme_indices = phoneme_indices.flatten()
    
    # Count occurrences
    phoneme_counts = Counter(phoneme_indices)
    
    # Create a dictionary mapping phoneme labels to counts
    phoneme_distribution = {}
    for idx, count in phoneme_counts.items():
        # Convert float to int for mapping lookup (important fix!)
        idx_int = int(idx) if isinstance(idx, (float, np.float32, np.float64)) else idx
        
        if idx_int in phoneme_mapping:
            phoneme_distribution[phoneme_mapping[idx_int]] = count
        else:
            phoneme_distribution[f"Unknown-{idx}"] = count
    
    # Sort by count (descending)
    sorted_distribution = dict(sorted(phoneme_distribution.items(), key=lambda x: x[1], reverse=True))
    
    # Print the distribution
    file_name = os.path.basename(npy_file)
    print(f"\nPhoneme distribution for {file_name}:")
    print("=" * 50)
    total_phonemes = sum(sorted_distribution.values())
    print(f"Total phonemes: {total_phonemes}")
    print("\nTop phonemes by frequency:")
    print(f"{'Phoneme':<10} {'Count':<10} {'Percentage':<10}")
    print("-" * 30)
    for phoneme, count in sorted_distribution.items():
        percentage = (count / total_phonemes) * 100
        print(f"{phoneme:<10} {count:<10} {percentage:.2f}%")
    
    # Save to text file if output_file is specified
    if output_file:
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w') as f:
            f.write(f"Phoneme distribution for {file_name}:\n")
            f.write("=" * 50 + "\n")
            f.write(f"Total phonemes: {total_phonemes}\n\n")
            f.write("Phoneme distribution by frequency:\n")
            f.write(f"{'Phoneme':<10} {'Count':<10} {'Percentage':<10}\n")
            f.write("-" * 30 + "\n")
            for phoneme, count in sorted_distribution.items():
                percentage = (count / total_phonemes) * 100
                f.write(f"{phoneme:<10} {count:<10} {percentage:.2f}%\n")
        print(f"\nDistribution saved to: {output_file}")
    
    return sorted_distribution

def analyze_directory(directory, output_dir=None):
    """Analyze all phoneme distributions in the given directory."""
    # Find all .npy files containing "consecutive" (we prefer these for distribution analysis)
    consecutive_files = list(Path(directory).glob("*consecutive*.npy"))
    
    # If no consecutive files found, look for position index files
    if not consecutive_files:
        position_files = list(Path(directory).glob("*position_index*.npy"))
        if not position_files:
            print(f"No phoneme data files found in {directory}")
            return
        npy_files = position_files
    else:
        npy_files = consecutive_files
    
    # Find mapping files
    mapping_files = list(Path(directory).glob("*phoneme_mapping*.txt"))
    if not mapping_files:
        print(f"No phoneme mapping files found in {directory}")
        return
    
    # Use the first mapping file (assuming they're all similar)
    mapping_file = mapping_files[0]
    
    # Analyze each npy file
    all_distributions = {}
    for npy_file in npy_files:
        # Create output file path if output_dir is specified
        output_file = None
        if output_dir:
            output_file = os.path.join(output_dir, f"{npy_file.stem}_distribution.txt")
        
        distribution = analyze_phoneme_distribution(str(npy_file), str(mapping_file), output_file)
        if distribution:
            all_distributions[str(npy_file)] = distribution
    
    return all_distributions

def analyze_all_conditions(base_dir, output_dir=None):
    """Analyze phoneme distributions for all conditions."""
    # Define the directory structure
    conditions = {
        'train': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence'],
        'test': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence']
    }
    
    all_results = {}
    
    # Create a summary file
    summary_file = os.path.join(output_dir, "phoneme_distribution_summary.txt") if output_dir else None
    if summary_file:
        os.makedirs(os.path.dirname(summary_file), exist_ok=True)
        with open(summary_file, 'w') as f:
            f.write("Phoneme Distribution Summary\n")
            f.write("=" * 50 + "\n\n")
    
    for split, condition_dirs in conditions.items():
        split_dir = os.path.join(base_dir, split)
        if not os.path.exists(split_dir):
            print(f"Directory does not exist: {split_dir}")
            continue
        
        for condition in condition_dirs:
            condition_dir = os.path.join(split_dir, condition)
            if not os.path.exists(condition_dir):
                print(f"Directory does not exist: {condition_dir}")
                continue
            
            print(f"\nAnalyzing {split}/{condition}:")
            print("=" * 50)
            
            # Create condition-specific output directory
            condition_output_dir = None
            if output_dir:
                condition_output_dir = os.path.join(output_dir, split, condition)
                os.makedirs(condition_output_dir, exist_ok=True)
            
            results = analyze_directory(condition_dir, condition_output_dir)
            if results:
                all_results[f"{split}/{condition}"] = results
                
                # Add to summary file
                if summary_file:
                    with open(summary_file, 'a') as f:
                        f.write(f"\n{split}/{condition}:\n")
                        f.write("-" * 30 + "\n")
                        
                        # For each numpy file
                        for npy_file, distribution in results.items():
                            f.write(f"\n  {os.path.basename(npy_file)}:\n")
                            total = sum(distribution.values())
                            
                            # Show top 10 phonemes
                            f.write("  Top 10 phonemes:\n")
                            for i, (phoneme, count) in enumerate(list(distribution.items())[:10]):
                                percentage = (count / total) * 100
                                f.write(f"    {i+1}. {phoneme}: {count} ({percentage:.2f}%)\n")

def ascii_bar_chart(data, title, max_width=50):
    """Create a simple ASCII bar chart."""
    max_value = max(data.values())
    scale = max_width / max_value if max_value > 0 else 1
    
    result = [title, "=" * len(title)]
    
    # Get the maximum label length for alignment
    max_label_len = max(len(str(label)) for label in data.keys())
    
    for label, value in data.items():
        bar_length = int(value * scale)
        bar = "#" * bar_length
        result.append(f"{str(label):<{max_label_len}} | {bar} {value}")
    
    return "\n".join(result)

def create_ascii_distribution_charts(base_dir, output_dir):
    """Create ASCII bar charts for phoneme distributions."""
    
    # Define the directory structure
    conditions = {
        'train': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence'],
        'test': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence']
    }
    
    charts_file = os.path.join(output_dir, "phoneme_ascii_charts.txt")
    os.makedirs(os.path.dirname(charts_file), exist_ok=True)
    
    with open(charts_file, 'w') as f:
        f.write("Phoneme Distribution ASCII Charts\n")
        f.write("=" * 50 + "\n\n")
        
        for split, condition_dirs in conditions.items():
            for condition in condition_dirs:
                condition_dir = os.path.join(base_dir, split, condition)
                if not os.path.exists(condition_dir):
                    continue
                
                # Find npy files (prefer consecutive)
                consecutive_files = list(Path(condition_dir).glob("*consecutive*.npy"))
                if not consecutive_files:
                    continue
                
                # Find mapping file
                mapping_files = list(Path(condition_dir).glob("*phoneme_mapping*.txt"))
                if not mapping_files:
                    continue
                
                # For each npy file (just use first one for simplicity)
                npy_file = consecutive_files[0]
                mapping_file = mapping_files[0]
                
                # Get distribution
                distribution = analyze_phoneme_distribution(str(npy_file), str(mapping_file))
                if not distribution:
                    continue
                
                # Get top 15 phonemes
                top_phonemes = dict(list(distribution.items())[:15])
                
                # Create ASCII chart
                chart_title = f"{split}/{condition} - {os.path.basename(npy_file)}"
                chart = ascii_bar_chart(top_phonemes, chart_title)
                
                f.write(chart + "\n\n")
                f.write("-" * 50 + "\n\n")
    
    print(f"\nASCII charts saved to: {charts_file}")

def main():
    if len(sys.argv) > 1:
        base_dir = sys.argv[1]
    else:
        # Try to detect the current working directory
        cwd = os.getcwd()
        if os.path.basename(cwd) in ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence']:
            # We're in a condition directory, go up to the Phonemes39_posindex_labels
            base_dir = os.path.dirname(os.path.dirname(cwd))
        else:
            base_dir = cwd
    
    # Create output directory for text files
    output_dir = os.path.join(os.getcwd(), "phoneme_distribution_results_fixed")
    
    print(f"Analyzing phoneme distributions in: {base_dir}")
    print(f"Saving results to: {output_dir}")
    
    # Analyze all conditions and create text outputs
    analyze_all_conditions(base_dir, output_dir)
    
    # Create ASCII bar charts (as a simple visualization alternative to matplotlib)
    create_ascii_distribution_charts(base_dir, output_dir)

if __name__ == "__main__":
    main()
