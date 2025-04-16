% Add the path to the AMT toolbox
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0'); % Adjust path as needed

% Initialize the AMT
amt_start();

% Define directories
input_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT/TRAIN/DR4/';
output_base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms/TRAIN/';
log_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/';

% Model parameters
center_frequencies = logspace(log10(125), log10(10000), 150);
fsmod = 100e3;
fs_neurogram = 500;

% Create output DR4 directory if it doesn't exist
output_dr_path = fullfile(output_base_dir, 'DR4');
if ~exist(output_dr_path, 'dir')
    mkdir(output_dr_path);
end

% Get speaker assigned to this job from environment variable
speaker_idx = str2double(getenv('SLURM_ARRAY_TASK_ID'));
speaker_dirs = dir(input_dir);
speaker_dirs = speaker_dirs([speaker_dirs.isdir]);
speaker_dirs = speaker_dirs(~ismember({speaker_dirs.name}, {'.', '..'}));

if speaker_idx <= length(speaker_dirs)
    current_speaker = speaker_dirs(speaker_idx).name;
    speaker_path = fullfile(input_dir, current_speaker);
    output_speaker_path = fullfile(output_dr_path, current_speaker);
    
    % Create speaker directory
    if ~exist(output_speaker_path, 'dir')
        mkdir(output_speaker_path);
    end
    
    % Process all WAV files for this speaker
    wav_files = dir(fullfile(speaker_path, '*.wav'));
    
    % Create log file for this speaker
    log_file = fullfile(log_dir, ['speaker_' current_speaker '_log.txt']);
    diary(log_file);
    
    fprintf('Processing speaker: %s\n', current_speaker);
    fprintf('Found %d files to process\n', length(wav_files));
    
    for wav_idx = 1:length(wav_files)
        try
            % Load and process WAV file
            [audio, fs] = audioread(fullfile(speaker_path, wav_files(wav_idx).name));
            
            if fs ~= fsmod
                audio = resample(audio, fsmod, fs);
            end
            
            [r_mean, ~, ~, ~, ~, ~, output] = zilany2014(audio, fsmod, center_frequencies, ...
                'fiberType', 3, 'nrep', 1, 'cohc', 1.0, 'cihc', 1.0);
            
            % Downsample
            downsampling_factor = fsmod / fs_neurogram;
            r_mean_downsampled = downsample(r_mean, downsampling_factor);
            
            % Save output
            [~, name, ~] = fileparts(wav_files(wav_idx).name);
            output_file = fullfile(output_speaker_path, [name '_neurogram.mat']);
            save(output_file, 'r_mean_downsampled', 'center_frequencies');
            
            fprintf('Successfully processed: %s\n', wav_files(wav_idx).name);
        catch ME
            fprintf('Error processing %s: %s\n', wav_files(wav_idx).name, ME.message);
        end
    end
    
    fprintf('Finished processing speaker: %s\n', current_speaker);
    diary off;
end