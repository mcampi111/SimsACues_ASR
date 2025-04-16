% convert_test_neurograms.m
%
% This script converts all test noisy neurogram data from the cell array format 
% to a single concatenated matrix format to match the clean neurogram format

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
input_dir = fullfile(base_dir, 'TIMIT_mat');
output_dir = fullfile(base_dir, 'TIMIT_mat');

% List of noise test files to convert
noise_files = {
    'TIMIT_neurogram_test_with_noise_default.mat',
    'TIMIT_neurogram_test_with_noise_snr_0.mat',
    'TIMIT_neurogram_test_with_noise_snr_5.mat',
    'TIMIT_neurogram_test_with_noise_snr_10.mat',
    'TIMIT_neurogram_test_with_noise_snr_15.mat',
    'TIMIT_neurogram_test_with_noise_snr_neg5.mat',
    'TIMIT_neurogram_test_with_noise.mat'
};

% Load clean file to check its format
clean_file = fullfile(input_dir, 'TIMIT_neurogram_test.mat');
clean_info = whos('-file', clean_file);
fprintf('Clean test file structure:\n');
for i = 1:length(clean_info)
    fprintf('  %s: %s, Size: %s\n', clean_info(i).name, clean_info(i).class, mat2str(clean_info(i).size));
end

% Process each noisy test file
for file_idx = 1:length(noise_files)
    noisy_file = fullfile(input_dir, noise_files{file_idx});
    
    % Generate output filename
    [~, filename_base, ~] = fileparts(noise_files{file_idx});
    output_file = fullfile(output_dir, [filename_base, '_concatenated.mat']);
    
    fprintf('\n\n%s\n', repmat('=', 1, 80));
    fprintf('Processing file %d/%d: %s\n', file_idx, length(noise_files), noisy_file);
    fprintf('%s\n', repmat('=', 1, 80));
    
    % Check if output file already exists
    if exist(output_file, 'file')
        fprintf('Output file already exists: %s. Skipping...\n', output_file);
        continue;
    end
    
    % Load noisy file
    fprintf('Loading noisy neurogram file: %s\n', noisy_file);
    try
        noisy_data = load(noisy_file);
        
        % Check if data is in the expected format
        if ~isfield(noisy_data, 'all_neurograms')
            fprintf('Error: File does not contain "all_neurograms" field. Skipping...\n');
            continue;
        end
        
        fprintf('Successfully loaded noisy file with %d neurograms\n', length(noisy_data.all_neurograms));
    catch err
        fprintf('Error loading noisy file: %s\n', err.message);
        continue;
    end
    
    % Inspect a few neurograms to verify their structure
    fprintf('\nInspecting first few neurograms:\n');
    for i = 1:min(3, length(noisy_data.all_neurograms))
        neurogram = noisy_data.all_neurograms{i};
        fprintf('  Neurogram %d: %s (length: %d)\n', i, mat2str(size(neurogram)), size(neurogram, 1));
    end
    
    % Calculate total size needed
    total_rows = 0;
    fprintf('Calculating total size...\n');
    for i = 1:length(noisy_data.all_neurograms)
        total_rows = total_rows + size(noisy_data.all_neurograms{i}, 1);
        if mod(i, 1000) == 0
            fprintf('  Processed %d/%d neurograms\n', i, length(noisy_data.all_neurograms));
        end
    end
    
    % Get number of columns (should be consistent)
    n_cols = size(noisy_data.all_neurograms{1}, 2);
    
    fprintf('Creating concatenated matrix with size [%d, %d]...\n', total_rows, n_cols);
    
    % Create the concatenated matrix
    % Use the same variable name convention as the original file
    var_name = ['TIMIT_neurogram_', strrep(filename_base, 'TIMIT_neurogram_', '')];
    eval([var_name, ' = zeros(total_rows, n_cols);']);
    
    row_idx = 1;
    
    % Also create a mapping file to track where each original neurogram starts
    neurogram_mapping = struct();
    neurogram_mapping.start_indices = zeros(length(noisy_data.all_neurograms), 1);
    neurogram_mapping.lengths = zeros(length(noisy_data.all_neurograms), 1);
    
    % Add sentence IDs and SNRs if they exist
    if isfield(noisy_data, 'all_sentence_ids')
        neurogram_mapping.sentence_ids = noisy_data.all_sentence_ids;
    end
    if isfield(noisy_data, 'all_snrs')
        neurogram_mapping.snrs = noisy_data.all_snrs;
    end
    
    % Concatenate neurograms
    fprintf('Concatenating neurograms...\n');
    for i = 1:length(noisy_data.all_neurograms)
        if mod(i, 1000) == 0
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
        eval([var_name, '(row_idx:end_idx, :) = curr_neurogram;']);
        
        % Update row index
        row_idx = end_idx + 1;
    end
    
    fprintf('Final concatenated matrix size: [%d, %d]\n', eval(['size(', var_name, ', 1)']), eval(['size(', var_name, ', 2)']));
    
    % Also save the center frequencies if they exist
    if isfield(noisy_data, 'center_frequencies')
        center_frequencies = noisy_data.center_frequencies;
    end
    
    % Save the concatenated matrix and mapping
    fprintf('Saving concatenated matrix to %s\n', output_file);
    
    % Prepare variable list for saving
    save_vars = {var_name, 'neurogram_mapping'};
    if exist('center_frequencies', 'var')
        save_vars{end+1} = 'center_frequencies';
    end
    
    % Build save command dynamically
    save_cmd = sprintf('save(''%s'', ', output_file);
    for i = 1:length(save_vars)
        if i > 1
            save_cmd = [save_cmd, ', '];
        end
        
        % Handle the concatenated matrix variable specially
        if i == 1
            save_cmd = [save_cmd, '''', save_vars{i}, ''''];
        else
            save_cmd = [save_cmd, '''', save_vars{i}, ''''];
        end
    end
    save_cmd = [save_cmd, ', ''-v7.3'');'];
    
    % Execute the save command
    eval(save_cmd);
    
    fprintf('\nConverted: %s to %s\n', noisy_file, output_file);
end

fprintf('\nAll conversions complete!\n');
