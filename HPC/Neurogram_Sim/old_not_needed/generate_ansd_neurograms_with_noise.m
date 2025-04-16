% generate_ansd_neurograms_with_noise.m
%
% This script generates noisy neurograms by adding WHAM! noise to existing ANSD neurograms
%
% Designed for cluster execution with job arrays using SLURM
% Usage: matlab -nodisplay -r "generate_ansd_neurograms_with_noise(TASK_ID, NUM_TASKS); exit"
%
% Where TASK_ID is the current job ID (1-based) and NUM_TASKS is the total number of jobs

function generate_ansd_neurograms_with_noise(task_id, num_tasks, test_snr_setting)
% generate_ansd_neurograms_with_noise - Generate noisy ANSD neurograms
%
% Inputs:
%   task_id - Current task ID (1-based)
%   num_tasks - Total number of tasks
%   test_snr_setting - Optional parameter:
%                      - Empty: Use the test_snr_mode setting in the script
%                      - 'fixed:X': Fixed SNR of X dB (e.g., 'fixed:5')

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
    
    % Test SNR settings - use the same as the healthy ones for consistency
    test_snr_mode = 'fixed';  % Use fixed SNR values
    test_fixed_snr_values = [-5, 0, 5, 10, 15];  % Same fixed SNR values as healthy
    
    % Parse test SNR setting if provided
    custom_test_snr = false;
    if nargin >= 3 && ~isempty(test_snr_setting)
        custom_test_snr = true;
        
        if strncmpi(test_snr_setting, 'fixed:', 6)
            test_snr_mode = 'fixed';
            test_fixed_snr_values = str2double(test_snr_setting(7:end));
        end
    end
    
    % Add the path to the AMT toolbox
    addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
    
    % Initialize the AMT
    amt_start();
    
    % Configure paths
    home_dir = '/pasteur/appa/homes/mcampi';
    base_dir = fullfile(home_dir, 'ASR_ANSD/Neurogram_Sim');
    
    % Define source and destination directories
    ansd_source_dir = '/pasteur/helix/scratch/mcampi/SELECT_Neurograms_ANSD';
    output_dir = fullfile(base_dir, 'SELECT_Neurograms_ANSD_WithNoise');
    
    % Create output directory if it doesn't exist
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Define subdirectories for test and train
    ansd_test_dir = fullfile(ansd_source_dir, 'TEST');
    ansd_train_dir = fullfile(ansd_source_dir, 'TRAIN');
    
    output_test_dir = fullfile(output_dir, 'TEST');
    output_train_dir = fullfile(output_dir, 'TRAIN');
    
    % Create output subdirectories
    if ~exist(output_test_dir, 'dir')
        mkdir(output_test_dir);
    end
    if ~exist(output_train_dir, 'dir')
        mkdir(output_train_dir);
    end
    
    % Define WHAM! noise directory and metadata
    wham_base_dir = '/pasteur/helix/scratch/mcampi/wham_noise';
    wham_train_dir = fullfile(wham_base_dir, 'tr');
    wham_test_dir = fullfile(wham_base_dir, 'tt');
    wham_train_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tr.csv');
    wham_test_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tt.csv');
    
    % Create log directory
    log_dir = fullfile(base_dir, 'logs', 'ansd_wham_noise_generation');
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
    fprintf('Starting noisy ANSD neurogram generation (Task %d of %d)\n', task_id, num_tasks);
    fprintf('Started at: %s\n', datestr(now));
    fprintf('Using output directory: %s\n', output_dir);
    
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
    fsmod = 100e3;  % Model sampling rate
    fs_neurogram = 500; % Neurogram target sampling rate (500 Hz, equivalent to 2 ms bins)
    
    % Get all ANSD neurogram files to process
    train_files = get_all_mat_files(ansd_train_dir);
    test_files = get_all_mat_files(ansd_test_dir);
    all_files = [train_files; test_files];
    
    fprintf('Found %d total ANSD neurogram files to process\n', length(all_files));
    
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
            output_subdir = output_train_dir;
            noise_dir = wham_train_dir;
            noise_meta = train_noise_meta;
        else
            output_subdir = output_test_dir;
            noise_dir = wham_test_dir;
            noise_meta = test_noise_meta;
        end
        
        % Get file structure for output path
        if is_train
            path_to_replace = ansd_train_dir;
        else
            path_to_replace = ansd_test_dir;
        end
        
        % Extract relative path
        rel_path = strrep(fileparts(file_info.filepath), path_to_replace, '');
        if startsWith(rel_path, '/')
            rel_path = rel_path(2:end); % Remove leading slash if present
        end
        
        % Create output subdirectory if needed
        dest_dir = fullfile(output_subdir, rel_path);
        if ~exist(dest_dir, 'dir')
            mkdir(dest_dir);
        end
        
        % Process ANSD neurogram file
        try
            % Extract base name without extension
            [~, name, ~] = fileparts(file_info.name);
            
            % Process with different SNR levels for test data
            if ~is_train
                % Process each SNR level for test files
                for snr_idx = 1:length(test_fixed_snr_values)
                    target_snr_db = test_fixed_snr_values(snr_idx);
                    
                    % Create output filename with SNR info
                    if target_snr_db == 0
                        snr_str = 'snr_0';
                    elseif target_snr_db < 0
                        snr_str = sprintf('snr_neg%d', abs(target_snr_db));
                    else
                        snr_str = sprintf('snr_%d', target_snr_db);
                    end
                    
                    output_file = fullfile(dest_dir, sprintf('%s_with_noise_%s.mat', name, snr_str));
                    
                    % Skip if file already exists
                    if exist(output_file, 'file')
                        fprintf('[%d/%d] Skipping existing file: %s (SNR: %d dB)\n', ...
                            i, length(task_files), file_info.name, target_snr_db);
                        continue;
                    end
                    
                    % Process this SNR level
                    fprintf('[%d/%d] Processing: %s (SNR: %d dB)\n', ...
                        i, length(task_files), file_info.name, target_snr_db);
                    
                    % Add noise to the ANSD neurogram
                    add_noise_to_neurogram(file_info.filepath, output_file, noise_dir, noise_meta, target_snr_db);
                end
                
                % Also create a default noise version if not using custom SNR
                if ~custom_test_snr
                    output_file = fullfile(dest_dir, sprintf('%s_with_noise_default.mat', name));
                    
                    % Skip if file already exists
                    if exist(output_file, 'file')
                        fprintf('[%d/%d] Skipping existing default file: %s\n', i, length(task_files), file_info.name);
                        continue;
                    end
                    
                    fprintf('[%d/%d] Processing default noise: %s\n', i, length(task_files), file_info.name);
                    
                    % Use a random SNR from mid-range for default
                    default_snr = 5 + 5 * rand(); % Random SNR between 5 and 10 dB
                    add_noise_to_neurogram(file_info.filepath, output_file, noise_dir, noise_meta, default_snr);
                end
            else
                % For training data, just create a single noisy version with random SNR
                output_file = fullfile(dest_dir, sprintf('%s_with_noise.mat', name));
                
                % Skip if file already exists
                if exist(output_file, 'file')
                    fprintf('[%d/%d] Skipping existing file: %s\n', i, length(task_files), file_info.name);
                    continue;
                end
                
                fprintf('[%d/%d] Processing: %s (training)\n', i, length(task_files), file_info.name);
                
                % Use a random SNR from a wider range for training
                train_snr = -5 + 20 * rand(); % Random SNR between -5 and 15 dB
                add_noise_to_neurogram(file_info.filepath, output_file, noise_dir, noise_meta, train_snr);
            end
            
        catch err
            fprintf('Error processing %s: %s\n', file_info.name, err.message);
            fprintf('Error details: %s\n', getReport(err, 'extended'));
        end
    end
    
    fprintf('Task %d of %d completed at: %s\n', task_id, num_tasks, datestr(now));
    diary off;
end

% Function to add noise to an ANSD neurogram
function add_noise_to_neurogram(input_file, output_file, noise_dir, noise_meta, target_snr_db)
    % Load the ANSD neurogram
    try
        ansd_data = load(input_file);
    catch err
        error('Failed to load ANSD neurogram: %s', err.message);
    end
    
    % Make sure neurogram exists
    if ~isfield(ansd_data, 'r_mean_downsampled')
        error('Input file does not contain r_mean_downsampled');
    end
    
    neurogram = ansd_data.r_mean_downsampled;
    
    % Select a random noise from WHAM dataset
    noise_idx = randi(height(noise_meta));
    
    % Get the filename (first column)
    if ismember('utterance_id', noise_meta.Properties.VariableNames)
        noise_filename = noise_meta.utterance_id{noise_idx};
    else
        % If the column has been renamed by MATLAB, just use the first column directly
        first_col_name = noise_meta.Properties.VariableNames{1};
        noise_filename = noise_meta.(first_col_name){noise_idx};
    end
    
    % Full path to noise file
    noise_file = fullfile(noise_dir, noise_filename);
    if ~endsWith(noise_file, '.wav')
        noise_file = [noise_file '.wav'];
    end
    
    % Load noise file
    try
        [noise, fs_noise] = audioread(noise_file);
    catch err
        error('Failed to load noise file %s: %s', noise_file, err.message);
    end
    
    % If noise is stereo, take just one channel
    if size(noise, 2) > 1
        noise = noise(:, 1);
    end
    
    % Resample noise to match neurogram time resolution (typically 500 Hz)
    fs_neurogram = 500; % Neurogram is typically at 500 Hz (2ms time bins)
    if fs_noise ~= fs_neurogram
        noise = resample(noise, fs_neurogram, fs_noise);
    end
    
    % If noise is shorter than neurogram, repeat it
    while length(noise) < size(neurogram, 1)
        noise = [noise; noise];
    end
    
    % Trim noise to match neurogram length
    noise = noise(1:size(neurogram, 1));
    
    % Prepare noise to match neurogram dimensions
    % Repeat noise across frequency channels
    noise_matrix = repmat(noise, 1, size(neurogram, 2));
    
    % Scale noise to achieve target SNR
    neurogram_power = sum(sum(neurogram.^2)) / numel(neurogram);
    noise_power = sum(sum(noise_matrix.^2)) / numel(noise_matrix);
    scaling_factor = sqrt(neurogram_power / (noise_power * 10^(target_snr_db/10)));
    scaled_noise = noise_matrix * scaling_factor;
    
    % Mix neurogram and noise
    noisy_neurogram = neurogram + scaled_noise;
    
    % Ensure non-negative values (neurogram represents firing rates)
    noisy_neurogram = max(noisy_neurogram, 0);
    
    % Save the noisy neurogram with metadata
    % Copy fields from original neurogram
    output_data = ansd_data;
    
    % Replace the neurogram with noisy version
    output_data.r_mean_downsampled = noisy_neurogram;
    
    % Add noise metadata
    output_data.noise_info = noise_meta(noise_idx, :);
    output_data.target_snr_db = target_snr_db;
    output_data.noise_filename = noise_filename;
    output_data.original_ansd_file = input_file;
    
    % Save the file
    save(output_file, '-struct', 'output_data');
    
    fprintf('   Created noisy neurogram with SNR: %.2f dB\n', target_snr_db);
end

% Function to get all MAT files recursively
function files = get_all_mat_files(directory)
    files = dir(fullfile(directory, '**', '*.mat'));
    
    % Add full filepath
    for i = 1:length(files)
        files(i).filepath = fullfile(files(i).folder, files(i).name);
    end
end
