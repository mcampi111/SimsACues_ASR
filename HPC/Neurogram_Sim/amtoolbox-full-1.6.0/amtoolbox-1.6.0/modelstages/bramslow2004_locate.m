function [a]=bramslow2004_locate(Freq,F_Hz)
%bramslow2004_locate Locate the nearest frequency below a given frequency
%
%   Usage:  a = bramslow2004_locate(Freq, F_Hz)
%
%   Input parameters:
%     Freq          : Frequency vector (in Hz).
%     F_Hz          : Frequency to look up (in Hz).
%
%   Output:
%     a             : Index in the frequency entry in Freq which is just below the frequency F_Hz.
%
%   Note: Freq must be stricktly monotonous. 
%
%   See also: bramslow2004
%  
%   References:
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/bramslow2004_locate.php


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

if Freq(1) > F_Hz
    a=-1;
    return;
end

a = find(F_Hz < Freq, 1)-1;
if isempty(a)
    a = length(Freq);
end

% if Freq(end) > F_Hz
% 
%     while max(Freq) > F_Hz
% 
%         for n =1:1:Points
% 
%             if Freq(n) >= F_Hz
% 
%                 b=n-1;
%                 return;
%             end
%         end
%         return;
%     end
% else
%     b=Points;
% end
% 
% assert(a==b);



