% merge_timit_neurograms_test_with_noise.m
%
% This script merges neurograms with WHAM noise from the test set
% Handles different SNR conditions separately

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
input_dir = fullfile(base_dir, 'SELECT_Neurograms_WithNoise', 'TEST');

% Find all neurogram files
files = dir(fullfile(input_dir, '**', '*neurogram_with_noise*.mat'));
fprintf('Found %d neurogram files\n', length(files));

% Group files by SNR condition
filesBySNR = struct();

for i = 1:length(files)
    filename = files(i).name;
    
    % Determine SNR condition from filename
    if contains(filename, 'snr')
        % Extract SNR value from filename
        if contains(filename, 'snr-5')
            snr_condition = 'snr_neg5';
        elseif contains(filename, 'snr0')
            snr_condition = 'snr_0';
        elseif contains(filename, 'snr5')
            snr_condition = 'snr_5';
        elseif contains(filename, 'snr10')
            snr_condition = 'snr_10';
        elseif contains(filename, 'snr15')
            snr_condition = 'snr_15';
        elseif contains(filename, 'random')
            snr_condition = 'random';
        else
            % Check for band SNR
            if contains(filename, 'snr-5_0')
                snr_condition = 'band_neg5_0';
            elseif contains(filename, 'snr0_5')
                snr_condition = 'band_0_5';
            elseif contains(filename, 'snr5_10')
                snr_condition = 'band_5_10';
            elseif contains(filename, 'snr10_15')
                snr_condition = 'band_10_15';
            else
                % Default to the exact SNR from the file
                data = load(fullfile(files(i).folder, files(i).name));
                snr_value = round(data.target_snr_db);
                snr_condition = sprintf('snr_%d', snr_value);
            end
        end
    else
        % Default for files without specific SNR in name
        snr_condition = 'default';
    end
    
    % Add file to appropriate group
    if ~isfield(filesBySNR, snr_condition)
        filesBySNR.(snr_condition) = {};
    end
    filesBySNR.(snr_condition){end+1} = files(i);
end

% Process each SNR condition
snr_conditions = fieldnames(filesBySNR);
fprintf('Found %d different SNR conditions: %s\n', length(snr_conditions), strjoin(snr_conditions, ', '));

for c = 1:length(snr_conditions)
    snr_condition = snr_conditions{c};
    current_files = filesBySNR.(snr_condition);
    
    fprintf('Processing %d files for condition: %s\n', length(current_files), snr_condition);
    
    % Use cell arrays to store neurograms with different dimensions
    num_files = length(current_files);
    all_neurograms = cell(num_files, 1);
    all_labels = cell(num_files, 1);
    all_sentence_ids = cell(num_files, 1);
    all_snrs = zeros(num_files, 1);
    
    % Process each file in this condition
    for i = 1:num_files
        if mod(i, 1000) == 0
            fprintf('  Processing file %d of %d\n', i, num_files);
        end
        
        file = current_files{i};
        neurogram_file = fullfile(file.folder, file.name);
        data = load(neurogram_file);
        
        % Extract neurogram (use noisy version)
        neurogram = data.r_mean_downsampled;
        
        % Store neurogram in cell array to handle different dimensions
        all_neurograms{i} = neurogram;
        
        % Extract speaker/sentence information from path
        path_parts = strsplit(file.folder, filesep);
        speaker_id = path_parts{end};
        
        % Extract sentence ID from filename
        [~, filename, ~] = fileparts(file.name);
        sentence_parts = strsplit(filename, '_');
        sentence_id = sentence_parts{1};
        
        % Store metadata
        all_sentence_ids{i} = [speaker_id '_' sentence_id];
        all_labels{i} = 'normal'; % All test data is normal
        all_snrs(i) = data.target_snr_db;
    end
    
    % Also save the center frequencies for reference if available
    if isfield(data, 'center_frequencies')
        center_frequencies = data.center_frequencies;
    else
        center_frequencies = []; % Empty if not available
    end
    
    % Save merged data for this condition
    output_file = fullfile(base_dir, sprintf('TIMIT_neurogram_test_with_noise_%s.mat', snr_condition));
    fprintf('Saving merged data to %s\n', output_file);
    save(output_file, 'all_neurograms', 'all_labels', 'all_sentence_ids', 'all_snrs', 'center_frequencies', '-v7.3');
end

fprintf('Done!\n');
