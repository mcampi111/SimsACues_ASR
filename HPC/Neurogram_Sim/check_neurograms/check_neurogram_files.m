% Sample neurogram file checking script
% This will examine a small batch of files to understand their structure

% Directory containing ANSD neurogram files with noise
train_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise/TRAIN/';

% Get all noise .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_with_noise.mat'));
fprintf('Found %d files for ANSD training with noise\n', length(mat_files));

% Sample a small number of files to check their structure
sample_size = 20;
fprintf('Examining %d random sample files to understand data structure...\n', sample_size);

% Get random indices for sampling
sample_indices = randperm(length(mat_files), sample_size);

% Create arrays to store findings
file_sizes = zeros(sample_size, 1);
variable_names = cell(sample_size, 1);
dimensions = cell(sample_size, 1);
load_method_success = zeros(sample_size, 2); % [standard_load, matfile_load]

% Examine each sample file
for i = 1:sample_size
    idx = sample_indices(i);
    file_path = fullfile(mat_files(idx).folder, mat_files(idx).name);
    
    fprintf('\nFile %d: %s\n', i, mat_files(idx).name);
    
    % Get file size
    file_info = dir(file_path);
    file_sizes(i) = file_info.bytes;
    fprintf('  File size: %.2f MB\n', file_sizes(i)/1024/1024);
    
    % Try checking file structure without loading the full data
    try
        file_vars = whos('-file', file_path);
        variable_names{i} = {file_vars.name};
        fprintf('  Variables in file: %s\n', strjoin({file_vars.name}, ', '));
        
        % Find r_mean_downsampled variable
        r_mean_idx = find(strcmp({file_vars.name}, 'r_mean_downsampled'), 1);
        if ~isempty(r_mean_idx)
            fprintf('  r_mean_downsampled: %s, %.2f MB\n', ...
                   mat2str(file_vars(r_mean_idx).size), ...
                   file_vars(r_mean_idx).bytes/1024/1024);
        else
            fprintf('  WARNING: r_mean_downsampled variable not found\n');
        end
    catch err
        fprintf('  Error checking file structure: %s\n', err.message);
    end
    
    % Try loading with standard method
    try
        tic;
        data = load(file_path);
        standard_time = toc;
        fprintf('  Standard load: SUCCESS (%.2f sec)\n', standard_time);
        load_method_success(i, 1) = 1;
        
        if isfield(data, 'r_mean_downsampled')
            dimensions{i} = size(data.r_mean_downsampled);
            fprintf('  r_mean_downsampled dimensions: %s\n', mat2str(dimensions{i}));
            fprintf('  Data type: %s\n', class(data.r_mean_downsampled));
        else
            fprintf('  WARNING: r_mean_downsampled field not found in loaded data\n');
        end
    catch err
        fprintf('  Standard load: FAILED - %s\n', err.message);
    end
    
    % Try loading with matfile
    try
        tic;
        m = matfile(file_path);
        matfile_time = toc;
        fprintf('  Matfile access: SUCCESS (%.2f sec)\n', matfile_time);
        load_method_success(i, 2) = 1;
        
        % Try to access r_mean_downsampled
        try
            var_info = whos(m, 'r_mean_downsampled');
            if ~isempty(var_info)
                fprintf('  r_mean_downsampled available via matfile\n');
            end
        catch
            fprintf('  Could not access r_mean_downsampled via matfile\n');
        end
    catch err
        fprintf('  Matfile access: FAILED - %s\n', err.message);
    end
end

% Summarize findings
fprintf('\n=== SUMMARY REPORT ===\n');
fprintf('Average file size: %.2f MB\n', mean(file_sizes)/1024/1024);
fprintf('Standard load success rate: %.1f%%\n', 100*mean(load_method_success(:,1)));
fprintf('Matfile access success rate: %.1f%%\n', 100*mean(load_method_success(:,2)));

% Check for dimension consistency
valid_dims = dimensions(~cellfun(@isempty, dimensions));
if ~isempty(valid_dims)
    unique_dims = unique(cat(1, valid_dims{:}), 'rows');
    fprintf('Found %d unique dimension patterns:\n', size(unique_dims, 1));
    for i = 1:size(unique_dims, 1)
        fprintf('  Dimension pattern %d: %s\n', i, mat2str(unique_dims(i,:)));
    end
else
    fprintf('No valid dimensions found in sample files.\n');
end

% Check variable names consistency
if all(~cellfun(@isempty, variable_names))
    all_vars = unique([variable_names{:}]);
    fprintf('Variables found across all files: %s\n', strjoin(all_vars, ', '));
    
    % Check if r_mean_downsampled exists in all files
    r_mean_exists = cellfun(@(x) any(strcmp(x, 'r_mean_downsampled')), variable_names);
    fprintf('r_mean_downsampled exists in %.1f%% of sample files\n', 100*mean(r_mean_exists));
end

fprintf('\nRecommendation based on sample analysis:\n');
if mean(load_method_success(:,1)) > mean(load_method_success(:,2))
    fprintf('- Prefer standard load method\n');
else
    fprintf('- Prefer matfile access method\n');
end

if ~isempty(valid_dims) && size(unique_dims, 1) == 1
    fprintf('- All samples have consistent dimensions - can use matrix approach\n');
else
    fprintf('- Samples have varying dimensions - use cell array approach\n');
end
