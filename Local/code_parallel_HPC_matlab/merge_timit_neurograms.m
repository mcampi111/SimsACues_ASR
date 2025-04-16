% Directory containing neurogram files
train_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms/TRAIN/';

% Get all .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_neurogram.mat'));

% Initialize parallel pool
num_workers = feature('numcores');
pool = parpool(num_workers);

% First, verify columns and calculate total rows needed
fprintf('Checking neurograms and calculating total size...\n');
total_rows = 0;
temp_storage = cell(length(mat_files), 1);

% Load and check all files in parallel
parfor i = 1:length(mat_files)
    if mod(i, 100) == 0
        fprintf('Processing file %d of %d\n', i, length(mat_files));
    end
    
    % Load current neurogram
    data = load(fullfile(mat_files(i).folder, mat_files(i).name));
    
    % Verify columns = 150
    if size(data.r_mean_downsampled, 2) ~= 150
        error('Column size mismatch in file %s: expected 150, got %d', ...
              mat_files(i).name, size(data.r_mean_downsampled, 2));
    end
    
    % Store in temporary cell array
    temp_storage{i} = data.r_mean_downsampled;
end

% Calculate total rows
for i = 1:length(mat_files)
    total_rows = total_rows + size(temp_storage{i}, 1);
end

% Preallocate final matrix
TIMIT_neurogram = zeros(total_rows, 150);

% Now combine all the pieces sequentially
fprintf('Assembling final matrix...\n');
current_row = 1;
for i = 1:length(mat_files)
    rows_to_add = size(temp_storage{i}, 1);
    TIMIT_neurogram(current_row:current_row+rows_to_add-1, :) = temp_storage{i};
    current_row = current_row + rows_to_add;
end

% Delete parallel pool
delete(pool);

% Save the combined neurogram
fprintf('Saving combined neurogram...\n');
save('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_neurogram.mat', 'TIMIT_neurogram', '-v7.3');

fprintf('Done! Combined %d files\n', length(mat_files));
fprintf('Final matrix size: %d x %d\n', size(TIMIT_neurogram));
