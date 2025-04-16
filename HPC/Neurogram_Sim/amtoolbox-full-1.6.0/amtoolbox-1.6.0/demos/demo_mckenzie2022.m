% demo_mckenzie2022 Demo for the model of colouration between binaural signals
%
%   This is a demonstration of MCKENZIE2022, a model predicting the 
%   coloration between two binaural signals in terms of the perceptual 
%   binaural coloration (PBC) scores. The demonstration compares various 
%   binaural Ambisonic renderers with and without diffuse-field equalisation
%   of the HRTFs as used in McKenzie et al. (2018). It also shows how to 
%   plot the PBC scores using PLOT_MCKENZIE2022. 
%
%   Figure 1: PBC scores calculated based on signals from McKenzie et al. (2018) for various Ambisonic orders (OAs) and with and without diffuse-field equalization (DFE).
%
%   Figure 2: PBC dataset normalisation; marker colours get lighter with iterations (see Fig. 2 of McKenzie et al., 2022)
%
%   Figure 3: PBC scores calculated calculated from frequency-domain data
%
%
%
%   References:
%     T. McKenzie, D. T. Murphy, and G. Kearney. Diffuse-field equalisation
%     of binaural ambisonic rendering. Applied Sciences, 8(10), 2018.
%     [1]http ]
%     
%     T. McKenzie, C. Armstrong, L. Ward, D. Murphy, and G. Kearney.
%     Predicting the colouration between binaural signals. Appl. Sci.,
%     12(2441), 2022.
%     
%     References
%     
%     1. https://www.mdpi.com/2076-3417/8/10/1956
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_mckenzie2022.php


%   #Requirements: MATLAB M-Stats M-Curvefit
%   #Author: Thomas McKenzie (2022): initial implementation
%   #Author: Cal Armstrong (2022): initial implementation
%   #Author: Lauren Ward (2022): initial implementation
%   #Author: Damian Murphy (2022): initial implementation
%   #Author: Gavin Kearney (2022): initial implementation
%   #Author: Piotr Majdak (2023): documentation and structure adaptations
%   #Author: Michael Mihocic (2024): catching if Octave is used, and if curve fitting toolbox is not available -> otherwise returning warning

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

if isoctave
    warning([mfilename ' is not supported in Octave.']);
    return;
end

if exist('fit','file') == 0
    warning([mfilename ' requires Matlab Curve-Fitting Toolbox.']);
    return;
end

%% Read in listening test stimuli from McKenzie 2018 paper.
data = amt_load('mckenzie2022', 'sig_mckenzie2018.mat');
% data = load('sig_mckenzie2022.mat');

fs = data.fs;
rsH = data.rsH;
testDirections = data.testDirections;
tsA1 = data.tsA1;
tsA3 = data.tsA3;
tsA5 = data.tsA5;
tsD1 = data.tsD1;
tsD3 = data.tsD3;
tsD5 = data.tsD5;
% combine stimuli into one matrix
ts = cat(3,tsA1,tsA3,tsA5,tsD1,tsD3,tsD5);
rs = cat(3,rsH,rsH,rsH,rsH,rsH,rsH);
tsP = permute(ts,[1 3 2]);
rsP = permute(rs,[1 3 2]);

%% Run spectral difference calculation
%- simple example

% Parameters
domFlag = 0; % specify that inputs are time-domain signals
freqRange = [20 20000]; % calculate spectral difference between 20Hz and 20kHz
nfft = length(rs(:,1,1)); % fft window size same as signal length
f = struct; 
f.fs = fs;f.nfft = nfft;f.minFreq = freqRange(1); f.maxFreq = freqRange(2);
datasetNormalisation = 0; % blank vector for using iterative dataset normalisation. if an int, then that fixes the dataset normalisation in dB. Thus for no normalisation, set to 0.

% Calculate perceptual spectral difference
[~,PSpecDiff] = mckenzie2022(tsP,rsP,domFlag,f,datasetNormalisation);
PSpecDiff = squeeze(PSpecDiff);

% get single values of spectral difference for all stimuli
PavgSpecDiffS = mean(PSpecDiff,2);

% plot values
spectralDifference=PavgSpecDiffS;

maxValue = max(spectralDifference);
minValue = min(spectralDifference);
figure('position',[100,100,1200 400]);
titles={'1OA no DFE','3OA no DFE','5OA no DFE','1OA with DFE','3OA no DFE','5OA no DFE'};
for i = 1:length(spectralDifference)/length(testDirections)
    subplot(2,3,i)
    plot_mckenzie2022(spectralDifference((i-1)*length(testDirections)+1:i*(length(testDirections))),testDirections);
    averagePBCvalue = mean(spectralDifference((i-1)*length(testDirections)+1:i*(length(testDirections))));
    title(strcat([titles{i} '. Mean PBC=',num2str(averagePBCvalue),' sones']));    
    caxis([minValue,maxValue]);
    xlim([0 180]); % as this data is only in a hemisphere, constrain axis limits
end


%% Run spectral difference calculation
%- with normalisation, alternative frequency range, pre-model FFT calculation

% Parameters
domFlag = 2; % specify that inputs are frequency-domain signals in dB
freqRange = [1000 10000]; % this time for a 1kHz - 10kHz frequency range
nfft = length(rs(:,1,1));

% Take FFT of matrices
fft_matrix_input = fft(tsP, nfft); % Get Fast Fourier transform

% Compute freq bins for x-axis limits
fr_low = round(freqRange(1)*nfft/fs);
fr_high = round(freqRange(2)*nfft/fs);

% Get absolute values for frequency bins
fft_abs_matrix_input = abs(fft_matrix_input(fr_low:fr_high,:,:));

% Get values in dB
tsF = 20*log10(fft_abs_matrix_input);

% Take FFT of matrices
fft_matrix_input = fft(rsP, nfft); % Get Fast Fourier transform

% Compute freq bins for x-axis limits
fr_low = round(freqRange(1)*nfft/fs);
fr_high = round(freqRange(2)*nfft/fs);

% Get absolute values for frequency bins
fft_abs_matrix_input = abs(fft_matrix_input(fr_low:fr_high,:,:));

% Get values in dB
rsF = 20*log10(fft_abs_matrix_input);

% Frequency vector for plotting
f = 0:fs/nfft:fs-(fs/nfft);
f = f(fr_low:fr_high);


%--------------------------------------------------------------------------


datasetNormalisation = []; % blank vector for using iterative dataset normalisation. if an int, then that fixes the dataset normalisation in dB. Thus for no normalisation, set to 0.
w = 1; % for sample weighting. If input signals correspond to irregularly spaced points on a sphere, such as a gaussian quadrature, w could be a vector of solid angle weights, which is then used in the spectral difference calculation.
normalisationPlotFlag = 1; % show dataset normalisation curve
normalisationResolution = 0.001; % choose resolution of dataset normalisation - smaller number for finer resolution.

% Calculate perceptual spectral difference
[~,PSpecDiff] = mckenzie2022(tsF,rsF,domFlag,f,datasetNormalisation,w,normalisationPlotFlag,normalisationResolution);
PSpecDiff = squeeze(PSpecDiff);

% get single values of spectral difference for all stimuli
PavgSpecDiffS = mean(PSpecDiff,2);

% plot values
spectralDifference=PavgSpecDiffS;

maxValue = max(spectralDifference);
minValue = min(spectralDifference);
figure('position',[100,100,1200 400]);
titles={'1OA no DFE','3OA no DFE','5OA no DFE','1OA with DFE','3OA no DFE','5OA no DFE'};
for i = 1:length(spectralDifference)/length(testDirections)
    subplot(2,3,i)
    plot_mckenzie2022(spectralDifference((i-1)*length(testDirections)+1:i*(length(testDirections))),testDirections);
    averagePBCvalue = mean(spectralDifference((i-1)*length(testDirections)+1:i*(length(testDirections))));
    title(strcat([titles{i} '. Mean PBC=',num2str(averagePBCvalue),' sones']));    
    caxis([minValue,maxValue]);
    xlim([0 180]); % as this data is only in a hemisphere, constrain axis limits
end


