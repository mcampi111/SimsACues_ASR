function plot_felsheim2024(stim, dists, fs, num_samples)
%plot_felsheim2024 Visualizes the output of the aLIFP model
%   
%   Usage: plot_felsheim2024(stim, dists, fs);
%          plot_felsheim2024(stim, dists, fs, num_samples);
% 
%   Input parameters:
%       stim:         Vector describing the electrical pulses (in mA) as input to the 
%                     aLIFP model, FELSHEIM2024.
%       dists:        Structure array describing the spike distributions as returned by the 
%                     aLIFP model, FELSHEIM2024.
%       fs:           Samping frequency of stim, used to sample the distributions.
%       num_samples:  Optional number of samples to be drawn from dists.
%                     Each entry in dists is sampled separately, thus,                                   
%                     these samples are only meaningfull for a large num_samples and  
%                     the interspike intervals are not reproduced. Default: 0 (meaning: all). 
% 
%   plot_felsheim202(..) plots the electrical pulses (in mA) and the response probabilities
%   as modeled by the aLIFP model, FELSHEIM2024. 
%
%   plot_felsheim202(.., num_samples) plots additionally the post-stimulus histogram, i.e., 
%   the histogram of spikes obtained by sampling the distributions num_samples times. The 
%   bin width of the histogram is 0.01 ms. 
%   
% 
%   See also: felsheim2024 demo_felsheim2024 exp_felsheim2024 
%             felsheim2024_sampledistribution felsheim2024_spikeprobability
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/plot/plot_felsheim2024.php

 
%   #Author: Rebecca Felsheim (2024): Original implemenation.
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.
%   #Author: Michael Mihocic (2024): Adaptations for Octave.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

if nargin < 4
    num_samples = 0;
end

off = round(1e-3 * fs);
max_time = length(stim) + off;

stim = [stim; zeros(off, 1)];


fig = figure("DefaultAxesFontSize", 12);

if num_samples > 0
    if ~isoctave; fig.Position = [0 0 1000, 1000]; end
    subplot(3,1,1); %tiledlayout(3,1, 'Padding', 'tight');  % use this when on Matlab 2019b or later
else
    if ~isoctave; fig.Position = [0 0 1000, 700]; end
    subplot(2,1,1); %tiledlayout(2,1, 'Padding', 'tight');  % use this when on Matlab 2019b or later
end

%nexttile % use this when on Matlab 2019b or later
t = (1:max_time) * 1e3 / fs;
plot(t, stim * 1e3, 'k', 'linewidth', 3)
hold on;
xlim([0, max_time * 1e-3])
ylabel("Current (in mA)")
xlabel("Time (in ms)")

title("Input")

%nexttile  % use this when on Matlab 2019b or later
if num_samples > 0
    subplot(3,1,2); %tiledlayout(3,1, 'Padding', 'tight');  % use this when on Matlab 2019b or later
else
    subplot(2,1,2); %tiledlayout(2,1, 'Padding', 'tight'); % use this when on Matlab 2019b or later
end

values = felsheim2024_spikeprobability(dists, max_time/fs);

plot((1:length(values)) * 1e-3, values, 'k', 'linewidth', 3);
hold on;

xlim([0, max_time * 1e-3]);

title("Output")

xlabel("Time (ms)")
ylabel(sprintf("Instantaneous\nspike probability"))


if num_samples > 0
    %nexttile
    subplot(3,1,3);
    samples = felsheim2024_sampledistribution(dists, num_samples);

    if isoctave
        bin_width = 1e-2;
        edges = min(samples * 1e3):bin_width:max(samples * 1e3);
        [counts, bin_centers] = hist(samples * 1e3, edges);
        bar(bin_centers, counts, 'FaceColor', 'k'); % 'k' is short for black
    else
        histogram(samples * 1e3, 'BinWidth', 1e-2, 'FaceColor','black');
    end

    
    hold on;

    xlim([0, max_time * 1e-3])

    title("Sampled output")
    xlabel("Time (ms)")
    ylabel("Number of spikes")
end



