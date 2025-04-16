function [E_Vector, TotLoudn]= bramslow2004_specloudn(E_Vector, E_0, E_TQ, E_UCL,HTLL, NoChan, E_Beg, E_End, Binaural)
%bramslow2004_specloudn Specific and total loudness from an excitation pattern
%
%   Usage: [E_Vector, TotLoudn]= bramslow2004_specloudn(E_Vector, E_0, E_TQ, E_UCL,HTLL, NoChan, E_Beg, E_End, Binaural)
%
%   Input parameters:
%     E_Vector      : Excitation (in dB) per ERB band.
%     E_0           : Excitation (in dB) per ERB band at the SPL of 0 dB.
%     E_TQ          : Excitation (in dB) per ERB band at the hearing threshold (TQ).
%     E_UCL         : Excitation (in dB) per ERB band at the UCL.
%     HTLL          : Hearing threshold levels interpolated along the ERB scale to 
%                     obtain SPL (in dB) of the 4152 coupler.
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
%     Binaural      : Flag considering the type of listening. If true, binaural 
%                     listening is assumed. If false, monaural listening is assumed. 
%
%   Output parameters:
%     E_Vector      : Specific loudness (in sone) in the ERB bands. 
%     TotLoudn      : Total loudness (in sone) across all ERB bands.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_specloudn.php


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


TotLoudn = 0.0;         % Total loudness, N, for frame
s = 1.0;                % Ratio of pure-tone to internal noise at threshold
LOUD_EXP = 0.23;
MIN_UCLDIV = 0.01;      % Min UCL divisor, = a factor 100
MONTHR = 1.0;            % Correction for monaural threshold
BINTHR = 0.5;            % Correction for binaural threshold
BINLOUD = 1.0;           % Binaural loudness is normal
MONLOUD = 0.5;           % Monaural loudness is half

ERB_INT = -0.288173;     % Intersect
ERB_SLOPE = 0.0137025;   % Slope
ERB_THR = 30.708;        % Above this threshold (dB SPL (4153))

LOUD_MULT = 0.068;       % Loudness multiplication factor
% Zwicker & Fastl: 0.08, Glasberg & Moore:  0.084, Zwicker & Feldtkeller: 0.068
LOUD_EXP = 0.23;         % Loudness growth exponent
LOUD_ADJ = 1.00;         % Loudness adjustment factor to obtain
MAX_LOUD = 320;          % Max loudness, limited for integer files
EXCNORM = false;
LOUDNORM = true;
UCLMODEL = true;

E_Bin = E_Beg;
E_Step = 0;
for Chan = 1:1:NoChan, E_Bin = E_Bin + E_Step;
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);

    f_kHz = erbrate2f(E_Bin)/1000;                     % Center frequency
	
    % Find s according to Bild 39,4 in Zwicker & Feldtkeller-------------------
    if f_kHz < 0.32
        s = 0.65;
    else
        s = - 2 - 2.2*log10(f_kHz/ 0.32);              % In dB
        s = 10.^(s/10.0);
    end
    E_UCL(Chan)= 10.^(E_UCL(Chan)/10);
    % Calculate UCL term according to Eqn (16)---------------------------------
    UCL_Div = 1.0 - (E_Vector(Chan)/E_UCL(Chan)).^(1.0/LOUD_EXP);
    UCL_Div = max(UCL_Div, MIN_UCLDIV);         % Don't go below minimum

    % Initialize monaural/binaural corrections---------------------------------
    if Binaural == 1
        ThrCorr = BINTHR;
        LoudCorr = BINLOUD;
    else
        ThrCorr = MONTHR;
        LoudCorr = MONLOUD;
    end

    % Normalizing factor for widened critical bands (= ratio of width to normal)
    NormFact = (ERB_INT + ERB_SLOPE * ERB_THR)/(ERB_INT + ERB_SLOPE * max(HTLL(Chan), ERB_THR));
    NormFact_Vector(Chan) = NormFact;

    % Loudness growth as in Zwicker & Feldtkeller, eqn 52,17-------------------
    E_Vector(Chan) = LoudCorr * LOUD_ADJ * LOUD_MULT * (ThrCorr*E_TQ(Chan)./(s*E_0(Chan))).^(LOUD_EXP)*(((1-s) + (s*E_Vector(Chan))/(ThrCorr*E_TQ(Chan))).^ (LOUD_EXP) - 1);

    if LOUDNORM == true
        % Normalize loudness for widened critical bands----------------------------

        E_Vector(Chan) = E_Vector(Chan) * NormFact_Vector(Chan);		% linear factor
    end

    if UCLMODEL == true
        %Modify by UCL term-------------------------------------------------------

        E_Vector(Chan) = E_Vector(Chan) / UCL_Div;

    end
    % Avoid negative loudness and keep below max specific loudness-------------
    E_Vector(Chan) = max(0, E_Vector(Chan));
    E_Vector(Chan) = min(MAX_LOUD, E_Vector(Chan));

    % Calculate total loudness-------------------------------------------------
    TotLoudn = TotLoudn + E_Vector(Chan);

end


