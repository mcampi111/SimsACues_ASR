% convert_neurogram_format.m
%
% This script converts the noisy neurogram data from the cell array format 
% to a single concatenated matrix format to match the clean neurogram format

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
noisy_file = fullfile(base_dir, 'TIMIT_neurogram_with_noise.mat');
output_file = fullfile(base_dir, 'TIMIT_neurogram_with_noise_concatenated.mat');

% Load clean file to check its format
clean_file = fullfile(base_dir, 'TIMIT_neurogram.mat');
clean_info = whos('-file', clean_file);
fprintf('Clean file structure:\n');
for i = 1:length(clean_info)
    fprintf('  %s: %s, Size: %s\n', clean_info(i).name, clean_info(i).class, mat2str(clean_info(i).size));
end

% Load noisy file
fprintf('\nLoading noisy neurogram file: %s\n', noisy_file);
try
    noisy_data = load(noisy_file);
    fprintf('Successfully loaded noisy file with %d neurograms\n', length(noisy_data.all_neurograms));
catch err
    fprintf('Error loading noisy file: %s\n', err.message);
    return;
end

% Inspect a few neurograms to verify their structure
fprintf('\nInspecting first few neurograms:\n');
for i = 1:min(5, length(noisy_data.all_neurograms))
    neurogram = noisy_data.all_neurograms{i};
    fprintf('  Neurogram %d: %s (length: %d)\n', i, mat2str(size(neurogram)), size(neurogram, 1));
end

% Calculate total size needed
total_rows = 0;
fprintf('Calculating total size...\n');
for i = 1:length(noisy_data.all_neurograms)
    total_rows = total_rows + size(noisy_data.all_neurograms{i}, 1);
    if mod(i, 10000) == 0
        fprintf('  Processed %d/%d neurograms\n', i, length(noisy_data.all_neurograms));
    end
end

% Get number of columns (should be consistent)
n_cols = size(noisy_data.all_neurograms{1}, 2);

fprintf('Creating concatenated matrix with size [%d, %d]...\n', total_rows, n_cols);

% Create the concatenated matrix
TIMIT_neurogram_with_noise = zeros(total_rows, n_cols);
row_idx = 1;

% Also create a mapping file to track where each original neurogram starts
neurogram_mapping = struct();
neurogram_mapping.start_indices = zeros(length(noisy_data.all_neurograms), 1);
neurogram_mapping.lengths = zeros(length(noisy_data.all_neurograms), 1);
neurogram_mapping.sentence_ids = noisy_data.all_sentence_ids;
neurogram_mapping.snrs = noisy_data.all_snrs;

% Concatenate neurograms
fprintf('Concatenating neurograms...\n');
for i = 1:length(noisy_data.all_neurograms)
    if mod(i, 10000) == 0
        fprintf('  Concatenated %d/%d neurograms\n', i, length(noisy_data.all_neurograms));
    end
    
    % Get current neurogram
    curr_neurogram = noisy_data.all_neurograms{i};
    curr_length = size(curr_neurogram, 1);
    
    % Store mapping information
    neurogram_mapping.start_indices(i) = row_idx;
    neurogram_mapping.lengths(i) = curr_length;
    
    % Add to the concatenated matrix
    end_idx = row_idx + curr_length - 1;
    TIMIT_neurogram_with_noise(row_idx:end_idx, :) = curr_neurogram;
    
    % Update row index
    row_idx = end_idx + 1;
end

fprintf('Final concatenated matrix size: [%d, %d]\n', size(TIMIT_neurogram_with_noise, 1), size(TIMIT_neurogram_with_noise, 2));

% Also save the center frequencies
center_frequencies = noisy_data.center_frequencies;

% Save the concatenated matrix and mapping
fprintf('Saving concatenated matrix to %s\n', output_file);
save(output_file, 'TIMIT_neurogram_with_noise', 'center_frequencies', 'neurogram_mapping', '-v7.3');

% Compare to original clean neurogram
clean_data = load(clean_file);
clean_var_name = fieldnames(clean_data);
clean_matrix = clean_data.(clean_var_name{1});

fprintf('\nComparison summary:\n');
fprintf('  Clean neurogram matrix size: [%d, %d]\n', size(clean_matrix));
fprintf('  Converted noisy neurogram matrix size: [%d, %d]\n', size(TIMIT_neurogram_with_noise));
diff_rows = size(clean_matrix, 1) - size(TIMIT_neurogram_with_noise, 1);
diff_percent = (diff_rows / size(clean_matrix, 1)) * 100;
fprintf('  Size difference: %d rows (%.2f%%)\n', diff_rows, diff_percent);

fprintf('\nConversion complete!\n');
