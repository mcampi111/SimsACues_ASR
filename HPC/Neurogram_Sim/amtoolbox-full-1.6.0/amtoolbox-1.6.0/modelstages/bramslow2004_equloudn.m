function [PowSpect1]= bramslow2004_equloudn(PowSpect,TransFact,In_FrmSize,In_SampF)
%bramslow2004_equloudn Correct the power spectrum for equal loudness contours
%
%   Usage:  PowSpect = bramslow2004_equloudn(PowSpect, TransFact, In_FrmSize, In_SampF)
%
%   Input parameters:
%     PowSpect      : Row vector with the power spectrum. Size: In_FrmSize/2.
%     TransFact     : Specifies the fixed frequency response equalization applied to the input 
%                     spectrum (after correcting for coupler response) before passing it through
%                     the auditory filterbank. It can be one of the following: 
%
%                     - 'ZWICKA0': a0 transmission factor as described by Zwicker & Fastl (1999).
%
%                     - 'ISO100N': 100-phone equal-loudness contours from ISO 226, see also Glasberg
%                       and Moore (1990).
%
%                     - 'ISO100M': As 'ISO100N' but flat below 1 kHz, see also Glasberg
%                       and Moore (1990).
%
%     In_FrmSize    : Frame size of the original time frame.
%     In_SampF      : Input sampling rate (in Hz).
% 
%   Output parameters:
%     PowSpect      : Row vector with the corrected power spectrum. Size: In_FrmSize/2.
%
%   See also: demo_bramslow2004 exp_bramslow2004 bramslow2004
%
%   References:
%     L. Bramsløw Nielsen. An Auditory Model with Hearing Loss. Technical
%     report, Eriksholm Research Centre, Snekkersten, 1993.
%     
%     G. Naylor. The AUDMOD auditory model: A critique and revisions.
%     Technical report, Eriksholm Research Centre, Snekkersten, 1994.
%     
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%     L. Bramsløw. An auditory loudness model with hearing loss. In
%     Baltic-Nordic Acoustics Meeting, pages 318--323, 2024.
%     
%     B. R. Glasberg and B. Moore. Derivation of auditory filter shapes from
%     notched-noise data. Hearing Research, 47(1-2):103--138, 1990.
%     
%     E. Zwicker and H. Fastl. Psychoacoustics: Facts and models, volume 254.
%     Springer Berlin, 1999.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_equloudn.php



%   #StatusDoc: 
%   #StatusCode: 
%   #Verification: Unknown
%   #Requirements: M-Signal
%   #Author: Lars Bramslow (1993): Original C code
%   #Author: Graham Naylor (1994): Updates to model
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


FirstTime = true;                       % Flag - reset after first call

if (FirstTime)
    Fixed_Eq = zeros(In_FrmSize/2, 1);
    
    switch (TransFact)                % Select transmission factor
        case {'ZWICKA0'}				    % Zwicker's a0 factor
            a0Points = 27;
            a0Gain = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 2.5 5.0 6.5 6.0 3.5 -1.0 -4.0 -7.5 -20.0];
            a0Freq = [31.5 40 50 63 80 100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 10000 12500];
            
            Freq = a0Freq;
            Gain = a0Gain;
            Points = a0Points;
            
        case {'ISO100N'}                  % ELC100 from ISO 226
            ELC100Points = 27;
            ELC100Gain = [-16.6 -12.6 -10.1 -7.9 -5.6 -3.6 -1.8 -0.1 1.3 2.2 2.8 2.7 2.6 1.9 1.0	0.0	0.9	2.3 5.1	8.5 11.2 11.5 7.8 0.1 -6.6 -13.0 -20.0];
            ELC100Freq = [31.5 40 50 63 80 100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 10000 12500];
            
            Freq = ELC100Freq;
            Gain = ELC100Gain;
            Points = ELC100Points;
            
        case {'ISO100M'}                  % ELC100, but flat below 1 kHz
            ELC100MPoints = 27;
            ELC100MGain = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.9 2.3 5.1 8.5 11.2 11.5 7.8 0.1 -6.6 -13.0 -20.0];
            ELC100MFreq = [31.5 40 50 63 80 100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 10000 12500];
            
            Freq = ELC100MFreq;
            Gain = ELC100MGain;
            Points = ELC100MPoints;
            
        otherwise                         % Unknown factor - return error code
            error('Unknown Transmission factor %s', TransFact);
    end
    
    
    for Bin = 1:1:In_FrmSize/2
        F_Hz = (Bin * In_SampF)/In_FrmSize;
        Index = bramslow2004_locate (Freq, F_Hz);   % Locate nearest point below F_Hz
        if Index < 0
            Gain_dB = Gain(1);
        elseif Index >= Points - 1
            Gain_dB = Gain(Points - 1);
        else
            Gain_dB = Gain(Index) + (Gain(Index+1) - Gain(Index))* (F_Hz - Freq(Index)) / (Freq(Index+1) - Freq(Index));
        end
        
        % Save the correction in array for future use------------------------------
        Fixed_Eq(Bin) = 10^(Gain_dB/10.0);
    end
    
    
end

% Apply the correction-----------------------------------------------------
% for Bin = 1:1:In_FrmSize/2
%     PowSpect1(Bin) = PowSpect(Bin)*Fixed_Eq(Bin);
% end
[rows, cols] = size(PowSpect);
% Transpose if required
if rows == 1
    Fixed_Eq = Fixed_Eq';
end
PowSpect1(1:In_FrmSize/2) = PowSpect(1:In_FrmSize/2).*Fixed_Eq(1:In_FrmSize/2);

FirstTime = false;



