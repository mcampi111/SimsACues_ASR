function out = sig_tone(f, dur, fs, ph)
%sig_tone Generate a single sinusoid
%
%   Usage: out = sig_tone(f, dur, fs);
%          out = sig_tone(f, dur, fs, ph);
%          
%   Input parameters:
%     f     : Frequency (in Hz).
%     dur   : Duration (in seconds).
%     fs    : Sampling frequency (in Hz).
%     ph    : Optional starting phase of the sine (in degrees). 
%             Default: 0 degrees, i.e., a sine.
%
%   Output parameters:
%     out   : Output signal, i.e., the tone.
%
%   SIG_TONE(..) generates a tone consisting of a single sinusoid with the
%   frequency f, duration dur, and starting phase ph. 
%
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_tone.php


%   #Author: Piotr Majdak (2024): original implementation

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

if nargin < 4, ph=0; end

N = round(dur*fs);
dTH=2*pi*f/fs;
TH=ph:dTH:2*pi*N*f/fs-dTH+ph;
out=sin(TH)';
