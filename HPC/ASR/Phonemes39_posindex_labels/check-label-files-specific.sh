#!/bin/bash

BASE_DIR="/pasteur/appa/homes/mcampi/ASR_ANSD/ASR/Phonemes39_posindex_labels"

# Define expected datasets and conditions
TRAIN_DATASETS=("healthy_silence" "healthy_noise" "ansd_silence" "ansd_noise")
TEST_DATASETS=("healthy_silence" "healthy_noise" "ansd_silence" "ansd_noise")
TEST_CONDITIONS=("default" "snr0" "snr5" "snr10" "snr15" "snr-5")

# Define expected file types
FILE_TYPES=("Phonemes39consecutive" "Phonemes39_position_index" "phoneme_mapping")

echo "=== Checking TRAIN directories ==="
for dataset in "${TRAIN_DATASETS[@]}"; do
    dir="${BASE_DIR}/train/${dataset}"
    echo "Checking ${dir}..."
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "WARNING: Directory $dir does not exist!"
        continue
    fi
    
    # Check for files (without condition suffix for train)
    for type in "${FILE_TYPES[@]}"; do
        if [[ "$type" == "phoneme_mapping" ]]; then
            file="${dir}/${type}_train_${dataset}.txt"
        else
            file="${dir}/${type}_true_train_${dataset}.npy"
        fi
        
        if [ -f "$file" ]; then
            filesize=$(stat -c%s "$file")
            echo "  ✓ Found $file (${filesize} bytes)"
        else
            echo "  ✗ MISSING: $file"
        fi
    done
    
    # List any unexpected files
    echo "  Other files in directory:"
    ls -la "$dir" | grep -v -E "$(echo "${FILE_TYPES[@]}" | tr ' ' '|')" | grep -v "total"
    echo ""
done

echo ""
echo "=== Checking TEST directories ==="
for dataset in "${TEST_DATASETS[@]}"; do
    dir="${BASE_DIR}/test/${dataset}"
    echo "Checking ${dir}..."
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "WARNING: Directory $dir does not exist!"
        continue
    fi
    
    # Check for files with each condition
    for condition in "${TEST_CONDITIONS[@]}"; do
        echo "  Checking condition: ${condition}"
        for type in "${FILE_TYPES[@]}"; do
            if [[ "$type" == "phoneme_mapping" ]]; then
                file="${dir}/${type}_test_${condition}.txt"
            else
                file="${dir}/${type}_true_test_${condition}.npy"
            fi
            
            if [ -f "$file" ]; then
                filesize=$(stat -c%s "$file")
                echo "    ✓ Found $file (${filesize} bytes)"
            else
                echo "    ✗ MISSING: $file"
            fi
        done
    done
    
    # List any unexpected files
    echo "  Other files in directory:"
    other_files=$(ls -la "$dir" | grep -v -E "$(echo "${FILE_TYPES[@]}" | tr ' ' '|')" | grep -v "total" | wc -l)
    if [ "$other_files" -gt 0 ]; then
        ls -la "$dir" | grep -v -E "$(echo "${FILE_TYPES[@]}" | tr ' ' '|')" | grep -v "total" | head -5
        if [ "$other_files" -gt 5 ]; then
            echo "    ... and $(($other_files - 5)) more files"
        fi
    else
        echo "    No additional files found"
    fi
    echo ""
done

echo "Check complete!"
