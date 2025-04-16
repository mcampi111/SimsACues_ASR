% A% Add the path to the AMT toolbox
addpath('/Users/mcampi/Desktop/To_Marta/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize the AMT
amt_start();

% Define base directories
train_input_dir = '/Users/mcampi/Desktop/To_Marta/CI-ASR/TIMIT/timit/SELECT/TIMIT/TRAIN_Phonemes/TRAIN/';
test_input_dir = '/Users/mcampi/Desktop/To_Marta/CI-ASR/TIMIT/timit/SELECT/TIMIT/TEST_Phonemes/TEST/';

train_output_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TRAIN/';
test_output_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TEST/';

%%
% Model parameters
center_frequencies = logspace(log10(125), log10(10000), 150);  % 150 CFs logarithmically spaced from 125 Hz to 10,000 Hz
fsmod = 100e3;  % Model sampling rate (adjustable)
fs_neurogram = 500; % Neurogram target sampling rate (500 Hz, equivalent to 2 ms bins)
%%
% Function to process directories
function process_directory(input_base_dir, output_base_dir, fsmod, fs_neurogram, center_frequencies)
    % Get all DR directories
    dr_dirs = dir(fullfile(input_base_dir, 'DR*'));
    
    for dr_idx = 1:length(dr_dirs)
        if ~dr_dirs(dr_idx).isdir || strcmp(dr_dirs(dr_idx).name, '.') || strcmp(dr_dirs(dr_idx).name, '..')
            continue;
        end
        
        dr_path = fullfile(input_base_dir, dr_dirs(dr_idx).name);
        
        % Get all speaker directories within DR directory
        speaker_dirs = dir(dr_path);
        speaker_dirs = speaker_dirs([speaker_dirs.isdir]);
        
        % Create corresponding output DR directory
        output_dr_path = fullfile(output_base_dir, dr_dirs(dr_idx).name);
        if ~exist(output_dr_path, 'dir')
            mkdir(output_dr_path);
        end
        
        for spk_idx = 1:length(speaker_dirs)
            if strcmp(speaker_dirs(spk_idx).name, '.') || strcmp(speaker_dirs(spk_idx).name, '..')
                continue;
            end
            
            speaker_path = fullfile(dr_path, speaker_dirs(spk_idx).name);
            
            % Create corresponding output speaker directory
            output_speaker_path = fullfile(output_dr_path, speaker_dirs(spk_idx).name);
            if ~exist(output_speaker_path, 'dir')
                mkdir(output_speaker_path);
            end
            
            % Process all WAV files in speaker directory
            wav_files = dir(fullfile(speaker_path, '*.wav'));
            
            for wav_idx = 1:length(wav_files)
                % Load the WAV file
                [audio, fs] = audioread(fullfile(speaker_path, wav_files(wav_idx).name));
                
                % Resample audio if needed
                if fs ~= fsmod
                    audio = resample(audio, fsmod, fs);
                    fs = fsmod;
                end
                
                % Generate auditory nerve response using Zilany model
                [r_mean, ~, ~, ~, ~, ~, output] = zilany2014(audio, fsmod, center_frequencies, ...
                                               'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
                
                % Downsample the auditory nerve response to match 2 ms bins (500 Hz)
                downsampling_factor = fsmod / fs_neurogram;
                r_mean_downsampled = downsample(r_mean, downsampling_factor); % Downsample each frequency channel
                
                % Create output filename
                [~, name, ~] = fileparts(wav_files(wav_idx).name);
                output_file = fullfile(output_speaker_path, [name '_neurogram.mat']);
                
                % Save neurogram
                save(output_file, 'r_mean_downsampled', 'center_frequencies');
                
                fprintf('Processed: %s', wav_files(wav_idx).name);
            end
        end
    end
end

%%

% Process TRAIN directory
fprintf('Processing TRAIN directory...\n');
process_directory(train_input_dir, train_output_dir, fsmod, fs_neurogram, center_frequencies);

%%

% Process TEST directory
fprintf('Processing TEST directory...\n');
process_directory(test_input_dir, test_output_dir, fsmod, fs_neurogram, center_frequencies);

%%
% Function to count files in directories recursively
function count = countFilesRecursively(directory, extension)
    count = 0;
    items = dir(fullfile(directory, '**', ['*.' extension]));
    count = length(items);
end

% Count and compare files
fprintf('\nChecking file counts...\n');

% Count input WAV files
train_wav_count = countFilesRecursively(train_input_dir, 'wav');
test_wav_count = countFilesRecursively(test_input_dir, 'wav');

% Count output MAT files
train_mat_count = countFilesRecursively(train_output_dir, 'mat');
test_mat_count = countFilesRecursively(test_output_dir, 'mat');

% Display results
fprintf('\nTRAIN directory:\n');
fprintf('Input WAV files: %d\n', train_wav_count);
fprintf('Output MAT files: %d\n', train_mat_count);
if train_wav_count == train_mat_count
    fprintf('✓ All TRAIN files processed successfully\n');
else
    fprintf('⚠ Mismatch in TRAIN files count!\n');
end

fprintf('\nTEST directory:\n');
fprintf('Input WAV files: %d\n', test_wav_count);
fprintf('Output MAT files: %d\n', test_mat_count);
if test_wav_count == test_mat_count
    fprintf('✓ All TEST files processed successfully\n');
else
    fprintf('⚠ Mismatch in TEST files count!\n');
end

%%
