% check_corrupt_files.m
% This script checks for corrupt neurogram files

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
train_dir = fullfile(base_dir, 'SELECT_Neurograms_WithNoise', 'TRAIN');

% Find all files
train_files = dir(fullfile(train_dir, '**', '*neurogram_with_noise.mat'));

fprintf('Found %d training files\n', length(train_files));

% Check for corrupt files
corrupt_files = {};
processed_count = 0;

% Check files in batches to save memory
batch_size = 1000;
num_batches = ceil(length(train_files) / batch_size);

fprintf('Checking training files for corruption in %d batches...\n', num_batches);

for batch = 1:num_batches
    start_idx = (batch-1) * batch_size + 1;
    end_idx = min(batch * batch_size, length(train_files));
    
    fprintf('Processing batch %d of %d (files %d to %d)...\n', batch, num_batches, start_idx, end_idx);
    
    for i = start_idx:end_idx
        file_path = fullfile(train_files(i).folder, train_files(i).name);
        
        try
            % Try to load the file
            data = load(file_path);
            % Try to access a field to ensure the file is valid
            temp = data.r_mean_downsampled;
            processed_count = processed_count + 1;
        catch err
            corrupt_files{end+1} = file_path;
            fprintf('Corrupt file found: %s\n', file_path);
        end
        
        if mod(i, 100) == 0
            fprintf('Checked %d files, found %d corrupt so far\n', i, length(corrupt_files));
        end
    end
end

fprintf('\nCheck completed. Processed %d files successfully. Found %d corrupt files.\n', processed_count, length(corrupt_files));

% Save the list of corrupt files
if ~isempty(corrupt_files)
    save(fullfile(base_dir, 'corrupt_files.mat'), 'corrupt_files');
    fprintf('List of corrupt files saved to %s\n', fullfile(base_dir, 'corrupt_files.mat'));
    
    % Also save as text file for easier reading
    fid = fopen(fullfile(base_dir, 'corrupt_files.txt'), 'w');
    for i = 1:length(corrupt_files)
        fprintf(fid, '%s\n', corrupt_files{i});
    end
    fclose(fid);
    fprintf('List of corrupt files also saved to %s\n', fullfile(base_dir, 'corrupt_files.txt'));
end
