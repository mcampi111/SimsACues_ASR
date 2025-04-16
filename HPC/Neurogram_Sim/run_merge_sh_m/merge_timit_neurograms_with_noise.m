% merge_timit_neurograms_with_noise.m
%
% This script merges neurograms with WHAM noise from the training set
% Reading directly from scratch space to avoid transfer corruption

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
input_dir = '/pasteur/helix/scratch/mcampi/neurograms_wham/TRAIN';  % Read directly from scratch

% Output file
output_file = fullfile(base_dir, 'TIMIT_neurogram_with_noise.mat');

% Find all neurogram files
files = dir(fullfile(input_dir, '**', '*neurogram_with_noise.mat'));
fprintf('Found %d neurogram files\n', length(files));

% Use a cell array to store neurograms with different dimensions
all_neurograms = {};
all_labels = {};
all_sentence_ids = {};
all_snrs = [];

% Process each file
fprintf('Processing files...\n');
error_count = 0;
success_count = 0;

for i = 1:length(files)
    if mod(i, 1000) == 0
        fprintf('Processing file %d of %d\n', i, length(files));
    end
    
    try
        % Load neurogram file
        neurogram_file = fullfile(files(i).folder, files(i).name);
        data = load(neurogram_file);
        
        % Extract neurogram (use noisy version)
        neurogram = data.r_mean_downsampled;
        
        % Store neurogram in cell array to handle different dimensions
        all_neurograms{end+1} = neurogram;
        
        % Extract speaker/sentence information from path
        path_parts = strsplit(files(i).folder, filesep);
        speaker_id = path_parts{end};
        
        % Extract sentence ID from filename
        [~, filename, ~] = fileparts(files(i).name);
        sentence_parts = strsplit(filename, '_');
        sentence_id = sentence_parts{1};
        
        % Store metadata
        all_sentence_ids{end+1} = [speaker_id '_' sentence_id];
        all_labels{end+1} = 'normal'; % All training data is normal
        all_snrs(end+1) = data.target_snr_db;
        
        success_count = success_count + 1;
    catch err
        % Log error and continue
        fprintf('Error processing file %s: %s\n', files(i).name, err.message);
        error_count = error_count + 1;
    end
end

% Also save the center frequencies for reference
if ~isempty(all_neurograms) && isfield(data, 'center_frequencies')
    center_frequencies = data.center_frequencies;
else
    center_frequencies = []; % Empty if not available
end

% Print stats
fprintf('\nProcessing completed. Successfully processed %d files (%d errors).\n', ...
    success_count, error_count);

% Save merged data
fprintf('Saving merged data to %s\n', output_file);
save(output_file, 'all_neurograms', 'all_labels', 'all_sentence_ids', 'all_snrs', 'center_frequencies', '-v7.3');

fprintf('Done!\n');
