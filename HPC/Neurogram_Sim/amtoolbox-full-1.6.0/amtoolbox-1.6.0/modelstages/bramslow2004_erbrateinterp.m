function [HTL]=bramslow2004_erbrateinterp(E, Level, AGFs_E, E_Beg, E_End)
%bramslow2004_erbrateinterp Interpolate an audiogram in the ERB-rate domain
%
%   Usage: HTL = bramslow2004_erbrateinterp(E, Level, AGFs_E, E_Beg, E_End)
%
%   Input parameters:
%
%     E             : Targetted ERB rate for the interpolation.
%     Level         : Audiogram (or UCLs, in dB HL) to be interpolated.
%     AGFs_E        : Audiogram frequencies (in Cams, on the ERB scale).
%     E_Beg         : Lowest ERB rate considered (in Cams, typically 3 Cams).
%     E_End         : Highest ERB rate considered (in Cams, typically 32 Cams).
%
%   Output parameters:
%
%     HTL           : Interpolated hearing threshold level at ERB rate E.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_erbrateinterp.php


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


Points = length(Level);
E_Below = E_Beg;
E_Above = E_End;

% Find interval and slope--------------------------------------------------
Count = 1;
if E < AGFs_E(1)                        % Below audiogram frequencies
    
    HTL = Level(1);
    
elseif E > AGFs_E(Points)               % Above audiogram frequencies
    
    HTL = Level(Points);
    
    % We have to go look for it------------------------------------------------
    
else
    
    % Old code
    while E > AGFs_E(Count)
        Count=Count+1;
    end
    
    E_Below = AGFs_E(Count - 1);
    E_Above = AGFs_E(Count);
    Slope = (Level(Count) - Level(Count - 1))/(E_Above - E_Below);
    HTL = Level(Count - 1) + Slope * (E - E_Below);
    
    % New code
    %     Count = find(E < AGFs_E, 1, 'first');
    %     %   Handle NaN's in Level
    %     CountBelow = find(~isnan(Level(1:Count-1)), 1, 'last');
    %     CountAbove = Count - 1 + find(~isnan(Level(Count:end)), 1, 'first');
    %     E_Below = AGFs_E(CountBelow);
    %     E_Above = AGFs_E(CountAbove);
    %     Slope = (Level(CountAbove) - Level(CountBelow))/(E_Above - E_Below);
    %     HTL = Level(CountBelow) + Slope * (E - E_Below);
    
end
assert(~isnan(HTL));    % NaN not allowed

