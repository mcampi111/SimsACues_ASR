% Directory containing your neurogram files
train_dir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/code_all/SELECT_Neurograms/Phonemes/TRAIN/';

% Get all .mat files recursively
mat_files = dir(fullfile(train_dir, '**', '*_neurogram.mat'));

% Initialize variables to store dimensions
total_rows = 0;
n_cols = [];

% Check dimensions of each file
fprintf('Checking neurogram dimensions...\n');
for i = 1:length(mat_files)
    if mod(i, 100) == 0
        fprintf('Processing file %d of %d\n', i, length(mat_files));
    end
    
    % Load current neurogram
    data = load(fullfile(mat_files(i).folder, mat_files(i).name));
    
    % Get size of r_mean_downsampled
    current_size = size(data.r_mean_downsampled);
    
    % Add rows to total
    total_rows = total_rows + current_size(1);
    
    % Keep track of number of columns (should be consistent)
    n_cols = [n_cols; current_size(2)];
end

% Check if all files have same number of columns
if length(unique(n_cols)) > 1
    warning('Not all matrices have the same number of columns!');
    fprintf('Found column sizes: %s\n', mat2str(unique(n_cols)));
else
    fprintf('All matrices have %d columns\n', n_cols(1));
end

% Calculate final matrix size
fprintf('\nSummary:\n');
fprintf('Total number of files: %d\n', length(mat_files));
fprintf('Expected final matrix size: %d x %d\n', total_rows, n_cols(1));
fprintf('Expected memory usage (GB): %.2f\n', ...
    (total_rows * n_cols(1) * 8) / (1024^3)); % assuming double precision (8 bytes)


%%
% FINAL OUTPUT:
%All matrices have 150 columns

%Summary:
%Total number of files: 95891
%Expected final matrix size: 7741629 x 150
%Expected memory usage (GB): 8.65


