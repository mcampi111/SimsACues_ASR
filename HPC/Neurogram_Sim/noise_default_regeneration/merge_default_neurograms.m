% merge_default_neurograms.m
%
% This script merges the default noise neurograms in a consistent way

function merge_default_neurograms()
    % Add the AMT toolbox path
    addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

    % Initialize AMT
    amt_start();

    % Define paths
    base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
    input_dir = '/pasteur/helix/scratch/mcampi/neurograms_wham/healthy/TEST_default';
    
    % Output directory for merged file
    output_dir = fullfile(base_dir, 'TIMIT_mat');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Output file
    output_file = fullfile(output_dir, 'TIMIT_neurogram_test_with_noise_default.mat');

    % Find all default noise neurogram files
    files = dir(fullfile(input_dir, '**', '*neurogram_with_noise_default.mat'));
    fprintf('Found %d default noise neurogram files\n', length(files));

    % Create log file
    log_dir = fullfile(base_dir, 'logs', 'merge_default');
    if ~exist(log_dir, 'dir')
        mkdir(log_dir);
    end
    log_file = fullfile(log_dir, 'merge_default_neurograms.log');
    diary(log_file);
    
    fprintf('Starting merger of default noise neurograms\n');
    fprintf('Started at: %s\n', datestr(now));

    % Sort files to ensure consistent ordering
    [~, indices] = sort({files.name});
    files = files(indices);

    % Initialize arrays for concatenation
    all_neurograms = [];
    total_time_points = 0;
    cf_saved = false;

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
            
            % Extract neurogram
            neurogram = data.r_mean_downsampled;
            
            % Concatenate along time dimension
            if isempty(all_neurograms)
                all_neurograms = neurogram;
            else
                all_neurograms = [all_neurograms; neurogram];
            end
            
            % Save center frequencies on first successful load
            if ~cf_saved && isfield(data, 'center_frequencies')
                center_frequencies = data.center_frequencies;
                cf_saved = true;
            end
            
            % Track progress
            total_time_points = total_time_points + size(neurogram, 1);
            success_count = success_count + 1;
        catch err
            % Log error and continue
            fprintf('Error processing file %s: %s\n', files(i).name, err.message);
            error_count = error_count + 1;
        end
    end

    % Print stats
    fprintf('\nProcessing completed.\n');
    fprintf('Successfully processed %d files (%d errors).\n', success_count, error_count);
    fprintf('Total time points: %d\n', total_time_points);
    fprintf('Final neurogram shape: %d x %d\n', size(all_neurograms, 1), size(all_neurograms, 2));

    % Save merged data
    fprintf('Saving merged data to %s\n', output_file);
    
    % Get the variable name matching other SNR files
    var_name = 'TIMIT_neurogram_test_with_noise_default';
    
    % Create a struct with the main variable
    S.(var_name) = all_neurograms;
    
    % Also save center frequencies
    if cf_saved
        S.center_frequencies = center_frequencies;
    end
    
    % Save using -v7.3 format for large matrices
    save(output_file, '-struct', 'S', '-v7.3');

    fprintf('Done!\n');
    diary off;
end
