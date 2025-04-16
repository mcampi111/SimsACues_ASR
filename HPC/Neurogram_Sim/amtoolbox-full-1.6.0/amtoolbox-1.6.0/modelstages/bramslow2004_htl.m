function [E_R, E_TQ, HTLL, E_E]=bramslow2004_htl(In_FrmSize, In_SampF, TransFact, Widen, AGLoss, RET4153, AGFs_E, NoChan, E_Beg, E_End, E_B)
%bramslow2004_htl Excitation pattern and hearing threshold levels considering an audiogram in free field
%
%   Usage: [E_R, E_TQ] = bramslow2004_htl(In_FrmSize, In_SampF, TransFact, Widen, AGLoss, RET4153, AGFs_E, NoChan, E_Beg, E_End);
%          [E_R, E_TQ] = bramslow2004_htl(..);
%
%   Input parameters:
%     In_FrmSize    : Input framesize (in samples).
%     In_SampF      : Input sampling rate (in Hz).
%     TransFact     : String specifying the fixed frequency response equalization applied to 
%                     the input spectrum (after correcting for coupler response) before 
%                     passing it through the auditory filterbank: 
%
%                     - 'ZWICKA0': Zwicker a0 transmission factor. 
%                     - 'ISO100N': 100-phone equal-loudness contours. 
%                     - 'ISO100M': 100-phone equal-loudness contours, modified to 
%                       be flat below 1 kHz.  
%
%     Widen         : Flag for filter widening dependent on level. If true, the filter will be widened. 
%     AGLoss        : Audiogram (in dB HL) specified at frequencies [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500] Hz.
%     RET4153       : ISO 389 thresholds in dB SPL as measured on the ear-simulator (4153) coupler. Specified at the same frequencies as for AGLoss.
%     AGFs_E        : Audiogram frequencies on the ERB scale (in Cams).
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
% 
%   Output parameters:
%     E_R           : Excitation pattern (in dB) in ERB bands for the audiogram.
%     E_TQ          : Power of the excitation (in dB) in ERB bands. 
%     HTLL          : Hearing threshold levels interpolated along the ERB scale to obtain SPL (in dB) of the 4152 coupler. Not used in the current model. 
%
%   See also other parameters as in arg_bramslow2004.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_htl.php


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

E_Bin = E_Beg;
E_Step = 0;

E_TQ = zeros(NoChan, 1); 
E_E = zeros(NoChan, 1); % Excitation in E bands for HTL, rectangular filter, Not used in current model.
E_R = zeros(NoChan, 1); 

for E_Index = 1:1:NoChan, E_Bin = E_Bin + E_Step;
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);

    PowSpect(1:In_FrmSize) = 0.0;

      % Calculate hearing loss, by piecevise linear interpolation in the ERB scale to get dB SPL in 4152 coupler----------------------------
    HTLL = bramslow2004_erbrateinterp(E_Bin, AGLoss, AGFs_E, E_Beg, E_End); % Hearing loss, by piecevise linear interpolation in the E-domain to get dB SPL in 4152 coupler. Not used in current model.
      % Find nearest bin---------------------------------------------------------
    f_kHz = erbrate2f (E_Bin)/1000;                             % Center frequency
    Bin = ((1000 * f_kHz * In_FrmSize /In_SampF));
    Bin = round(Bin);
      % Use the power of the threshold tone in that bin s------------------------
    BinValue = 10.^(HTLL / 10.);
    PowSpect(Bin) = BinValue;                % Initialize power spectrum

      % Refer to free field by applying IEC303 coupler gain----------------------
    PowSpect = bramslow2004_couplcorr(PowSpect, 'IEC303',In_FrmSize,In_SampF);
      % Equal loudness correction------------------------------------------------
    PowSpect = bramslow2004_equloudn(PowSpect, TransFact, In_FrmSize, In_SampF);
    E_SPL = bramslow2004_erbenergy( PowSpect, NoChan, In_FrmSize, In_SampF, Widen, AGLoss, RET4153, AGFs_E,  E_Beg, E_End); 
      % Output is to E_TQ--------------------------------------------------------
    [RoexFilt, E_TTemp]= bramslow2004_roexfilt(PowSpect, E_SPL, In_FrmSize, In_SampF, NoChan, Widen, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_B);
    E_TTemp(NoChan) = sum(E_TTemp);
    E_TQ(E_Index) = E_TTemp(NoChan);  % enter total excitation as value
    E_E(E_Index) = E_SPL(E_Index);
    E_R(E_Index) = 10.0 * log10(E_TQ(E_Index));
end
