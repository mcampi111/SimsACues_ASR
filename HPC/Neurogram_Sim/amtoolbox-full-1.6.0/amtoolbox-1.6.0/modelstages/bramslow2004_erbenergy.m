function [E_SPL, ERB_Power]=bramslow2004_erbenergy(PowSpect, NoChan, In_FrmSize, In_SampF, Widen, AGLoss, RET4153, AGFs_E,  E_Beg, E_End)
%bramslow2004_erbenergy ERB SPL and total power of a power spectrum
%
%   Usage:
%       [ERB_SPL, ERB_Power]=bramslow2004_erbenergy(PowSpect, NoChan, In_FrmSize, In_SampF, Widen, AGLoss, RET4153, AGFs_E,  E_Beg, E_End)
%
%   Input parameters:
%     PowSpect      : Row vector with the power spectrum. Size: In_FrmSize/2.
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%     In_FrmSize    : Input frame size.
%     In_SampF      : Input sampling rate (in Hz).
%     Widen         : Flag for filter widening dependent on level. If true, the filter will be widened. 
%     AGLoss        : Audiogram (in dB HL) at specified frequencies: 
%                     [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500].
%     RET4153       : ISO 389 thresholds in dB as measured on ear-simulator (4153) coupler. 
%                     Specified at the same frequencies as for AGLoss.
%     AGFs_E        : Audiogram frequencies (in Cams, on the ERB scale).
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
% 
%   Output parameters:
%     ERB_SPL       : SPL (in dB) in each ERB band, restricted to be between 20 and 130 dB.
%     ERB_Power     : Total power (in dB) across all ERB bands. 
%
%   BRAMSLOW2004_ERBENERGY(..) calculates the energy (in dB SPL) in each EEB band. Further, it returns the total power of the signal (in dB). 
%
%   See also other parameters as in arg_bramslow2004.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_erbenergy.php


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


% Static variables are initialized at first call, or if widening changes---
FirstTime = true;                         % Flag - reset after first call
PrevWiden = true;                         % If widening changes, statics must be updated
MAX_THR = 70.0;                           % Max threshold, no extrapolation above this
ERB_INT = -0.288173;                      % Intersect
ERB_SLOPE = 0.0137025;                    % Slope
ERB_THR = 30.708;                         % Above this threshold (dB SPL (4153))
C1 = 24.673;
C2 = 4.368;
C3 = 2302.6/(C1 * C2);
MIN_SPL = 20;                             % Min SPL, for filter slopes
MAX_SPL = 130;                            % Max SPL..

% Initialize each E-band to some energy, -100 dB = 1e-10
E_Energy(1:NoChan) = 1e-10;

% Now, calculate the energy for each band----------------------------------
E = E_Beg;
E_Step=0;

for E_Index = 1:1:NoChan, E = E + E_Step;            
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);
    if (FirstTime || PrevWiden ~= Widen)

        % Calculate hearing loss, by interpolation in the E-domain-----------------
        if (Widen == true)
            HTL = bramslow2004_erbrateinterp(E, AGLoss, AGFs_E, E_Beg, E_End);    

            % If no widening, use 0 dB HL
        else

            HTL = bramslow2004_erbrateinterp(E, RET4153, AGFs_E, E_Beg, E_End);   

        end

        % Find upper and lower bins to sum-----------------------------------------
		F_kHz = erbrate2f(E)/1000;                          % Center frequency

        % Keep below max. threshold------------------------------------------------
        HTL = min(HTL, MAX_THR);

        % If below low threshold, use normal ERB-----------------------------------

        HTL = max(ERB_THR, HTL);
        ERB_Hz = (1000*((C2 * F_kHz + 1)/(C2 + 1))*(ERB_INT + ERB_SLOPE * HTL));

        % Calculate lower limit of the band----------------------------------------

        Temp1 = C2 * ERB_Hz / 1000.0;
        Temp2 = 10.^(2*E/C3);
        Temp3 = (Temp1 + 2)*(Temp1 + 2) - 4 * (Temp1 + 1 - Temp2);
        F_kHz = (sqrt(Temp3) - (Temp1 + 2))/(2*C2);
        F_Hz = F_kHz * 1000;
        FLow(E_Index) = F_Hz;
        BinL(E_Index) = ceil(FLow(E_Index)/(In_SampF/(In_FrmSize)));
        if BinL(E_Index) < 0
            BinL(E_Index) = 0;                 % Don't allow neg. Bins
        end

        % Calculate upper limit of the band----------------------------------------
        F_Hz = F_Hz + ERB_Hz;
        FHigh(E_Index) = F_Hz;
        BinU(E_Index) = floor(FHigh(E_Index)/(In_SampF/(In_FrmSize)));

        if BinU(E_Index) > In_FrmSize/2            % Don't go beyond fs/2
            BinU(E_Index) = In_FrmSize/2;
        else
            BinU(E_Index) = BinU(E_Index);
        end

    end

    % Sum up the bins----------------------------------------------------------

    for Bin = BinL(E_Index):1:BinU(E_Index)

        E_Energy(E_Index) = E_Energy(E_Index) + PowSpect(Bin);    

    end
end

Temp1 = 0;

% Calculate total Energy and convert energy to dB SPL----------------------

for E_Index =1:1:NoChan

    Temp1 =  Temp1 + E_Energy(E_Index);
    E_SPL(E_Index) = 10*log10(E_Energy(E_Index));

end

% Force energy to range----------------------------------------------------

for E_Index = 1:1:NoChan
    E_SPL(E_Index) = max(E_SPL(E_Index), MIN_SPL);
    E_SPL(E_Index) = min(E_SPL(E_Index), MAX_SPL);
end

ERB_Power = 10*log10(Temp1);

% Clear the first time flag------------------------------------------------
FirstTime = false;
PrevWiden = Widen;


