% Directory containing ANSD neurogram files with noise
test_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise/TEST/';

% Define the noise conditions to process
noise_conditions = {'default', 'snr0.0', 'snr5.0', 'snr10.0', 'snr15.0', 'snr-5.0'};

for condition_idx = 1:length(noise_conditions)
    current_condition = noise_conditions{condition_idx};
    fprintf('Processing condition: %s\n', current_condition);
    
    % Define the pattern to search for based on the condition
    pattern = ['*_with_noise_ansd_' current_condition '.mat'];
    
    % Get all .mat files matching the pattern recursively
    mat_files = dir(fullfile(test_dir, '**', pattern));
    
    fprintf('Found %d files for condition %s\n', length(mat_files), current_condition);
    
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
        file_path = fullfile(mat_files(i).folder, mat_files(i).name);
        data = matfile(file_path);
        
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
    TIMIT_neurogram_ansd_test_with_noise = zeros(total_rows, 150);
    
    % Now combine all the pieces sequentially
    fprintf('Assembling final matrix...\n');
    current_row = 1;
    for i = 1:length(mat_files)
        rows_to_add = size(temp_storage{i}, 1);
        TIMIT_neurogram_ansd_test_with_noise(current_row:current_row+rows_to_add-1, :) = temp_storage{i};
        current_row = current_row + rows_to_add;
    end
    
    % Delete parallel pool
    delete(pool);
    
    % Save the combined neurogram for the current condition
    output_filename = sprintf('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/TIMIT_neurogram_ansd_test_with_noise_%s.mat', current_condition);
    fprintf('Saving combined ANSD neurogram for condition %s...\n', current_condition);
    save(output_filename, 'TIMIT_neurogram_ansd_test_with_noise', '-v7.3');
    
    fprintf('Done! Combined %d files for condition %s\n', length(mat_files), current_condition);
    fprintf('Final matrix size: %d x %d\n', size(TIMIT_neurogram_ansd_test_with_noise));
end

fprintf('All noise conditions processed successfully!\n');
