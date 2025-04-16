function [PowSpect]= bramslow2004_couplcorr(PowSpect, Coupler, In_FrmSize, In_SampF)
%bramslow2004_couplcorr Correct the power spectrum for recording coupler: Convert the SPL at coupler to the SPL in free field
%
%   Usage:  [PowSpect]= bramslow2004_couplcorr(PowSpect,Coupler,In_FrmSize, In_SampF)
%
%   Input parameters:
%     PowSpect      : Row vector with the power spectrum. Size: In_FrmSize/2.
%     Coupler       : String specifying the coupler: 
%                     
%                     - 'freefield': defines freefield as the coupler meaning
%                       that the input power spectrum will not be modified.
%               
%                     - 'diffusefield_shaw1985': Diffuse field response as described by Shaw and 
%                       Vaillancourt (1985) as well as by Naylor (1994).
%
%                     - 'IEC711_shaw1985': IEC711 open-ear response as described by Shaw and 
%                       Vaillancourt (1985).
%
%                     - 'IEC711_mehrgardt1977': IEC711 open-ear response as described by Mehrgardt
%                       and Mellert (1977).
%
%                     - 'IEC303': 6cc coupler correction as described by Bentler and Pavlovic (1992).
%
%     In_FrmSize    : Input framesize (in samples) of the original time frame.
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
%     E. A. G. Shaw and M. M. Vaillancourt. Transformation of sound-pressure
%     level from the free field to the eardrum presented in numerical form.
%     The Journal of the Acoustical Society of America, 78(3):1120--1123, sep
%     1985.
%     
%     S. Mehrgardt and V. Mellert. Transformation characteristics of the
%     external human ear. The Journal of the Acoustical Society of America,
%     61(6):1567--1576, jun 1977.
%     
%     R. A. Bentler and C. V. Pavlovic. Addendum to "Transfer Functions and
%     Correction Factors Used in Hearing Aid Evaluation and Research". Ear
%     and Hearing, 13(4):284--286, 1992.
%     
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%     L. Bramsløw. An auditory loudness model with hearing loss. In
%     Baltic-Nordic Acoustics Meeting, pages 318--323, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_couplcorr.php


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


FirstTime = true;
LastCoupler = '';

if (FirstTime || (LastCoupler ~= Coupler))

    switch (Coupler)                            % Select coupler

        case {'freefield'}				% Free field - no correction
            return;

        case {'IEC711_shaw1985'}	 			% IEC711 subtract Shaw's open ear respons

            ShawGain = [0.0 0.0 0.0 0.5 1.0 1.4 1.5 1.8 2.4 3.1 2.6 3.0 6.1 12.0 16.8 15.4 14.9 14.3 10.7 7.3 6.4 1.8 -1.7 8.5];
            ShawFreq = [100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3000 3150 4000 5000 6000 6300 8000 10000 12500];
            ShawPoints = length(ShawFreq);

            Freq = ShawFreq;
            Gain = ShawGain;
            Points = ShawPoints;


        case {'diffusefield_shaw1985'}	 			% DIFFFLD subtract Shaw's diffuse field response (GN addition 1994)

            KEMAR2DiffuseGain = [0.0 0.2 0.4 0.8 1.1 1.5 2.1 2.9 3.9 21.0 15.0 6.0 0.0];
            KEMAR2DiffuseFreq = [100 200 250 315 400 500 630 800 1000 3000 6500 9200 12000];
            KEMAR2DiffusePoints = length(KEMAR2DiffuseFreq);

            Freq = KEMAR2DiffuseFreq;
            Gain = KEMAR2DiffuseGain;
            Points = KEMAR2DiffusePoints;


        case {'IEC711_mehrgardt1977'}	 			% IEC711 subtract M&M's open ear response

            MMGain = [0.0 0.0 0.0 -0.5 0.5 1.5 1.0 1.0 2.0 3.0 0.0 1.0 9.0 12.0 15.0 17.5 16.5 11.0 7.0 4.0 -1.0 -12.0];
            MMFreq = [100 125 160 200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 10000 12500];
            MMPoints = length(MMFreq);

            Freq = MMFreq;
            Gain = MMGain;
            Points = MMPoints;


        case {'IEC303'}	 			% 6cc coupler correction

            IEC303Gain = [14.4 10.8 8.4 4.7 2.6 1.8 1.2 0.4 0.9 2.6 6.1 8.9 9.7 10.9 10.3 3.7 -7.6 -9.0 -5.0];
            IEC303Freq = [200 250 315 400 500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 10000 12500];
            IEC303Points = length(IEC303Freq);

            Freq = IEC303Freq;
            Gain = IEC303Gain;
            Points = IEC303Points;


        otherwise
            error('Unknown Coupler %s', Coupler)
    end

    % Calculate correction-----------------------------------------------------
    for Bin = 0:1:((In_FrmSize/2)-1)

        F_Hz = (Bin * In_SampF)/In_FrmSize;

        Index = bramslow2004_locate(Freq, F_Hz);  %Locate nearest point below F_Hz
        if Index < 1

            Gain_dB = Gain(1);

        elseif Index >= Points

            Gain_dB = Gain(Points);

        else

            Gain_dB = Gain(Index) + (Gain(Index+1) - Gain(Index)) * (F_Hz - Freq(Index)) / (Freq(Index+1) - Freq(Index));
        end

        % Save the correction in array for future use. Use -gain, to go from-------
        % coupler to free field----------------------------------------------------
        CoupCorr(Bin+1) = 10.^(-Gain_dB/10.0);
    end

    % Remember what coupler sent into the array--------------------------------
    LastCoupler = Coupler;
end

% Apply the correction-----------------------------------------------------

for Bin = 1:1:In_FrmSize/2
    powspect=PowSpect(Bin);                 % To control correct PowSpect
    PowSpect(Bin) = powspect * CoupCorr(Bin);
end

FirstTime = false;


