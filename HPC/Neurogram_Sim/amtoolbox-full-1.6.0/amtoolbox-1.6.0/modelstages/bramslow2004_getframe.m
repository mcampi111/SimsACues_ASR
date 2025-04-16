function [In_Buffer, In_NoSamps, RMS_sample] = bramslow2004_getframe(y, In_FrmSize, NoFrames, Cal_RMS, UserRMS, cal_dB_SPL)
%bramslow2004_getframe Prepares a signal for BRAMSLOW2004
%
%   Usage: [In_Buffer, In_NoSamps, RMS_sample]=bramslow2004_getframe(y, In_FrmSize, NoFrames, Cal_RMS, UserRMS, cal_dB_SPL)
%
%   Input parameters:
%     y         : Input signal in the time domain.
%     In_FrmSize: Targetted frame size (in samples).
%     NoFrames  : Targetted number of frames. 
%     Cal_RMS   : Flag. If 0, UserRMS is used for scaling. If 1, the actual RMS of the signal is used.
%     UserRMS   : User RMS of input signal.
%     cal_dB_SPL: SPL of the input signal y at full scale, i.e., amplitude of +-1, i.e., 0 dB FS. 
%
%   Output parameters:
%     In_Buffer  : Matrix with frames of the input signal (in Pa). Size: (*In_FrmSize x NoFrames*). 
%     In_NoSamps : Length (in samples) of the input signal y.
%     RMS_sample : RMS of input signal y (i.e., before the scaling). 
%
%   BRAMSLOW2004_GETFRAME(..) split input signal into a matrix of frames and scales to dB SPL
%   as a preparation for further processing by BRAMSLOW2004.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_getframe.php


%   #Author: Lars Bramslow (1993): Original C code
%   #Author: Graham Naylor (1994): Updates to model
%   #Author: Tayyib Arshad (2007): Ported to Matlab
%   #Author: Lars Bramslow (2024): Integration into AMT

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%   Set RMS
if Cal_RMS == true
    %    RMS = sqrt(mean(y_refscaled.^2));
    RMS_sample = std(y);            % Calculated excl DC and re square at FS
    amt_disp(sprintf('     Auto RMS_sample calibration, RMS_sample = %7.1f, %5.1f dBFS (square)', RMS_sample, 20*log10(RMS_sample)));
else
    % OLD: User RMS_sample assume 16-bit scaling
    % LABW: NEW: User RMS is used as is (matlab .wav file is float)
    RMS_sample = UserRMS; % /32768;
end

% Scale to p/p0
db_re_fs_square = 20*log10(RMS_sample);
c = 10^((cal_dB_SPL - db_re_fs_square)/20);

%   Do it
y = c*y;

%    RMS = sqrt(mean(y_refscaled.^2));
%RMS_re_p0 = std(y);             % Calculated excl DC and re square at FS
%disp(sprintf('     Calibrated signal, RMS_sample = %7.1f, %5.1f dB SPL', RMS_re_p0, 20*log10(RMS_re_p0)));

%   Copy to buffer
a = 1;
% In_SampF = fs;
In_NoSamps = length(y);
In_Buffer = zeros(NoFrames, In_FrmSize);

for CurFrame = 1:1:NoFrames
    b = CurFrame * In_FrmSize;

    if b < In_NoSamps
        Samples = y(a:b);
        a = b+1;
        In_Buffer(CurFrame, :) = Samples;
    elseif b > In_NoSamps
        c=In_NoSamps-a;
        d=a+c;
        Samples = y(a:d);
        In_Buffer(CurFrame, :) = zeros(1,In_FrmSize);
        In_Buffer(CurFrame,1:length(Samples)) = Samples;
        return;
    end
end


