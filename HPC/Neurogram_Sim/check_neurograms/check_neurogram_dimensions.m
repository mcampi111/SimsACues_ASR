% check_neurogram_dimensions.m
%
% This script samples neurogram files and reports their dimensions
% to help diagnose concatenation errors

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Define paths
base_dir = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim';
train_dir = fullfile(base_dir, 'SELECT_Neurograms_WithNoise', 'TRAIN');
test_dir = fullfile(base_dir, 'SELECT_Neurograms_WithNoise', 'TEST');

% Find sample files
train_files = dir(fullfile(train_dir, '**', '*neurogram_with_noise.mat'));
test_files = dir(fullfile(test_dir, '**', '*neurogram_with_noise.mat'));

fprintf('Found %d training files and %d test files\n', length(train_files), length(test_files));

% Sample size
sample_size = min(20, min(length(train_files), length(test_files)));

% Sample and check training files
fprintf('\nChecking %d sample training files:\n', sample_size);
train_indices = randperm(length(train_files), sample_size);

% Store dimension info
train_dims = zeros(sample_size, 2);

for i = 1:sample_size
    idx = train_indices(i);
    file_path = fullfile(train_files(idx).folder, train_files(idx).name);
    
    % Load file
    data = load(file_path);
    
    % Get neurogram dimensions
    [freq_bins, time_bins] = size(data.r_mean_downsampled);
    train_dims(i,:) = [freq_bins, time_bins];
    
    fprintf('File %d: %s - Dimensions: %d x %d\n', i, train_files(idx).name, freq_bins, time_bins);
end

% Check if all training dimensions are the same
if all(train_dims(:,1) == train_dims(1,1)) && all(train_dims(:,2) == train_dims(1,2))
    fprintf('All sampled training neurograms have the same dimensions: %d x %d\n', train_dims(1,1), train_dims(1,2));
else
    fprintf('WARNING: Training neurograms have different dimensions!\n');
    fprintf('  Frequency bins range: %d to %d\n', min(train_dims(:,1)), max(train_dims(:,1)));
    fprintf('  Time bins range: %d to %d\n', min(train_dims(:,2)), max(train_dims(:,2)));
end

% Sample and check test files
fprintf('\nChecking %d sample test files:\n', sample_size);
test_indices = randperm(length(test_files), sample_size);

% Store dimension info
test_dims = zeros(sample_size, 2);

for i = 1:sample_size
    idx = test_indices(i);
    file_path = fullfile(test_files(idx).folder, test_files(idx).name);
    
    % Load file
    data = load(file_path);
    
    % Get neurogram dimensions
    [freq_bins, time_bins] = size(data.r_mean_downsampled);
    test_dims(i,:) = [freq_bins, time_bins];
    
    fprintf('File %d: %s - Dimensions: %d x %d\n', i, test_files(idx).name, freq_bins, time_bins);
end

% Check if all test dimensions are the same
if all(test_dims(:,1) == test_dims(1,1)) && all(test_dims(:,2) == test_dims(1,2))
    fprintf('All sampled test neurograms have the same dimensions: %d x %d\n', test_dims(1,1), test_dims(1,2));
else
    fprintf('WARNING: Test neurograms have different dimensions!\n');
    fprintf('  Frequency bins range: %d to %d\n', min(test_dims(:,1)), max(test_dims(:,1)));
    fprintf('  Time bins range: %d to %d\n', min(test_dims(:,2)), max(test_dims(:,2)));
end

% Compare train and test dimensions
if isequal(train_dims(1,:), test_dims(1,:))
    fprintf('\nTraining and test dimensions match: %d x %d\n', train_dims(1,1), train_dims(1,2));
else
    fprintf('\nWARNING: Training and test dimensions differ!\n');
    fprintf('  Training: %d x %d\n', train_dims(1,1), train_dims(1,2));
    fprintf('  Test: %d x %d\n', test_dims(1,1), test_dims(1,2));
end

fprintf('\nCheck completed.\n');
