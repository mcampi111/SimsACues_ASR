function [Roex_SPL, E_Vector, HTLL]=bramslow2004_roexfilt(PowSpect, E_SPL, In_FrmSize, In_SampF, NoChan, Widen, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin)
%bramslow2004_roexfilt Correct the power spectrum by the roex-filter shape considering signal level and hearing loss
%
%   Usage: [Roex_SPL, E_Vector, HTLL]=bramslow2004_roexfilt(PowSpect, E_SPL, In_FrmSize, In_SampF, NoChan, Widen, AGFs_E, AGLoss, RET4153, E_Beg, E_End, E_Bin)
%
%   Input parameters:
%     PowSpect      : Row vector with the power spectrum. Size: In_FrmSize/2.
%     E_SPL         : SPL (in dB) in each ERB, used to adjust the roex filter slopes.
%     In_FrmSize    : Input framesize (in samples).
%     In_SampF      : Input sampling rate (in Hz).
%     NoChan        : Number of output channels (equally distributed on the ERB scale).
%     Widen         : Flag for filter widening dependent on level. If true, the filter will be widened. 
%     AGFs_E        : Audiogram frequencies on ERB scale (in Cams).
%     AGLoss        : Audiogram (in dB HL) specified at frequencies [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500] Hz.
%     RET4153       : ISO 389 thresholds (in dB SPL) as measured on the ear-simulator (4153) coupler. 
%                     Specified at the same frequencies as for AGLoss.
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
%     E_Bin         : ERB rates (in Cams) of the individual bins in the frame.
% 
%   Output parameters:
%     Roex_SPL      : SPL (in dB) corrected by the roex-filterbank output.
%     E_Vector      : Power spectrum (in dB) corrected by the roex-filterbank output.
%     HTLL          : Hearing threshold levels (in dB) interpolated along the ERB scale to obtain SPL of the 4152 coupler.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_roexfilt.php


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


% Flag for first pass 
FirstTime = true;
PrevWiden = 'WIDEN';
C1=     24.673;
C2=     4.368;

PU_DEP_HL = true;
PL_DEP_HL = true;
PL_MOD2 = true;
MAX_THR = 100;
PU_THR = 36.8;
GMAX = 10;
PMIN = 3;
PL_INT2 = 30.16;
PL_SLO2 = -0.38;
PL_THR2 = 20;

f0_kHz = [30,1];
f0_Hz = [30,1];
pl_51 = [30,1];
pu_51 = [30,1];
HTLL = [30,1];
HTLU = [30,1];
BinL = [30,1];
BinU = [30,1];


% Initialize each E-band to some energy, -100 dB = 1e-10-------------------

E_Vector(1:NoChan) = 1e-10;

% Calculate constants right away-------------------------------------------
% If PL_DEP_HL is defined
%--------------------------------------------------------------------------
if (PL_DEP_HL~=true)
    if (FirstTime)
        p51_1k = 4.0 * 1000.0 / (C1 * (C2 + 1.0));
    end
end

% Now, calculate the energy for each band----------------------------------
E = E_Beg;
E_Step = 0;

for Filt_Index = 1:1:NoChan, E = E + E_Step;
    E_Step = (E_End - E_Beg)/(NoChan - 1.0);

    if FirstTime || strcmp(PrevWiden, Widen) == 0

        f0_kHz(Filt_Index) = erbrate2f(E)/1000;		
        f0_Hz(Filt_Index) = f0_kHz(Filt_Index) * 1000.0;

        if PU_DEP_HL ~= false
            Erb_Hz = f2erb(f0_Hz(Filt_Index));			
            pl_51(Filt_Index) = 4.0*f0_Hz(Filt_Index)/Erb_Hz;
            pu_51(Filt_Index) = pl_51(Filt_Index);
        end

        % Find hearing loss and force to range-------------------------------------
        if (Widen == true)
            HTLL(Filt_Index) = bramslow2004_erbrateinterp(E, AGLoss, AGFs_E, E_Beg, E_End);
        else
            HTLL(Filt_Index) = bramslow2004_erbrateinterp(E, RET4153, AGFs_E, E_Beg, E_End);
        end

        HTLL(Filt_Index) = min(HTLL(Filt_Index), MAX_THR);

        HTLU(Filt_Index) = HTLL(Filt_Index);

        HTLU(Filt_Index) = max(HTLU(Filt_Index), PU_THR);

        % Find bin above GMAX------------------------------------------------------
        f_Hz = (1 - GMAX)*f0_Hz(Filt_Index);
        BinL(Filt_Index) = ceil(f_Hz/(In_SampF/In_FrmSize));

        if BinL(Filt_Index) < 1
            BinL(Filt_Index) = 1;       % Don't allow bin-numbers under 1
        end

        % Find bin below GMAX -----------------------------------------------------
        f_Hz = (1 + GMAX)*f0_Hz(Filt_Index);
        BinU(Filt_Index) = floor(f_Hz/(In_SampF/In_FrmSize));  % compensation for bin starts at 1 not 0!


        BinU(Filt_Index) = min(BinU(Filt_Index), (In_FrmSize/2));   % Don't go beyond fs/2
    end
    % if FirstTime etc.

    Prev_ESPL_Index = 10000;   % Make sure this is out of range before loop

    % Sum up the bins----------------------------------------------------------

    for Bin = BinL(Filt_Index):1:BinU(Filt_Index)

        f_Hz = Bin*In_SampF/In_FrmSize;

        % Index is 0 for bins below E_Beg------------------------------------------
        ESPL_Index = (max(1, (E_Bin(Bin) - E_Beg)/E_Step ));
        % Don't go above NoChan either---------------------------------------------
        ESPL_Index = min(ESPL_Index, NoChan);
        if ESPL_Index == 0
            ESPL_Index = 1;
        end
        ESPL_Index= round(ESPL_Index);
        if ESPL_Index ~= Prev_ESPL_Index

            if 1
                if PL_DEP_HL
                    if (PL_MOD2~=true)
                        pl = (((C2 + 1)*f0_kHz(Filt_Index))/(C2*f0_kHz(Filt_Index) + 1))*((PL_INT1 + PL_SLO1*max(HTLL(Filt_Index),PL_THR1))- 0.380*(E_SPL(ESPL_Index) - 71.0));

                    else

                        pl = (((C2 + 1)*f0_kHz(Filt_Index))/(C2*f0_kHz(Filt_Index) + 1))*(PL_INT2 + PL_SLO2*(max(min(0,E_SPL(ESPL_Index) - 71.0),HTLL(Filt_Index)-PL_THR2)+PL_THR2));
                    end


                else


                    pl = pl_51(Filt_Index) - 0.380*(pl_51(Filt_Index)/p51_1k)*(E_SPL(ESPL_Index) - 51.0);
                end

                % Upper skirt doesn't change with level------------------------------------
                if PU_DEP_HL == false
                    pu = (((C2 + 1)*f0_kHz(Filt_Index))/(C2*f0_kHz(Filt_Index) + 1))*(PU_INT + PU_SLOPE*HTLU(Filt_Index));
                else
                    pu = pu_51(Filt_Index);
                end

            else
                pl = pl_51(Filt_Index) - 0.380*(E_SPL(ESPL_Index) - 51.0);
                pu = pu_51(Filt_Index) + 0.118*(E_SPL(ESPL_Index) - 51.0);
            end

            % Make sure pl and pu are valid--------------------------------------------
            pl = max(pl, PMIN);
            pu = max(pu, PMIN);
        end

        % if ESPL_Index ...--------------------------------------------------------
        % Remember index-----------------------------------------------------------

        Prev_ESPL_Index = ESPL_Index;

        g = (f_Hz - f0_Hz(Filt_Index))/f0_Hz(Filt_Index);

        if g < 0
            E_Vector(Filt_Index) = E_Vector(Filt_Index) + PowSpect(Bin) * (1-pl*g)*exp(pl*g);
        else
            E_Vector(Filt_Index) = E_Vector(Filt_Index) + PowSpect(Bin) * (1+pu*g)*exp(-pu*g);
        end
    end

end


Roex_SPL(NoChan) = 0.0;
for Filt_Index = 1:1:NoChan
    Roex_SPL(Filt_Index) = 10 * log10(E_Vector(Filt_Index));

end

% Don't initialize next time-----------------------------------------------
FirstTime = false;
PrevWiden = Widen;

