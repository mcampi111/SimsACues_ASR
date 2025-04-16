% Add the path to the AMT toolbox or your model directory
addpath('/Users/mcampi/Desktop/To_Marta/amtoolbox-full-1.6.0/amtoolbox-1.6.0');

% Initialize the AMT (if using AMT)
amt_start();

% Directory containing WAV files
inputDir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/trial_speaker';
files = dir(fullfile(inputDir, '*.wav'));

% Output directory to save neurograms
outputDir = '/Users/mcampi/Desktop/To_Marta/ANSD_Study/code/trial_neurograms_results';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%%
% Model parameters
center_frequencies = [250, 500, 1000, 2000, 4000, 8000];  % Example CFs
fsmod = 100e3;  % Model sampling rate (adjustable)

% Struct to hold neurogram data for later plotting
neurogram_data = struct();

%%
% First loop: Process each file and store neurogram data
wavFiles = dir(fullfile(inputDir, '*.wav'));
for i = 1:length(wavFiles)
    % Load the WAV file
    [audio, fs] = audioread(fullfile(inputDir, wavFiles(i).name));
    
    % Resample audio if needed
    if fs ~= fsmod
        audio = resample(audio, fsmod, fs);
        fs = fsmod;
    end

    % Define corresponding PHN file
    phnFilename = strrep(wavFiles(i).name, '.WAV', '.PHN');
    phnPath = fullfile(inputDir, phnFilename);
    
    % Check if the PHN file exists
    if exist(phnPath, 'file')
        % Open and read the PHN file
        fid = fopen(phnPath, 'r');
        phoneme_segments = textscan(fid, '%d %d %s');
        fclose(fid);
        
        % Extract start times, end times, and phonemes
        start_times = phoneme_segments{1};
        end_times = phoneme_segments{2};
        phonemes = phoneme_segments{3};
        
        % Store neurogram data for each phoneme
        neurogram_data(i).file_name = wavFiles(i).name;
        neurogram_data(i).phonemes = phonemes;
        neurogram_data(i).neurograms = cell(length(phonemes), 1);
        neurogram_data(i).save_paths = cell(length(phonemes), 1);
        
        for j = 1:length(phonemes)
            % Extract segment for this phoneme
            start_idx = start_times(j) + 1;  % Adjust for MATLAB indexing
            end_idx = end_times(j) + 1;
            phoneme_audio = audio(start_idx:end_idx);
            
            % Generate neurogram data for the phoneme segment
            [r_mean, ~, ~, ~, ~, ~, output] = zilany2014(phoneme_audio, fs, center_frequencies, ...
                'fiberType', 3, 'nrep', 10, 'cohc', 1.0, 'cihc', 1.0);
            
            % Store neurogram data in the structure
            neurogram_data(i).neurograms{j} = r_mean;
            % Define and store the save path for this neurogram
            neurogram_data(i).save_paths{j} = fullfile(outputDir, [wavFiles(i).name, '_', phonemes{j}, '_neurogram.mat']);
        end
    else
        fprintf('Warning: PHN file %s not found.\n', phnFilename);
    end
end


%%

% Second loop: Save each neurogram data as a .mat file
for i = 1:length(neurogram_data)
    % Retrieve file name, phonemes, and save paths
    phonemes = neurogram_data(i).phonemes;
    save_paths = neurogram_data(i).save_paths;
    
    % Iterate over each phoneme neurogram
    for j = 1:length(phonemes)
        r_mean = neurogram_data(i).neurograms{j};
        
        % Save neurogram data in a .mat file using the stored save path
        save(save_paths{j}, 'r_mean', 'center_frequencies');  % Save with metadata if needed
    end
end



%%

% Specify the speaker name to filter (replace with the desired speaker file name)
speaker_name = 'SA1.WAV';

% Loop through neurogram data to find the specified speaker
for i = 1:length(neurogram_data)
    % Check if the current file matches the specified speaker name
    if strcmp(neurogram_data(i).file_name, speaker_name)
        % Retrieve phonemes and save paths for the selected speaker
        phonemes = neurogram_data(i).phonemes;
        save_paths = neurogram_data(i).save_paths;
        
        % Set up a figure with subplots
        num_phonemes = length(phonemes);
        figure;
        set(gcf, 'Position', [100, 100, 1200, 800]);  % Adjust figure size if needed
        tiledlayout('flow');  % Automatically arrange subplots

        % Iterate over each phoneme neurogram and add it as a subplot
        for j = 1:num_phonemes
            % Load the neurogram data from the saved .mat file
            mat_data = load(save_paths{j});
            r_mean = mat_data.r_mean;
            center_frequencies = mat_data.center_frequencies;
            
            % Create a subplot for each phoneme
            nexttile;
            imagesc(r_mean');
            axis xy;
            colormap('hot');
            colorbar;
            title(['Phoneme: ', phonemes{j}]);
            xlabel('Time (samples)');
            ylabel('Frequency (Hz)');
            set(gca, 'YTick', 1:length(center_frequencies));
            set(gca, 'YTickLabel', center_frequencies);
        end
        
        % Add a main title to the figure
        sgtitle(['Neurograms for Speaker: ', speaker_name]);
    end
end

%%