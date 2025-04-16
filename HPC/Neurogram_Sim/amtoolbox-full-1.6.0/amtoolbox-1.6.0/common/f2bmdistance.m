function [dists, CFs] = f2bmdistance( flow, fhigh, N)
%f2bmdistance Basilar-membrane distances and center frequencies in the cochlea
%    
%   Usage: [dists, CFs] = f2bmdistance( flow, fhigh, segnum );
%
%   Input parameters: 
%     flow   : Lowest center frequency (in Hz).
%     fhigh  : Highest center frequency (in Hz). 
%     N      : Number of segments at the cochlea. 
%
%   F2BMDISTANCE calculates the distances (in mm) at the basilar 
%   membrane (BM) from the human cochlea apex and the corresponding 
%   characteristic frequencies (CFs, in Hz) according to the position-frequency 
%   function from Greenwood (1990). 
%   
%   The CFs and distances are calculated for N places at the BM 
%   beginning with low-frequency flow and ending with the high-frequency 
%   fhigh.
%
%   References:
%     D. D. Greenwood. A cochlear frequency‐position function for several
%     species—29 years later. The Journal of the Acoustical Society of
%     America, 87(6):2592--2605, 06 1990.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/f2bmdistance.php


%   #Author: Clara Hollomey (2020): Implementation as greenwood to be used by lyon2011.
%   #Author: Clara Hollomey (2021): Renamed to f2bmdistance.
%   #Author: Clara Hollomey (2021): Parameters flow and fhigh added. 
%   #Author: Piotr Majdak (2024): Major bug fixes and documentation upgrade for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

  % Parameters for Eq. 1 from Greenwood (1990), page 2593.
A = 165.44; 
alpha = 0.06; 
k = 1;
Plow=(log10((flow/A)+k)/alpha);
Phigh=(log10((fhigh/A)+k)/alpha);
Pos=zeros(N,1);
for ii=1:N
    Pos(ii)=((Plow-Phigh)/(N-1))*(ii-1)+Phigh;
end

CFs=A.*(10.^(alpha.*Pos)-k);
dists=Pos;

