% examine_corrupt_file.m
%
% This script attempts to diagnose issues with a corrupt MAT file

% Add the AMT toolbox path
addpath('/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize AMT
amt_start();

% Specify the corrupt file to examine
corrupt_file = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise/TRAIN/DR1/FSJK1/SI696_ey_17809_19676_neurogram_ansd_with_noise.mat';
% Add a second file to examine
test_file = '/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise/TEST/[some_directory]/[some_file]_with_noise_default.mat';

% Add this at the end of your script
fprintf('\nExamining test file: %s\n', test_file);
% [copy the same examination code as for corrupt_file]

fprintf('Examining file: %s\n', corrupt_file);

fprintf('\nExamining test file: %s\n', test_file);


% Try to get file information
file_info = dir(corrupt_file);
if isempty(file_info)
    fprintf('File does not exist or cannot be accessed\n');
else
    fprintf('File size: %d bytes\n', file_info.bytes);
    fprintf('Last modified: %s\n', file_info.date);
    fprintf('Permissions: %s\n', file_info.bytes);
end

% Try to read the file with low-level functions
try
    fprintf('\nAttempting to open file with low-level functions...\n');
    fid = fopen(corrupt_file, 'r');
    if fid == -1
        fprintf('Failed to open file with fopen\n');
    else
        % Read header bytes
        header = fread(fid, 128, 'uint8');
        fprintf('First 128 bytes read: %d bytes\n', length(header));
        
        % Close file
        fclose(fid);
    end
catch err
    fprintf('Error during low-level read: %s\n', err.message);
end

% Try to load file contents
try
    fprintf('\nAttempting standard MAT file load...\n');
    data = load(corrupt_file);
    fprintf('File loaded successfully. Fields in the file:\n');
    fields = fieldnames(data);
    for i = 1:length(fields)
        fprintf('  %s\n', fields{i});
    end
catch err
    fprintf('Error loading file: %s\n', err.message);
end

% Try whos command without loading
try
    fprintf('\nAttempting to examine file structure with whos...\n');
    info = whos('-file', corrupt_file);
    fprintf('File structure information:\n');
    for i = 1:length(info)
        fprintf('  %s: %s, %d bytes\n', info(i).name, info(i).class, info(i).bytes);
    end
catch err
    fprintf('Error examining file structure: %s\n', err.message);
end

fprintf('\nExamination complete.\n');
