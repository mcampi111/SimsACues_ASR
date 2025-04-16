#!/usr/bin/env python3
import os
import sys
from pathlib import Path

def print_files_in_dir(directory):
    """Print all files in the given directory."""
    try:
        files = sorted(os.listdir(directory))
        if not files:
            print(f"  [!] No files found in {directory}")
            return False
        
        print(f"  Files in {directory}:")
        for file in files:
            file_path = os.path.join(directory, file)
            file_size = os.path.getsize(file_path)
            print(f"    - {file} ({file_size} bytes)")
        return True
    except Exception as e:
        print(f"  [!] Error accessing {directory}: {e}")
        return False

def check_label_directories(base_dir):
    """Check all label directories under the given base directory."""
    # Define the expected directory structure
    expected_dirs = {
        'train': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence'],
        'test': ['ansd_noise', 'ansd_silence', 'healthy_noise', 'healthy_silence']
    }
    
    # Expected file patterns (partial matches)
    expected_file_patterns = [
        'phoneme_mapping', 
        'Phonemes39consecutive', 
        'Phonemes39_position_index'
    ]
    
    print(f"Checking label directories under: {base_dir}")
    print("=" * 70)
    
    # Track any missing components
    missing_directories = []
    missing_files = {}
    
    # Check each main directory
    for main_dir, sub_dirs in expected_dirs.items():
        main_dir_path = os.path.join(base_dir, main_dir)
        
        if not os.path.exists(main_dir_path):
            print(f"[!] Missing main directory: {main_dir_path}")
            missing_directories.append(main_dir_path)
            continue
            
        print(f"\nChecking {main_dir} directory:")
        
        # Check each sub-directory
        for sub_dir in sub_dirs:
            sub_dir_path = os.path.join(main_dir_path, sub_dir)
            
            if not os.path.exists(sub_dir_path):
                print(f"  [!] Missing sub-directory: {sub_dir_path}")
                missing_directories.append(sub_dir_path)
                continue
                
            print(f"\n  Checking {sub_dir} directory:")
            
            # Check for expected files
            files = os.listdir(sub_dir_path)
            found_patterns = [False] * len(expected_file_patterns)
            
            for file in files:
                for i, pattern in enumerate(expected_file_patterns):
                    if pattern in file:
                        found_patterns[i] = True
            
            # Report missing file patterns
            missing_patterns = []
            for i, found in enumerate(found_patterns):
                if not found:
                    missing_patterns.append(expected_file_patterns[i])
            
            if missing_patterns:
                missing_files[sub_dir_path] = missing_patterns
                print(f"  [!] Missing file patterns in {sub_dir_path}: {', '.join(missing_patterns)}")
            
            # Print all files in the directory
            print_files_in_dir(sub_dir_path)
    
    # Print summary
    print("\n" + "=" * 70)
    print("SUMMARY:")
    
    if not missing_directories and not missing_files:
        print("✓ All expected directories and file patterns found!")
    else:
        if missing_directories:
            print(f"[!] Missing directories ({len(missing_directories)}):")
            for dir_path in missing_directories:
                print(f"  - {dir_path}")
        
        if missing_files:
            print(f"[!] Directories with missing file patterns ({len(missing_files)}):")
            for dir_path, patterns in missing_files.items():
                print(f"  - {dir_path}: missing {', '.join(patterns)}")

if __name__ == "__main__":
    # Use the current directory if no argument is provided
    if len(sys.argv) > 1:
        base_dir = sys.argv[1]
    else:
        # Default to the Phonemes39_posindex_labels directory
        current_dir = os.getcwd()
        if os.path.basename(current_dir) == "healthy_noise":
            # If we're in a subdirectory, go up to the Phonemes39_posindex_labels dir
            base_dir = os.path.dirname(os.path.dirname(current_dir))
        else:
            # Otherwise use current directory
            base_dir = current_dir
    
    check_label_directories(base_dir)
