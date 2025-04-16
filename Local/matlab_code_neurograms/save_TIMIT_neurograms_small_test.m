% Directory containing neurogram files
train_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TRAIN/';

% Get all .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_neurogram.mat'));

% Randomly select 1000 files
n_files = 1000;
rng(42); % for reproducibility
selected_indices = randperm(length(mat_files), n_files);
selected_files = mat_files(selected_indices);

% Initialize empty matrix for selected neurograms
TIMIT_neurogram = [];

% Combine selected neurograms
fprintf('Combining %d neurograms for test subset...\n', n_files);
for i = 1:length(selected_files)
    if mod(i, 100) == 0
        fprintf('Processing file %d of %d\n', i, n_files);
    end
    
    % Load current neurogram
    data = load(fullfile(selected_files(i).folder, selected_files(i).name));
    
    % Vertically concatenate
    TIMIT_neurogram = [TIMIT_neurogram; data.r_mean_downsampled];
end

% Save the combined neurogram
fprintf('Saving test subset neurogram...\n');
save('TIMIT_neurogram_small.mat', 'TIMIT_neurogram', '-v7.3');

% Also save the list of selected files for reference
selected_filenames = {selected_files.name};
save('selected_files_list.mat', 'selected_filenames');

fprintf('Done! Combined %d files\n', length(selected_files));
fprintf('Final matrix size: %d x %d\n', size(TIMIT_neurogram));