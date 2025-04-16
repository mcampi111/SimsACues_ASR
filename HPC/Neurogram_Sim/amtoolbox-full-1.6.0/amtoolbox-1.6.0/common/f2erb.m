function ERB = f2erb(CF_Hz, ERB_f, ERB_Q)
%f2erb Calculates the equivalent rectangular bandwidth of an auditory filter
%
%   Usage: erb = f2erb(f);
%          erb = f2erb(f, ERB_f, ERB_Q);
%
%   Input parameters: 
%     f      : Center frequency of the auditory filter (in Hz)
%     ERB_f  : Optional Greenwood map's break frequency (in Hz).
%     ERB_Q  : Optional Glasberg and Moore's high-cf ratio
%
%   erb = F2ERB(f); calculates the equivalent rectangular bandwidth (ERB)
%   (in Hz) according to Eq. 4 Glasberg and Moore (1990) or Moore et al. (1997): 
%
%       erb = 24.7 * (1 + 4.37 * f / 1000);
%
%   This bandwidth is also usually referred to as 1 Cam, see e.g., Moore et al. (2016).
%
%   erb = F2ERB(f, ERB_f, ERB_Q); calculates the ERB (in Hz)
%   as used by Lyon (2011) to design the filters in LYON2011_DESIGN. 
%
%   See also: moore1997 lyon2011_design moore2016 
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%     B. C. J. Moore, B. R. Glasberg, and T. Baer. A Model for the Prediction
%     of Thresholds, Loudness, and Partial Loudness. J. Audio Eng. Soc,
%     45(4):224--240, 1997.
%     
%     B. R. Glasberg and B. Moore. Derivation of auditory filter shapes from
%     notched-noise data. Hearing Research, 47(1-2):103--138, 1990.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/f2erb.php


%   #Author: Thomas Deppisch (2017): original implementation
%   #Author: Clara Hollomey (2021): integration in the AMT
%   #Author: Piotr Majdak (2024): documentation upgrade for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


if nargin < 3
    ERB_Q = 1000/(24.7*4.37);  % 9.2645
	if nargin < 2
		ERB_f = 1000/4.37;  % 228.833
	end
end

if nargin == 1
    ERB = 24.673*(0.004368*CF_Hz + 1); %as originally given in glasberg1990 and moore1997
else
    ERB = (ERB_f + CF_Hz) / ERB_Q;
end


