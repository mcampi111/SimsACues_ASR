%demo_lyon2024 Excitation patterns of the CARFAC v2 model LYON2024
%
%   This script generates a tone at the SPL of 40 dB and feeds it to the cascade of 
%   asymmetric resonators with fast-acting compression (CARFAC) model, version 2. The 
%   excitation pattern is formed by taking the RMS of the output channels.
%
%   Figure 1: The response at channel 16 to a 4-kHz tone at 40 dB SPL
%
%   Figure 2: The excitation pattern in response to a 4-kHz tone at 40 dB SPL
%
%   See also:  lyon2024
%
%   References:
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_lyon2024.php


%   #Author: Piotr Majdak (2024): Implementation based on demo_lyon2011.
%   #Author: Piotr Majdak (2024): Adaptation for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


  % Create the stimulus: a 100ms-long tone at 4 kHz and 40 dB SPL
fs = 22050; 
T = 0.1; % 100 ms duration
f = 4000; % 4 kHz 
CFind = 16; % corresponds to roughly 4 kHz
SPL = 40; % SPL in dB re 20 microPa

sig = scaletodbspl(sig_tone(f, T, fs),SPL);
sig = fade(sig, 0.01, fs); % ramp the signal for 10 ms to minimize the spectral splatter effect.

  % Feed the signal into the model
CF_default = lyon2024_design(1, fs); % The defauls parameter designs are here
CF_struct = lyon2024_init(CF_default); % This initializes all the states for the CARFACT
[CF_default, decim_naps, naps, BM] = lyon2024(sig, CF_struct);

  % Plot the output at the channel corresponding to CF of 4 kHz
figure;
plot(0:(1/fs):(T-1/fs),BM(:,CFind));
title('Response at channel 16 (CF=4kHz) to a 4-kHz tone');
xlabel('Time [s]');
ylabel('Amplitude');
  % Plot the excitation pattern (Assumption: The channels are not distorted).
Fr=zeros(1,CF_struct.n_ch);
  % calculate the RMS of the output (steady state) for all channels
for i=1: CF_struct.n_ch
    Fr(i)=sqrt(2).*rms(BM(floor(length(BM(:,i))/2):end,i));
end
norm_Fr=Fr./max(Fr);
figure
plot(CF_struct.pole_freqs, db(norm_Fr));
xlabel('Center frequency (in Hz)');
ylabel('Normalized RMS energy');
title('The excitation pattern in response to 4-kHz tone at 40 dB SPL');




