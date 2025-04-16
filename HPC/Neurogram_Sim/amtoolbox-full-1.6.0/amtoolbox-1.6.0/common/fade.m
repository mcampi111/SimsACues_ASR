function [y, window] = fade(signal,rise_time,fs)
%fade Apply fade in and fade out to a signal
%
%   Usage: y = fade(signal,rise_time,fs);
%          [y, window] = fade(signal,rise_time,fs);
%
%   Input parameters:
%     signal    : Input signal. Size: (*time x channels*).
%     rise_time : Fading time (in s), applied each to beginning
%                 and the end of the signal.
%     fs        : Sampling frequency (in Hz).
%
%   Output parameters:
%     y      : Output signal. Size: (*time x channels*).
%     window : Column vector with the window used to create the fading.
%
%   FADE(..) imposes a cosine-like fade-in
%   and fade-out to the begining and end of a signal, respectively.
%
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/fade.php


%   #Author: Clara Hollomey (2021): original implementation
%   #Author: Piotr Majdak (2024): reimplementation based on cosine_fade_window from sig_marquardt2009

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

n_ramp = round(rise_time * fs);
n_signal = size(signal,1);

window = ones(1, n_signal);
flank = 0.5 * (1 + cos(pi / n_ramp * (-n_ramp:-1)));
window(1:n_ramp) = flank;
window(end-n_ramp+1:end) = fliplr(flank);
window = window';
y = signal.*window; 

