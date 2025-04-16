function [E_0, E_0E, E_0R]=bramslow2004_exc0dbspl(In_FrmSize, In_SampF, TransFact, Widen, AGLoss, RET4153, AGFs_E, NoChan, E_Beg, E_End, E_B)
% bramslow2004_exc0dbspl Excitation patterns at an SPL of 0 dB in free field (to calibrate model)
%
%   Usage: E_0 = bramslow2004_exc0dbspl(In_FrmSize, In_SampF, TransFact, Widen, AGLoss, RET4153, AGFs_E, NoChan, E_Beg, E_End, E_B)
%
%   Input parameters:
%     In_FrmSize    : Input framesize (in samples).
%
%     In_SampF      : Input sampling rate (in Hz).
%
%     TransFact     : Specifies the fixed frequency response equalization applied to the input spectrum 
%                     (after correcting for coupler response) before passing it through the auditory filterbank.  
%                     The parameter choices are: 
%
%                     - 'ZWICKA0': Zwicker a0 transmission factor. 
%
%                     - 'ISO100N': 100-phone equal-loudness contours. 
%
%                     - 'ISO100M': 100-phone equal-loudness contours, modified to flat below 1 kHz.  
%
%     Widen         : Flag for filter widening dependent on level. If true, the filter will be widened. 
%
%     AGLoss        : Audiogram (in dB HL) Specified at frequencies 
%                     [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500] Hz.
%
%     RET4153       : ISO 389 thresholds (in dB) as measured on the ear-simulator (4153) coupler. 
%                     Specified at the same frequencies as for AGLoss.
%
%     AGFs_E        : Audiogram frequencies (in Cams, on the ERB scale).
%
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
%
%     E_B           : ERB rates (in Cams) of the individual bins in the frame.
%
%
%   Output parameters:
%     E_0           : Power of the excitation in ERB bands for 0 dB SPL, with potentially widened filter.
%
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_exc0dbspl.php


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
E_0 = zeros(NoChan, 1); 
E_0E = zeros(NoChan, 1); % Excitation in ERB-scale bands for 0 dB SPL, rectangular filter, minimum 20 dB SPL. Currently unused.
E_0R = zeros(NoChan, 1); % Excitation in ERB-scale bands for 0 dB SPL, possibly widened, dB. Currently unused.

for E_Index = 1:1:NoChan, E_Bin = E_Bin + E_Step;
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);
      % Zero power spectrum each time around
    PowSpect = zeros(In_FrmSize,1);

      % Find nearest bin---------------------------------------------------------
    f_Hz = erbrate2f(E_Bin);                               % Center frequency
    Bin = ((f_Hz * In_FrmSize / In_SampF));
    Bin = round(Bin);
      % 0 dB SPL = 1 in normalized spectra---------------------------------------
    BinValue = 1.0;
    PowSpect(Bin) = BinValue;                % Initialize power spectrum
      % Refers always to 0 dB SPL free field, so no coupler correction needed----
    PowSpect=bramslow2004_couplcorr(PowSpect,'freefield',In_FrmSize, In_SampF);

      % Pass through filterbank--------------------------------------------------
    PowSpect = bramslow2004_equloudn(PowSpect, TransFact, In_FrmSize, In_SampF);
    E_SPL = bramslow2004_erbenergy(PowSpect, NoChan, In_FrmSize, In_SampF, Widen, AGLoss, RET4153, AGFs_E,  E_Beg, E_End); 

    [RoexFilt, E_TTemp]= bramslow2004_roexfilt(PowSpect, E_SPL, In_FrmSize, In_SampF, NoChan, Widen, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_B);

    E_TTemp(NoChan) = sum(E_TTemp);
    E_0(E_Index) = E_TTemp(NoChan);  %	put total into cell of output array

    E_0E(E_Index) = E_SPL(E_Index);
    E_0R(E_Index) = 10.0 * log10(E_0(E_Index));
end

