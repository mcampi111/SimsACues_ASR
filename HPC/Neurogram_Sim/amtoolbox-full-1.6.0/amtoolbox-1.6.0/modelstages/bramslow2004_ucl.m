function E_UCL=bramslow2004_ucl(In_FrmSize, fs, TransFact, NoChan, Widen, AG_UCL,AGLoss, RET4153, AGFs_E, E_Beg, E_End, E_B)
%bramslow2004_ucl Excitation patterns at uncomfortable levels (UCLs)
%
%   Usage: E_UCL = bramslow2004_ucl(In_FrmSize, In_SampF, TransFact, NoChan, Widen, AG_UCL, AGLoss, RET4153, AGFs_E, E_Beg, E_End, E_B)
%
%   Input parameters:
%     In_FrmSize    : Input framesize (in samples).
%     fs            : Input sampling rate (in Hz).
%     TransFact     : String specifying the fixed frequency response equalization applied to the input spectrum 
%                     (after correcting for coupler response) before passing 
%                     it through the auditory filterbank: 
%
%                     - 'ZWICKA0': Zwicker a0 transmission factor. 
%
%                     - 'ISO100N': 100-phone equal-loudness contours. 
%
%                     - 'ISO100M': 100-phone equal-loudness contours, modified 
%                       be to flat below 1 kHz.  
%
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%     Widen         : Flag for filter widening dependent on level. If true, the filter will be widened. 
%     AG_UCL        : Audiogram with uncomfortable levels (UCLs) (in dB HL). 
%                     Specified at frequencies: [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500]
%     AGLoss        : Audiogram with the hearing loss (in dB HL). 
%                     Specified at the same frequencies as for AG_UCL.
%     RET4153       : SPL thresholds (in dB) as specified by ISO 389 on the ear simulator (B&K 4153) coupler. 
%                     Specified at the same frequencies as for AG_UCL.
%     AGFs_E        : Audiogram frequencies (in Cams, on the ERB scale).
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
% 
%   Output parameters:
%     E_UCL         : Excitation pattern (in dB) in ERB bands for the provided UCL.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_ucl.php


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


% Zero power spectrum
PowSpect(1:In_FrmSize) = 0.0;

E_Bin = E_Beg;
E_Step = 0;
for E_Index = 1:1:NoChan, E_Bin = E_Bin + E_Step;     
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);

      % Calculate UCL by piecewise linear interpolation in the E-domain----------
    UCL = bramslow2004_erbrateinterp(E_Bin, AG_UCL, AGFs_E, E_Beg, E_End);  

      % Find nearest bin---------------------------------------------------------
    f_kHz = erbrate2f(E_Bin)/1000;                             % Center frequency
    Bin = ((1000 * f_kHz * In_FrmSize / fs));
    Bin = round(Bin);
      % Use the power of the UCL tone--------------------------------------------
    BinValue = 10.^ (UCL / 10);
    PowSpect(Bin) = BinValue;                % Initialize power spectrum
end
  % Refer to free field by applying IEC303 coupler gain----------------------
PowSpect = bramslow2004_couplcorr(PowSpect, 'IEC303', In_FrmSize, fs);   % fixed
  % Equal loudness correction------------------------------------------------
PowSpect = bramslow2004_equloudn(PowSpect, TransFact, In_FrmSize, fs);   % fixed
  % For this calculation, no upward spread of masking, so filters are forced narrow, instead of using actual energy in ERBs--------------------
E_SPL(1:NoChan) = 20.0;
  % Output is to E_UCL-------------------------------------------------------
[~, E_UCL]= bramslow2004_roexfilt(PowSpect, E_SPL, In_FrmSize, fs, NoChan, Widen, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_B); 
  % E_UCL in dB
E_UCL= 10*log10(E_UCL);
