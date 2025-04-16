% Directory containing neurogram files
train_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms/TRAIN/';

% Get all .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_neurogram.mat'));

% Initialize parallel pool
num_workers = feature('numcores');  % Get number of available cores
pool = parpool(num_workers);        % Create parallel pool

% First, get size of one neurogram to preallocate
first_data = load(fullfile(mat_files(1).folder, mat_files(1).name));
[rows, cols] = size(first_data.r_mean_downsampled);

% Preallocate full matrix
TIMIT_neurogram = zeros(rows * length(mat_files), cols);

% Create a temporary cell array to store results
temp_storage = cell(length(mat_files), 1);

% Combine neurograms using parallel processing
fprintf('Combining neurograms...\n');
parfor i = 1:length(mat_files)
    if mod(i, 100) == 0
        fprintf('Processing file %d of %d\n', i, length(mat_files));
    end
    
    % Load current neurogram
    data = load(fullfile(mat_files(i).folder, mat_files(i).name));
    
    % Store in temporary cell array
    temp_storage{i} = data.r_mean_downsampled;
end

% Now combine all the pieces sequentially
fprintf('Assembling final matrix...\n');
for i = 1:length(mat_files)
    start_idx = (i-1) * rows + 1;
    end_idx = i * rows;
    TIMIT_neurogram(start_idx:end_idx, :) = temp_storage{i};
end

% Delete parallel pool
delete(pool);

% Save the combined neurogram
fprintf('Saving combined neurogram...\n');
save('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_neurogram.mat', 'TIMIT_neurogram', '-v7.3');

fprintf('Done! Combined %d files\n', length(mat_files));
fprintf('Final matrix size: %d x %d\n', size(TIMIT_neurogram));