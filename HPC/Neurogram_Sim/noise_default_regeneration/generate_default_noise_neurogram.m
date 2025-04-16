% generate_default_noise_neurogram_parallel.m (CORRECTED)
%
% This script generates default noise neurograms for TEST files in parallel
% Designed for execution as a SLURM job array
% PRESERVES PROPER DR1-DR7 DIRECTORY STRUCTURE

function generate_default_noise_neurogram_parallel(task_id, num_tasks)
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
    
    % Add the path to the AMT toolbox
    addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
    
    % Initialize the AMT
    amt_start();
    
    % Configure paths
    home_dir = '/pasteur/appa/homes/mcampi';
    base_dir = fullfile(home_dir, 'ASR_ANSD/Neurogram_Sim');
    
    % Test input directory
    test_input_dir = fullfile(base_dir, 'SELECT/TEST');
    
    % Create an isolated output directory
    output_dir = '/pasteur/helix/scratch/mcampi/neurograms_wham/healthy/TEST_default';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Define WHAM! noise directory and metadata
    wham_base_dir = '/pasteur/helix/scratch/mcampi/wham_noise';
    wham_test_dir = fullfile(wham_base_dir, 'tt');
    wham_test_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tt.csv');
    
    % Log directory and file
    log_dir = fullfile(base_dir, 'logs', 'default_noise_parallel');
    if ~exist(log_dir, 'dir')
        mkdir(log_dir);
    end
    log_file = fullfile(log_dir, sprintf('task_%d_of_%d.log', task_id, num_tasks));
    diary(log_file);
    
    fprintf('Starting parallel default noise generation (Task %d of %d)\n', task_id, num_tasks);
    fprintf('Started at: %s\n', datestr(now));
    
    % Load WHAM! metadata
    try
        test_noise_meta = readtable(wham_test_meta_file);
        fprintf('WHAM! noise test samples: %d\n', height(test_noise_meta));
    catch err
        fprintf('Error loading WHAM! metadata: %s\n', err.message);
        diary off;
        return;
    end
    
    % Model parameters
    center_frequencies = logspace(log10(125), log10(10000), 150);
    fsmod = 100e3;  % Model sampling rate
    fs_neurogram = 500; % Neurogram sampling rate
    
    % Get all test files
    test_files = get_all_wav_files(test_input_dir);
    fprintf('Found %d test files to process\n', length(test_files));
    
    % Determine which files this task should process
    files_per_task = ceil(length(test_files) / num_tasks);
    start_idx = (task_id - 1) * files_per_task + 1;
    end_idx = min(task_id * files_per_task, length(test_files));
    
    task_files = test_files(start_idx:end_idx);
    fprintf('This task will process %d files (from %d to %d)\n', ...
        length(task_files), start_idx, end_idx);
    
    % Initialize random number generator with task-specific seed for reproducibility
    rng(42 + task_id);
    
    % Process each file
    for i = 1:length(task_files)
        file_info = task_files(i);
        
        % Extract the full relative path to preserve dialect regions (DR1-DR7)
        rel_path = strrep(file_info.folder, test_input_dir, '');
        if startsWith(rel_path, filesep)
            rel_path = rel_path(2:end);  % Remove leading slash
        end
        
        % Create output subdirectory with full dialect region structure
        output_subdir = fullfile(output_dir, rel_path);
        if ~exist(output_subdir, 'dir')
            mkdir(output_subdir);
        end
        
        % Create output filename with consistent naming
        [~, name, ~] = fileparts(file_info.name);
        output_file = fullfile(output_subdir, [name '_neurogram_with_noise_default.mat']);
        
        % Skip if file already exists
        if exist(output_file, 'file')
            fprintf('[%d/%d] Skipping existing file: %s\n', i, length(task_files), file_info.name);
            continue;
        end
        
        % Process the file
        try
            fprintf('[%d/%d] Processing: %s (in %s)\n', i, length(task_files), file_info.name, rel_path);
            
            % Load speech file
            [speech, fs] = audioread(file_info.filepath);
            
            % Resample speech if needed
            if fs ~= fsmod
                speech = resample(speech, fsmod, fs);
            end
            
            % Select a random noise from WHAM dataset
            noise_idx = randi(height(test_noise_meta));
            
            % Get the noise filename
            if ismember('utterance_id', test_noise_meta.Properties.VariableNames)
                noise_filename = test_noise_meta.utterance_id{noise_idx};
            else
                first_col_name = test_noise_meta.Properties.VariableNames{1};
                noise_filename = test_noise_meta.(first_col_name){noise_idx};
            end
            
            % Full path to noise file
            noise_file = fullfile(wham_test_dir, noise_filename);
            if ~endsWith(noise_file, '.wav')
                noise_file = [noise_file '.wav'];
            end
            
            % Load noise file
            try
                [noise, fs_noise] = audioread(noise_file);
            catch err1
                % Try again with different noise file if failed
                fprintf('Error loading noise file %s: %s\n', noise_file, err1.message);
                continue;
            end
            
            % If noise is stereo, take one channel
            if size(noise, 2) > 1
                noise = noise(:, 1);
            end
            
            % Ensure noise is long enough
            while length(noise) < length(speech)
                noise = [noise; noise];
            end
            noise = noise(1:length(speech));
            
            % Use random SNR between 5-10 dB to match the ANSD approach
            target_snr_db = 5.0 + 5.0 * rand(); % Random SNR between 5-10 dB
            
            % Scale noise to target SNR
            speech_power = sum(speech.^2) / length(speech);
            noise_power = sum(noise.^2) / length(noise);
            scaling_factor = sqrt(speech_power / (noise_power * 10^(target_snr_db/10)));
            scaled_noise = noise * scaling_factor;
            
            % Mix speech and noise
            mixed_signal = speech + scaled_noise;
            mixed_signal = mixed_signal / max(abs(mixed_signal));
            
            % Generate auditory nerve response for mixed signal
            [r_mean, ~, ~, ~, ~, ~, ~] = zilany2014(mixed_signal, fsmod, center_frequencies, ...
                'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
            
            % Generate neurogram for clean speech
            [r_mean_clean, ~, ~, ~, ~, ~, ~] = zilany2014(speech, fsmod, center_frequencies, ...
                'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
            
            % Downsample to target rate
            downsampling_factor = fsmod / fs_neurogram;
            r_mean_downsampled = downsample(r_mean, downsampling_factor);
            r_mean_clean_downsampled = downsample(r_mean_clean, downsampling_factor);
            
            % Extract noise metadata
            noise_info = test_noise_meta(noise_idx, :);
            
            % Save neurogram
            save(output_file, 'r_mean_downsampled', 'r_mean_clean_downsampled', 'center_frequencies', ...
                'noise_info', 'target_snr_db', 'noise_filename');
            
            fprintf('   Processed with default noise (SNR: %.2f dB)\n', target_snr_db);
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
