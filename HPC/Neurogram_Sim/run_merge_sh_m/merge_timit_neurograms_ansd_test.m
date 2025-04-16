% Directory containing ANSD neurogram files
train_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD/Phonemes/TEST/';

% Get all .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_ansd.mat'));

% Initialize empty matrix for all neurograms
TIMIT_neurogram_ansd = [];

% Combine neurograms
fprintf('Combining ANSD neurograms...\n');
for i = 1:length(mat_files)
    if mod(i, 100) == 0
        fprintf('Processing file %d of %d\n', i, length(mat_files));
    end
    
    % Load current neurogram
    data = load(fullfile(mat_files(i).folder, mat_files(i).name));
    
    % Vertically concatenate
    TIMIT_neurogram_ansd = [TIMIT_neurogram_ansd; data.r_mean_downsampled];
end

% Save the combined neurogram
fprintf('Saving combined ANSD neurogram...\n');
save('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_neurogram_ansd_test.mat', 'TIMIT_neurogram_ansd', '-v7.3');

fprintf('Done! Combined %d files\n', length(mat_files));
fprintf('Final matrix size: %d x %d\n', size(TIMIT_neurogram_ansd));
