% generate_neurograms.m
%
% Generates neurograms using the Zilany et al. (2014) auditory nerve model
% for TIMIT speech signals, optionally mixed with WHAM! noise.
%
% Paper: "Mechanism-Specific Speech Encoding Failures in Auditory Neuropathy"
% Section 2.1 — Auditory nerve model
%
% Parameters (from paper):
%   - 150 log-spaced CFs: 125 Hz – 10 kHz
%   - High-SR fibers (fiberType=3, ~100 sp/s)
%   - Model sampling rate: 100 kHz
%   - Downsampled to 500 Hz (2 ms bins)
%   - OHC/IHC function: normal (cohc=1.0, cihc=1.0)
%   - Environmental noise: WHAM! dataset, SNR ~ U(0, 20) dB
%
% Usage (SLURM):
%   matlab -nodisplay -r "generate_neurograms(TASK_ID, NUM_TASKS, true); exit"
%   matlab -nodisplay -r "generate_neurograms(TASK_ID, NUM_TASKS, false); exit"
%
% Inputs:
%   task_id          - Current task ID (1-based), or read from SLURM env
%   num_tasks        - Total number of tasks, or read from SLURM env
%   add_noise        - logical: true = mix with WHAM! noise, false = clean
%   test_snr_setting - (optional, noise only) Override test SNR mode:
%                      'random', 'fixed:X', 'band:X-Y'

function generate_neurograms(task_id, num_tasks, add_noise, test_snr_setting)

    %% ---- Parse arguments ------------------------------------------------
    if nargin < 2
        if isempty(getenv('SLURM_ARRAY_TASK_ID')) || isempty(getenv('SLURM_ARRAY_TASK_COUNT'))
            error('Provide task_id and num_tasks, or run as a SLURM job array');
        end
        task_id   = str2double(getenv('SLURM_ARRAY_TASK_ID'));
        num_tasks = str2double(getenv('SLURM_ARRAY_TASK_COUNT'));
    end

    if nargin < 3
        add_noise = true;  % default: generate noisy neurograms
    end

    if nargin < 4
        test_snr_setting = '';
    end

    %% ---- SNR configuration (only used when add_noise = true) ------------
    train_snr_min = 0;    % dB  (Paper: "0–20 dB SNR")
    train_snr_max = 20;   % dB

    test_snr_mode = 'fixed';
    test_random_snr_min = 0;
    test_random_snr_max = 20;
    test_fixed_snr_values = [0, 5, 10, 15, 20];
    test_snr_bands = {[0, 5], [5, 10], [10, 15], [15, 20]};

    custom_test_snr = false;
    if add_noise && ~isempty(test_snr_setting)
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

    %% ---- Paths ----------------------------------------------------------
    addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
    amt_start();

    home_dir = '/pasteur/appa/homes/mcampi';
    base_dir = fullfile(home_dir, 'ASR_ANSD/Neurogram_Sim');

    if add_noise
        scratch_dir = '/pasteur/helix/scratch/mcampi/neurograms_wham';
        condition_label = 'noise';
    else
        scratch_dir = '/pasteur/helix/scratch/mcampi/neurograms_clean';
        condition_label = 'silence';
    end

    if ~exist(scratch_dir, 'dir')
        mkdir(scratch_dir);
    end

    train_input_dir = fullfile(base_dir, 'SELECT/TRAIN');
    test_input_dir  = fullfile(base_dir, 'SELECT/TEST');
    train_output_dir = fullfile(scratch_dir, 'TRAIN');
    test_output_dir  = fullfile(scratch_dir, 'TEST');

    % WHAM! noise paths (only needed when add_noise = true)
    if add_noise
        wham_base_dir = '/pasteur/helix/scratch/mcampi/wham_noise';
        wham_train_dir = fullfile(wham_base_dir, 'tr');
        wham_test_dir  = fullfile(wham_base_dir, 'tt');
        wham_train_meta_file = fullfile(wham_base_dir, 'metadata', 'noise_meta_tr.csv');
        wham_test_meta_file  = fullfile(wham_base_dir, 'metadata', 'noise_meta_tt.csv');
    end

    %% ---- Logging --------------------------------------------------------
    log_dir = fullfile(base_dir, 'logs', [condition_label '_generation']);
    if ~exist(log_dir, 'dir')
        mkdir(log_dir);
    end

    if add_noise && custom_test_snr
        log_file = fullfile(log_dir, sprintf('task_%d_of_%d_%s.log', ...
            task_id, num_tasks, strrep(test_snr_setting, ':', '_')));
    else
        log_file = fullfile(log_dir, sprintf('task_%d_of_%d.log', task_id, num_tasks));
    end
    diary(log_file);

    fprintf('=== Neurogram generation [%s] (Task %d of %d) ===\n', ...
        condition_label, task_id, num_tasks);
    fprintf('Started at: %s\n', datestr(now));
    fprintf('Output directory: %s\n', scratch_dir);

    %% ---- Load WHAM! metadata (noise condition only) ---------------------
    if add_noise
        try
            train_noise_meta = readtable(wham_train_meta_file);
            test_noise_meta  = readtable(wham_test_meta_file);
            fprintf('WHAM! noise samples: Training: %d, Testing: %d\n', ...
                height(train_noise_meta), height(test_noise_meta));
        catch err
            fprintf('Error loading WHAM! metadata: %s\n', err.message);
            diary off;
            return;
        end
    end

    %% ---- Auditory nerve model parameters --------------------------------
    % Paper Section 2.1:
    %   "150 log-spaced characteristic frequencies spanning 125 Hz to 10 kHz"
    %   "high spontaneous rate fibers (100 spikes/s)"
    %   "normal outer and inner hair cell function"
    center_frequencies = logspace(log10(125), log10(10000), 150);
    fsmod = 100e3;       % Model sampling rate (Hz)
    fs_neurogram = 500;  % Target neurogram rate (Hz) → 2 ms bins

    %% ---- Collect and distribute files -----------------------------------
    train_files = get_all_wav_files(train_input_dir);
    test_files  = get_all_wav_files(test_input_dir);
    all_files   = [train_files; test_files];

    fprintf('Found %d total files to process\n', length(all_files));

    files_per_task = ceil(length(all_files) / num_tasks);
    start_idx = (task_id - 1) * files_per_task + 1;
    end_idx   = min(task_id * files_per_task, length(all_files));
    task_files = all_files(start_idx:end_idx);

    fprintf('This task: %d files (indices %d–%d)\n', ...
        length(task_files), start_idx, end_idx);

    rng(42 + task_id);  % Reproducible randomisation per task

    %% ---- Main processing loop -------------------------------------------
    for i = 1:length(task_files)
        file_info = task_files(i);
        is_train  = contains(file_info.filepath, 'TRAIN');

        % --- Output path --------------------------------------------------
        if is_train
            output_dir = train_output_dir;
            path_to_replace = train_input_dir;
        else
            output_dir = test_output_dir;
            path_to_replace = test_input_dir;
        end

        rel_path = strrep(file_info.filepath, path_to_replace, '');
        [~, rel_path] = fileparts(fileparts(rel_path));
        output_subdir = fullfile(output_dir, rel_path);
        if ~exist(output_subdir, 'dir')
            mkdir(output_subdir);
        end

        [~, name, ~] = fileparts(file_info.name);

        if add_noise
            % Noisy condition: filename encodes SNR mode for test data
            if is_train || ~custom_test_snr
                output_file = fullfile(output_subdir, [name '_neurogram_with_noise.mat']);
            else
                if strcmpi(test_snr_mode, 'random')
                    output_file = fullfile(output_subdir, [name '_neurogram_with_noise_random.mat']);
                elseif strcmpi(test_snr_mode, 'fixed')
                    output_file = fullfile(output_subdir, sprintf('%s_neurogram_with_noise_snr%.1f.mat', ...
                        name, test_fixed_snr_values(1)));
                elseif strcmpi(test_snr_mode, 'bands')
                    output_file = fullfile(output_subdir, sprintf('%s_neurogram_with_noise_snr%.1f_%.1f.mat', ...
                        name, test_snr_bands{1}(1), test_snr_bands{1}(2)));
                end
            end
        else
            % Clean condition
            output_file = fullfile(output_subdir, [name '_neurogram.mat']);
        end

        % Skip existing files (resume support)
        if exist(output_file, 'file')
            fprintf('[%d/%d] Skipping existing: %s\n', i, length(task_files), file_info.name);
            continue;
        end

        % --- Generate neurogram -------------------------------------------
        try
            fprintf('[%d/%d] Processing: %s\n', i, length(task_files), file_info.name);

            % Load and resample speech
            [speech, fs] = audioread(file_info.filepath);
            if fs ~= fsmod
                speech = resample(speech, fsmod, fs);
            end

            if add_noise
                % ---- NOISE CONDITION ----

                % Select noise metadata
                if is_train
                    noise_dir  = wham_train_dir;
                    noise_meta = train_noise_meta;
                else
                    noise_dir  = wham_test_dir;
                    noise_meta = test_noise_meta;
                end

                % Pick random WHAM! noise sample
                noise_idx = randi(height(noise_meta));
                if ismember('utterance_id', noise_meta.Properties.VariableNames)
                    noise_filename = noise_meta.utterance_id{noise_idx};
                else
                    first_col = noise_meta.Properties.VariableNames{1};
                    noise_filename = noise_meta.(first_col){noise_idx};
                end
                noise_file = fullfile(noise_dir, noise_filename);

                % Determine target SNR
                if is_train
                    target_snr_db = train_snr_min + (train_snr_max - train_snr_min) * rand();
                else
                    target_snr_db = get_test_snr(test_snr_mode, test_fixed_snr_values, ...
                        test_snr_bands, test_random_snr_min, test_random_snr_max, ...
                        custom_test_snr, i);
                end

                % Load noise
                try
                    [noise_sig, ~] = audioread(noise_file);
                catch
                    if ~endsWith(noise_file, '.wav')
                        [noise_sig, ~] = audioread([noise_file '.wav']);
                    else
                        fprintf('  Error loading noise: %s\n', noise_file);
                        continue;
                    end
                end
                if size(noise_sig, 2) > 1
                    noise_sig = noise_sig(:, 1);
                end

                % Match length
                while length(noise_sig) < length(speech)
                    noise_sig = [noise_sig; noise_sig]; %#ok<AGROW>
                end
                noise_sig = noise_sig(1:length(speech));

                % Mix at target SNR
                speech_power = sum(speech.^2) / length(speech);
                noise_power  = sum(noise_sig.^2) / length(noise_sig);
                scaling = sqrt(speech_power / (noise_power * 10^(target_snr_db / 10)));
                mixed_signal = speech + noise_sig * scaling;
                mixed_signal = mixed_signal / max(abs(mixed_signal));

                % Generate neurograms for mixed and clean signals
                [r_mean, ~, ~, ~, ~, ~, ~] = zilany2014(mixed_signal, fsmod, center_frequencies, ...
                    'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
                [r_mean_clean, ~, ~, ~, ~, ~, ~] = zilany2014(speech, fsmod, center_frequencies, ...
                    'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);

                % Downsample
                ds_factor = fsmod / fs_neurogram;
                r_mean_downsampled       = downsample(r_mean, ds_factor);
                r_mean_clean_downsampled = downsample(r_mean_clean, ds_factor);

                % Save
                noise_info = noise_meta(noise_idx, :);
                save(output_file, 'r_mean_downsampled', 'r_mean_clean_downsampled', ...
                    'center_frequencies', 'noise_info', 'target_snr_db', 'noise_filename');

                fprintf('  Done [noise] SNR=%.1f dB\n', target_snr_db);

            else
                % ---- SILENCE CONDITION ----

                % Generate neurogram for clean speech only
                [r_mean, ~, ~, ~, ~, ~, ~] = zilany2014(speech, fsmod, center_frequencies, ...
                    'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);

                % Downsample
                ds_factor = fsmod / fs_neurogram;
                r_mean_downsampled = downsample(r_mean, ds_factor);

                % Save
                save(output_file, 'r_mean_downsampled', 'center_frequencies');

                fprintf('  Done [clean]\n');
            end

        catch err
            fprintf('  Error: %s — %s\n', file_info.name, err.message);
        end
    end

    fprintf('Task %d of %d completed at: %s\n', task_id, num_tasks, datestr(now));
    diary off;
end


%% ---- Helper: determine test SNR ----------------------------------------
function snr = get_test_snr(mode, fixed_vals, bands, rnd_min, rnd_max, is_custom, file_idx)
    if strcmpi(mode, 'random')
        snr = rnd_min + (rnd_max - rnd_min) * rand();
    elseif strcmpi(mode, 'fixed')
        if length(fixed_vals) > 1 && ~is_custom
            idx = mod(file_idx - 1, length(fixed_vals)) + 1;
            snr = fixed_vals(idx);
        else
            snr = fixed_vals(1);
        end
    elseif strcmpi(mode, 'bands')
        if length(bands) > 1 && ~is_custom
            idx = mod(file_idx - 1, length(bands)) + 1;
            band = bands{idx};
        else
            band = bands{1};
        end
        snr = band(1) + (band(2) - band(1)) * rand();
    else
        snr = 5;  % fallback
    end
end


%% ---- Helper: recursive WAV file listing ---------------------------------
function files = get_all_wav_files(directory)
    files = dir(fullfile(directory, '**', '*.wav'));
    for i = 1:length(files)
        files(i).filepath = fullfile(files(i).folder, files(i).name);
    end
end
