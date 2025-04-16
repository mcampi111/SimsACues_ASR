% compare_merged_neurograms.m (fixed version)
%
% This script inspects both clean and noisy neurogram files
% to determine how they differ and if data was lost

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
clean_file = fullfile(base_dir, 'TIMIT_neurogram.mat');
noisy_file = fullfile(base_dir, 'TIMIT_neurogram_with_noise.mat');

% First check if the files exist
if ~exist(clean_file, 'file')
    error('Clean file not found: %s', clean_file);
end

if ~exist(noisy_file, 'file')
    error('Noisy file not found: %s', noisy_file);
end

% Load information about clean neurogram file
fprintf('Examining clean neurogram file: %s\n', clean_file);
clean_info = whos('-file', clean_file);
fprintf('Variables in clean file:\n');
for i = 1:length(clean_info)
    fprintf('  %s: %s, Size: %s\n', clean_info(i).name, clean_info(i).class, mat2str(clean_info(i).size));
end

% Load information about noisy neurogram file
fprintf('\nExamining noisy neurogram file: %s\n', noisy_file);
noisy_info = whos('-file', noisy_file);
fprintf('Variables in noisy file:\n');
for i = 1:length(noisy_info)
    fprintf('  %s: %s, Size: %s\n', noisy_info(i).name, noisy_info(i).class, mat2str(noisy_info(i).size));
end

% Load both files to examine content
fprintf('\nLoading files to examine content...\n');

try
    % Load clean file
    clean_data = load(clean_file);
    clean_vars = fieldnames(clean_data);
    
    % Load noisy file
    noisy_data = load(noisy_file);
    noisy_vars = fieldnames(noisy_data);
    
    % Determine sample counts based on available data
    fprintf('\n===== CONTENT ANALYSIS =====\n');
    
    % Check clean file structure
    fprintf('Clean file structure:\n');
    for i = 1:length(clean_vars)
        var_name = clean_vars{i};
        var_data = clean_data.(var_name);
        
        % Check type of variable
        if iscell(var_data)
            fprintf('  %s: Cell array with %d elements\n', var_name, numel(var_data));
            
            % Sample first few elements if they exist
            if numel(var_data) > 0
                fprintf('    Sample values: ');
                for j = 1:min(3, numel(var_data))
                    if ischar(var_data{j})
                        fprintf('"%s" ', var_data{j});
                    elseif isnumeric(var_data{j})
                        if numel(var_data{j}) == 1
                            fprintf('%g ', var_data{j});
                        else
                            fprintf('[%dx%d] ', size(var_data{j}, 1), size(var_data{j}, 2));
                        end
                    else
                        fprintf('(%s) ', class(var_data{j}));
                    end
                end
                fprintf('\n');
            end
        elseif isnumeric(var_data)
            fprintf('  %s: Numeric array with dimensions %s\n', var_name, mat2str(size(var_data)));
        else
            fprintf('  %s: %s\n', var_name, class(var_data));
        end
    end
    
    % Check noisy file structure
    fprintf('\nNoisy file structure:\n');
    for i = 1:length(noisy_vars)
        var_name = noisy_vars{i};
        var_data = noisy_data.(var_name);
        
        % Check type of variable
        if iscell(var_data)
            fprintf('  %s: Cell array with %d elements\n', var_name, numel(var_data));
            
            % Sample first few elements if they exist
            if numel(var_data) > 0
                fprintf('    Sample values: ');
                for j = 1:min(3, numel(var_data))
                    if ischar(var_data{j})
                        fprintf('"%s" ', var_data{j});
                    elseif isnumeric(var_data{j})
                        if numel(var_data{j}) == 1
                            fprintf('%g ', var_data{j});
                        else
                            fprintf('[%dx%d] ', size(var_data{j}, 1), size(var_data{j}, 2));
                        end
                    else
                        fprintf('(%s) ', class(var_data{j}));
                    end
                end
                fprintf('\n');
            end
        elseif isnumeric(var_data)
            fprintf('  %s: Numeric array with dimensions %s\n', var_name, mat2str(size(var_data)));
        else
            fprintf('  %s: %s\n', var_name, class(var_data));
        end
    end
    
    % Try to determine the number of samples in each file
    fprintf('\n===== SAMPLE COUNT ESTIMATION =====\n');
    
    % For clean file
    clean_samples = NaN;
    for i = 1:length(clean_vars)
        var_name = clean_vars{i};
        var_data = clean_data.(var_name);
        
        if iscell(var_data)
            fprintf('Clean file possible sample count from %s: %d\n', var_name, numel(var_data));
            clean_samples = numel(var_data);
        elseif isnumeric(var_data) && length(size(var_data)) == 2
            % Maybe it's a dataset with samples as rows or columns
            [rows, cols] = size(var_data);
            fprintf('Clean file dimensions of %s: %d rows x %d columns\n', var_name, rows, cols);
        end
    end
    
    % For noisy file
    noisy_samples = NaN;
    for i = 1:length(noisy_vars)
        var_name = noisy_vars{i};
        var_data = noisy_data.(var_name);
        
        if iscell(var_data)
            fprintf('Noisy file possible sample count from %s: %d\n', var_name, numel(var_data));
            noisy_samples = numel(var_data);
        elseif isnumeric(var_data) && length(size(var_data)) == 2
            % Maybe it's a dataset with samples as rows or columns
            [rows, cols] = size(var_data);
            fprintf('Noisy file dimensions of %s: %d rows x %d columns\n', var_name, rows, cols);
        end
    end
    
    % If we found sample counts, calculate difference
    if ~isnan(clean_samples) && ~isnan(noisy_samples)
        diff_count = clean_samples - noisy_samples;
        diff_percent = (diff_count / clean_samples) * 100;
        
        fprintf('\n===== SUMMARY =====\n');
        fprintf('Clean file samples: %d\n', clean_samples);
        fprintf('Noisy file samples: %d\n', noisy_samples);
        fprintf('Difference: %d samples (%.2f%%)\n', diff_count, diff_percent);
    else
        fprintf('\nCould not reliably determine sample counts from file structures.\n');
        fprintf('Please examine the file information above manually.\n');
    end
catch err
    fprintf('Error during analysis: %s\n', err.message);
end

fprintf('\nComparison completed.\n');
