% generate_neurograms_with_wham_noise.m
%
% This script generates neurograms using the zilany2014 model for TIMIT speech signals
% mixed with WHAM! noise.
%
% Designed for cluster execution with job arrays using SLURM
% Usage: matlab -nodisplay -r "generate_neurograms_with_wham_noise(TASK_ID, NUM_TASKS); exit"
%
% Where TASK_ID is the current job ID (1-based) and NUM_TASKS is the total number of jobs

function generate_neurograms_with_wham_noise(task_id, num_tasks, test_snr_setting)
% generate_neurograms_with_wham_noise - Generate neurograms with WHAM noise
%
% Inputs:
%   task_id - Current task ID (1-based)
%   num_tasks - Total number of tasks
%   test_snr_setting - Optional parameter:
%                      - Empty: Use the test_snr_mode setting in the script
%                      - 'random': Random SNR for testing
%                      - 'fixed:X': Fixed SNR of X dB (e.g., 'fixed:5')
%                      - 'band:X-Y': Random SNR in band [X,Y] (e.g., 'band:0-5')

    % Check if arguments were provided
    if nargin < 2
        if isempty(getenv('SLURM_ARRAY_TASK_ID')) || isempty(getenv('SLURM_ARRAY_TASK_COUNT'))
            error('Please provide task_id and num_tasks arguments or run as a SLURM job array');
        else
            % Get task ID and number of tasks from SLURM environment variables
            task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
            num_tasks = str2double(getenv('SLURM_ARRAY_TASK_COUNT'));
        end
    end
    
    % SNR parameters
    train_snr_min = -5;  % Minimum SNR for training in dB
    train_snr_max = 15;  % Maximum SNR for training in dB

    % Test SNR modes:
    % - 'random': Random SNR within range (similar to training)
    % - 'fixed': Fixed SNR values
    % - 'bands': Random SNR within smaller bands
    test_snr_mode = 'fixed';  % Choose test SNR mode

    % SNR settings for each test mode
    test_random_snr_min = -5;  % For 'random' mode
    test_random_snr_max = 15;  % For 'random' mode

    % For 'fixed' mode, specify the exact SNR values to test
    test_fixed_snr_values = [-5, 0, 5, 10, 15];  % For 'fixed' mode

    % For 'bands' mode, specify the SNR bands to test
    test_snr_bands = {[-5, 0], [0, 5], [5, 10], [10, 15]};  % For 'bands' mode
    
    % Parse test SNR setting if provided
    custom_test_snr = false;
    if nargin >= 3 && ~isempty(test_snr_setting)
        custom_test_snr = true;
        
        if strcmpi(test_snr_setting, 'random')
            test_snr_mode = 'random';
        elseif strncmpi(test_snr_setting, 'fixed:', 6)
            test_snr_mode = 'fixed';
            test_fixed_snr_values = str2double(test_snr_setting(7:end));
        elseif strncmpi(test_snr_setting, 'band:', 5)
            test_snr_mode = 'bands';
            band_range = test_snr_setting(6:end);
            band_parts = strsplit(band_range, '-');
            if length(band_parts) == 2
                test_snr_bands = {[str2double(band_parts{1}), str2double(band_parts{2})]};
            end
        end
    end
    
    % Add the path to the AMT toolbox
    addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
    
    % Initialize the AMT
    amt_start();
    
    % Configure paths
    home_dir = '/pasteur/appa/homes/mcampi';
    base_dir = fullfile(home_dir, 'ASR_ANSD/Neurogram_Sim');
    
    % Define scratch directory for outputs
    scratch_dir = '/pasteur/helix/scratch/mcampi/neurograms_wham';
    
    % Create scratch directory if it doesn't exist
    if ~exist(scratch_dir, 'dir')
        mkdir(scratch_dir);
    end
    
    % Define base directories
    train_input_dir = fullfile(base_dir, 'SELECT/TRAIN');
    test_input_dir = fullfile(base_dir, 'SELECT/TEST');
    
    % Use scratch space for outputs
    train_output_dir = fullfile(scratch_dir, 'TRAIN');
    test_output_dir = fullfile(scratch_dir, 'TEST');
    
    % Define WHAM! noise directory and metadata
    wham_base_dir = '/pasteur/helix/scratch/mcampi/wham_noise';
    wham_train_dir = fullfile(wham_base_dir, 'tr');
    wham_test_dir = fullfile(wham_base_dir, 'tt');
    wham_train_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tr.csv');
    wham_test_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tt.csv');
    
    % Create log directory
    log_dir = fullfile(base_dir, 'logs', 'wham_noise_generation');
    if ~exist(log_dir, 'dir')
        mkdir(log_dir);
    end
    
    % Create log file name with SNR info if applicable
    if custom_test_snr
        log_file = fullfile(log_dir, sprintf('task_%d_of_%d_%s.log', ...
            task_id, num_tasks, strrep(test_snr_setting, ':', '_')));
    else
        log_file = fullfile(log_dir, sprintf('task_%d_of_%d.log', task_id, num_tasks));
    end
    diary(log_file);
    
    % Print job info
    fprintf('Starting neurogram generation with WHAM! noise (Task %d of %d)\n', task_id, num_tasks);
    fprintf('Started at: %s\n', datestr(now));
    fprintf('Using scratch directory for outputs: %s\n', scratch_dir);
    
    % Load WHAM! metadata
    try
        train_noise_meta = readtable(wham_train_meta_file);
        test_noise_meta = readtable(wham_test_meta_file);
        fprintf('WHAM! noise samples: Training: %d, Testing: %d\n', ...
            height(train_noise_meta), height(test_noise_meta));
    catch err
        fprintf('Error loading WHAM! metadata: %s\n', err.message);
        diary off;
        return;
    end
    
    % Model parameters
    center_frequencies = logspace(log10(125), log10(10000), 150);  % 150 CFs logarithmically spaced from 125 Hz to 10,000 Hz
    fsmod = 100e3;  % Model sampling rate
    fs_neurogram = 500; % Neurogram target sampling rate (500 Hz, equivalent to 2 ms bins)
    
    % Get all files to process
    train_files = get_all_wav_files(train_input_dir);
    test_files = get_all_wav_files(test_input_dir);
    all_files = [train_files; test_files];
    
    fprintf('Found %d total files to process\n', length(all_files));
    
    % Determine which files this task should process
    files_per_task = ceil(length(all_files) / num_tasks);
    start_idx = (task_id - 1) * files_per_task + 1;
    end_idx = min(task_id * files_per_task, length(all_files));
    
    task_files = all_files(start_idx:end_idx);
    fprintf('This task will process %d files (from %d to %d)\n', ...
        length(task_files), start_idx, end_idx);
    
    % Initialize random number generator with task-specific seed for reproducibility
    rng(42 + task_id);
    
    % Process each file
    for i = 1:length(task_files)
        file_info = task_files(i);
        
        % Determine if this is train or test data
        is_train = contains(file_info.filepath, 'TRAIN');
        
        % Set appropriate output directory and noise metadata
        if is_train
            output_dir = train_output_dir;
            noise_dir = wham_train_dir;
            noise_meta = train_noise_meta;
        else
            output_dir = test_output_dir;
            noise_dir = wham_test_dir;
            noise_meta = test_noise_meta;
        end
        
        % Create output subdirectories if needed
        if is_train
            path_to_replace = train_input_dir;
        else
            path_to_replace = test_input_dir;
        end
        rel_path = strrep(file_info.filepath, path_to_replace, '');
        [~, rel_path] = fileparts(fileparts(rel_path));
        output_subdir = fullfile(output_dir, rel_path);
        if ~exist(output_subdir, 'dir')
            mkdir(output_subdir);
        end
        
        % Create output filename
        [~, name, ~] = fileparts(file_info.name);
        
        % Create appropriate output filename based on test SNR mode
        if is_train || ~custom_test_snr
            output_file = fullfile(output_subdir, [name '_neurogram_with_noise.mat']);
        else
            % For test data with custom SNR, include SNR info in filename
            if strcmpi(test_snr_mode, 'random')
                output_file = fullfile(output_subdir, [name '_neurogram_with_noise_random.mat']);
            elseif strcmpi(test_snr_mode, 'fixed')
                output_file = fullfile(output_subdir, sprintf('%s_neurogram_with_noise_snr%.1f.mat', ...
                    name, test_fixed_snr_values(1)));
            elseif strcmpi(test_snr_mode, 'bands')
                band_start = test_snr_bands{1}(1);
                band_end = test_snr_bands{1}(2);
                output_file = fullfile(output_subdir, sprintf('%s_neurogram_with_noise_snr%.1f_%.1f.mat', ...
                    name, band_start, band_end));
            end
        end
        
        % Skip if file already exists (to support resuming interrupted jobs)
        if exist(output_file, 'file')
            fprintf('[%d/%d] Skipping existing file: %s\n', i, length(task_files), file_info.name);
            continue;
        end
        
        % Process the file
        try
            fprintf('[%d/%d] Processing: %s\n', i, length(task_files), file_info.name);
            
            % Load speech file
            [speech, fs] = audioread(file_info.filepath);
            
            % Resample speech if needed
            if fs ~= fsmod
                speech = resample(speech, fsmod, fs);
            end
            
            % Select a random noise from WHAM dataset
            noise_idx = randi(height(noise_meta));
            
            % Display column names for debugging
            fprintf('Available column names: %s\n', strjoin(noise_meta.Properties.VariableNames, ', '));
            % Get the utterance_id (first column) which contains the actual filename
            if ismember('utterance_id', noise_meta.Properties.VariableNames)
                noise_filename = noise_meta.utterance_id{noise_idx};
                fprintf('Using utterance_id for noise file: %s\n', noise_filename);
            else
                % If the column has been renamed by MATLAB, just use the first column directly
                first_col_name = noise_meta.Properties.VariableNames{1};
                noise_filename = noise_meta.(first_col_name){noise_idx};
                fprintf('Using first column (%s) for noise file: %s\n', first_col_name, noise_filename);
            end
            
            % Full path to noise file
            noise_file = fullfile(noise_dir, noise_filename);
            
            % Determine SNR based on mode and whether this is train or test data
            if is_train
                % For training data, always use random SNR within training range
                target_snr_db = train_snr_min + (train_snr_max - train_snr_min) * rand();
            else
                % For test data, use the appropriate SNR based on the mode
                if strcmpi(test_snr_mode, 'random')
                    target_snr_db = test_random_snr_min + (test_random_snr_max - test_random_snr_min) * rand();
                elseif strcmpi(test_snr_mode, 'fixed')
                    % If multiple fixed values are specified, cycle through them based on file index
                    if length(test_fixed_snr_values) > 1 && ~custom_test_snr
                        snr_idx = mod(i-1, length(test_fixed_snr_values)) + 1;
                        target_snr_db = test_fixed_snr_values(snr_idx);
                    else
                        target_snr_db = test_fixed_snr_values(1);
                    end
                elseif strcmpi(test_snr_mode, 'bands')
                    % If multiple bands are specified, cycle through them based on file index
                    if length(test_snr_bands) > 1 && ~custom_test_snr
                        band_idx = mod(i-1, length(test_snr_bands)) + 1;
                        current_band = test_snr_bands{band_idx};
                    else
                        current_band = test_snr_bands{1};
                    end
                    band_min = current_band(1);
                    band_max = current_band(2);
                    target_snr_db = band_min + (band_max - band_min) * rand();
                end
            end
            
            % Load noise file
            try
                [noise, fs_noise] = audioread(noise_file);
            catch err1
                % If file not found with extension, try adding .wav
                if ~endsWith(noise_file, '.wav')
                    try
                        [noise, fs_noise] = audioread([noise_file '.wav']);
                    catch err2
                        fprintf('Error loading noise file %s: %s\n', noise_file, err1.message);
                        continue; % Skip this file and move to next
                    end
                else
                    fprintf('Error loading noise file %s: %s\n', noise_file, err1.message);
                    continue; % Skip this file and move to next
                end
            end
            
            % If noise is stereo, take just one channel
            if size(noise, 2) > 1
                noise = noise(:, 1);
            end
            
            % If noise is shorter than speech, repeat it
            while length(noise) < length(speech)
                noise = [noise; noise];
            end
            
            % Trim noise to match speech length
            noise = noise(1:length(speech));
            
            % Scale noise to achieve target SNR
            speech_power = sum(speech.^2) / length(speech);
            noise_power = sum(noise.^2) / length(noise);
            scaling_factor = sqrt(speech_power / (noise_power * 10^(target_snr_db/10)));
            scaled_noise = noise * scaling_factor;
            
            % Mix speech and noise
            mixed_signal = speech + scaled_noise;
            
            % Normalize to prevent clipping
            mixed_signal = mixed_signal / max(abs(mixed_signal));
            
            % Generate auditory nerve response for mixed signal
            [r_mean, ~, ~, ~, ~, ~, ~] = zilany2014(mixed_signal, fsmod, center_frequencies, ...
                'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
            
            % Generate neurogram for clean speech (optional - comment out if not needed)
            [r_mean_clean, ~, ~, ~, ~, ~, ~] = zilany2014(speech, fsmod, center_frequencies, ...
                'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
            
            % Downsample to target rate
            downsampling_factor = fsmod / fs_neurogram;
            r_mean_downsampled = downsample(r_mean, downsampling_factor);
            r_mean_clean_downsampled = downsample(r_mean_clean, downsampling_factor);
            
            % Extract noise metadata
            noise_info = noise_meta(noise_idx, :);
            
            % Save neurogram
            save(output_file, 'r_mean_downsampled', 'r_mean_clean_downsampled', 'center_frequencies', ...
                'noise_info', 'target_snr_db', 'noise_filename');
            
            fprintf('   Processed with noise: %s (SNR: %.2f dB)\n', file_info.name, target_snr_db);
        catch err
            fprintf('Error processing %s: %s\n', file_info.name, err.message);
        end
    end
    
    fprintf('Task %d of %d completed at: %s\n', task_id, num_tasks, datestr(now));
    diary off;
end

% Function to get all WAV files recursively
function files = get_all_wav_files(directory)
    files = dir(fullfile(directory, '**', '*.wav'));
    
    % Add full filepath
    for i = 1:length(files)
        files(i).filepath = fullfile(files(i).folder, files(i).name);
    end
end
