function [PowerSpect]=bramslow2004_powerspectrum(In_Buffer)
%bramslow2004_powerspectrum Calculate a windowed power spectrum
%
%   Usage: [PowerSpect]=bramslow2004_powerspectrum(In_Buffer)
%
%   Input parameters:
%     In_Buffer     : Vector with the signal in the time domain, must be of 2^N length.
% 
%   Output parameters:
%     PowerSpect    : Power spectrum (linear in amplitude).
%
%   BRAMSLOW2004_POWERSPECTRUM(..) applies a Hann window to the time signal
%   and then calculates the power spectrum. 
%    
%   
%   See also: demo_bramslow2004 exp_bramslow2004 bramslow2004
%
%   References:
%     L. Bramsløw Nielsen. An Auditory Model with Hearing Loss. Technical
%     report, Eriksholm Research Centre, Snekkersten, 1993.
%     
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%     L. Bramsløw. An auditory loudness model with hearing loss. In
%     Baltic-Nordic Acoustics Meeting, pages 318--323, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_powerspectrum.php


%   #StatusDoc: 
%   #StatusCode: 
%   #Verification: Unknown
%   #Requirements: M-Signal
%   #Author: Lars Bramslow (1993): Original C code
%   #Author: Tayyib Arshad (2007): Ported to Matlab
%   #Author: Lars Bramslow (2024): Integration into AMT
%   #Author: Piotr Majdak (2024): Integration for AMT 1.6.0

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

In_FrmSize = length(In_Buffer);                     % Number of samples

%   Window
window = hann(In_FrmSize);                          % The hann window is generated
windowscale = sum(window.^2)/In_FrmSize;            % The amount of power lost
Window_In_Buffer=In_Buffer.*window';                % The window is applied on the samples

%   Spectrum
spectrum=fft(Window_In_Buffer, In_FrmSize)/In_FrmSize;              % In_FrmSize is /2 because of the REAL fft in the c version
PowerSpect=2*abs(spectrum(2:((In_FrmSize/2)+1)).^2)/windowscale;    % Power spectum, compensated for window loss and the upper half of spectrum


