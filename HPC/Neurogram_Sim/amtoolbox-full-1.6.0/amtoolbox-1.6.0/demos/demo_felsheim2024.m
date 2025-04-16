%demo_felsheim2024 Demo of the adaptive leaky-integrate and firing probability (aLIFP) model
%
%   DEMO_FELSHEIM2024 demonstrates how to use the aLIFP model to 
%   predict the instantaneos spike probability over time 
%   of an electrically excited auditory nerve. And it shows how this distribution 
%   can be sampled. 
%
%   Figure 1: Three pulses
% 
%      *Top panel**: Input signal consisting of three biphasic pulses. 
%      *Center panel**: Modeled response probabilities illustrating how the 
%      number of Gaussian components in the distribution increases with each pulse. 
%      *Bottom panel**: Modeled post-stimulus histogram, i.e., the response 
%      distribution sampled 100 times. 
%
%   Figure 2: Pulse train
% 
%      As above, but for an unmodulated 1000-pps pulse train. 
%
%   Figure 3: Pulse train and modified model parameters
% 
%      Response to an unmodulated 1000-pps pulse train, calculated with a 
%      modified model parameters: Membrane resistance of 40 Ohm (instead of 
%      29 Ohm) and threshold standard deviation of 0.8 mV (instead of 0.43 mV). 
%
%   See also: felsheim2024 exp_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_felsheim2024.php


%   #Author: Rebecca C. Felsheim (2024): Original implementation. 
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


% phase length of the biphasic pulse
phaseL = 100e-6;

ipg = 30e-6;
fs = 1e6; % fixed sampling rate from the model parameters

pulse = [-1 * ones(round(phaseL * fs), 1); zeros(round(ipg * fs), 1); ones(round(phaseL * fs), 1)];

%% signal from the paper
signal = [zeros(100,1); pulse * .64e-3; zeros(1500, 1); pulse * .85e-3; zeros(1500, 1); pulse * .9e-3; zeros(100,1)];
spike_struct =  felsheim2024(signal, fs);

plot_felsheim2024(signal, spike_struct, fs, 100);


%% pulse train
signal = sig_pulsetrain(.025, 1000, pulse) * 0.78e-3;

spike_struct =  felsheim2024(signal, fs);

plot_felsheim2024(signal, spike_struct, fs, 100);


%% pulse train with modified model parameters and no sampling of the signal

spike_struct =  felsheim2024(signal, fs, 'membrane_resistance', 40, 'threshold_sigma', 8e-4);

plot_felsheim2024(signal, spike_struct, fs, 100);

