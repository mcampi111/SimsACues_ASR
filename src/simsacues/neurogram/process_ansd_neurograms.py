"""
process_ansd_neurograms.py — Apply ANSD perturbations to neurograms

Reads healthy neurograms (clean or noisy), applies one of four perturbation
types with equal probability, and saves the result.

Designed for SLURM cluster execution with job arrays.

Neurograms are at 500 Hz sampling rate (2 ms bins), 150 frequency channels.
"""

import os
import sys
import json
import numpy as np
from scipy.io import loadmat, savemat
import logging
import argparse

from simsacues.neurogram.perturbations import apply_random_perturbation, NEUROGRAM_SAMPLING_RATE
from simsacues.noise import add_cognitive_noise

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler('ansd_neurogram_processing.log'),
        logging.StreamHandler(sys.stdout)
    ]
)


def process_neurograms(input_base, output_base, task_id, num_tasks,
                       condition='silence', save_perturbation_map=True):
    """
    Process neurograms: apply ANSD perturbations and optionally cognitive noise.

    Parameters
    ----------
    input_base : str
        Base directory containing TRAIN/ and TEST/ subdirectories with
        healthy neurogram .mat files.
    output_base : str
        Base directory for output perturbed neurograms.
    task_id : int
        SLURM task ID (0-based).
    num_tasks : int
        Total number of SLURM tasks.
    condition : str
        'silence' for clean neurograms, 'noise' for noisy neurograms.
        For 'noise' condition, input files end in '_with_noise.mat'.
    save_perturbation_map : bool
        If True, save a JSON mapping of filename → perturbation type.
    """
    np.random.seed(42 + task_id)

    perturbation_map = {}

    # Determine file suffix based on condition
    if condition == 'noise':
        input_suffix = '_with_noise.mat'
        output_suffix = '_neurogram_ansd.mat'
    else:
        input_suffix = '_neurogram.mat'
        output_suffix = '_neurogram_ansd.mat'

    for dataset in ['TRAIN', 'TEST']:
        input_path = os.path.join(input_base, dataset)
        output_path = os.path.join(output_base, dataset)
        os.makedirs(output_path, exist_ok=True)

        # Collect all matching .mat files
        all_files = []
        for dr_dir in sorted(os.listdir(input_path)):
            if not dr_dir.startswith('DR'):
                continue
            dr_path = os.path.join(input_path, dr_dir)

            for speaker_dir in sorted(os.listdir(dr_path)):
                if speaker_dir.startswith('.'):
                    continue
                speaker_path = os.path.join(dr_path, speaker_dir)

                for f in sorted(os.listdir(speaker_path)):
                    if f.endswith(input_suffix):
                        all_files.append(os.path.join(speaker_path, f))

        # Distribute files across tasks
        files_per_task = len(all_files) // num_tasks
        start_idx = task_id * files_per_task
        end_idx = start_idx + files_per_task if task_id < num_tasks - 1 else len(all_files)
        task_files = all_files[start_idx:end_idx]

        logging.info(f"Processing {dataset}: {len(task_files)} files for task {task_id}")

        for file_path in task_files:
            try:
                # Construct output path preserving directory structure
                relative_path = os.path.relpath(file_path, input_base)
                output_file = os.path.join(output_base, relative_path)
                output_file = output_file.replace(input_suffix, output_suffix)
                os.makedirs(os.path.dirname(output_file), exist_ok=True)

                # Skip existing files
                if os.path.exists(output_file):
                    continue

                # Load neurogram
                mat_data = loadmat(file_path)
                neurogram = mat_data['r_mean_downsampled']

                if neurogram.ndim != 2:
                    logging.warning(f"Unexpected shape {neurogram.shape}: {file_path}")
                    continue

                # Apply random ANSD perturbation
                perturbed, pert_type, pert_params = apply_random_perturbation(
                    neurogram, sampling_rate=NEUROGRAM_SAMPLING_RATE
                )

                # Save
                save_dict = {
                    'r_mean_downsampled': perturbed,
                    'perturbation_type': pert_type,
                    'original_filename': os.path.basename(file_path),
                }
                # Preserve center frequencies if available
                if 'center_frequencies' in mat_data:
                    save_dict['center_frequencies'] = mat_data['center_frequencies']
                # Preserve noise info if available
                if 'target_snr_db' in mat_data:
                    save_dict['target_snr_db'] = mat_data['target_snr_db']

                savemat(output_file, save_dict)

                # Track perturbation assignment
                out_filename = os.path.basename(output_file)
                perturbation_map[out_filename] = pert_type

                logging.info(f"Processed {os.path.basename(file_path)} → {pert_type}")

            except Exception as e:
                logging.error(f"Error processing {file_path}: {e}")

    # Save perturbation map
    if save_perturbation_map and perturbation_map:
        map_file = os.path.join(output_base, f'perturbation_types_task{task_id}.json')
        with open(map_file, 'w') as f:
            json.dump(perturbation_map, f, indent=2)
        logging.info(f"Saved perturbation map: {map_file}")


def main():
    parser = argparse.ArgumentParser(description='Apply ANSD perturbations to neurograms')
    parser.add_argument('--input-base', type=str, required=True,
                        help='Base directory with healthy neurograms')
    parser.add_argument('--output-base', type=str, required=True,
                        help='Output directory for perturbed neurograms')
    parser.add_argument('--condition', type=str, default='silence',
                        choices=['silence', 'noise'],
                        help='silence or noise condition')
    args = parser.parse_args()

    task_id = int(os.environ.get('SLURM_ARRAY_TASK_ID', 0))
    num_tasks = int(os.environ.get('SLURM_ARRAY_TASK_COUNT', 1))

    process_neurograms(
        args.input_base, args.output_base,
        task_id, num_tasks,
        condition=args.condition
    )


if __name__ == '__main__':
    main()
