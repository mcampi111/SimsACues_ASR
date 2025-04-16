function [lat,pol]=sph2horpolar(azi,ele)
%sph2horpolar Convert from spherical to horizontal-polar coordinate system
%
%   Usage:    [lat,pol] = sph2horpolar(azi,ele);
%
%   Input parameters:
%     azi     : Azimuth angle in degrees. Can be scalar or a vector. 
%     ele     : Elevation angle in degrees. Must be scalar or the size of azi.
%
%   Output parameters:
%     lat     : Lateral angle in degrees, ranging from -90 ^circ to +90 ^circ.
%     pol     : Polar angle in degress, ranging from -90 ^circ to +270 ^circ.
%
%   [lat,pol] = SPH2HORPOLAR(azi,ele); converts the direction given by the 
%   azimuth angle azi and elevation angle ele 
%   into the coordinates of the horizontal-polar system as shown in Fig. 2
%   in Majdak et al., (2013). In that coordinate system, a point on a sphere 
%   is described by the lateral angle lat and polar angle pol.
%
%   See also: cart2horpolar
%
%   References:
%     P. Majdak, T. Walder, and B. Laback. Effect of long-term training on
%     sound localization performance with spectrally warped and band-limited
%     head-related transfer functions. The Journal of the Acoustical Society
%     of America, 134:2148--2159, 2013.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/sph2horpolar.php


%   #Author: Piotr Majdak (2009): original implementation
%   #Author: Robert Baumgartner (2010): various improvements
%   #Author: Robert Baumgartner (2012): integration in the AMT
%   #Author: Piotr Majdak (2022): doc fix and bug fix in occasional complex-valued results

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

azi=mod(azi+360,360);
ele=mod(ele+360,360);

razi = deg2rad(azi);
rele = deg2rad(ele);
rlat=asin(sin(razi).*cos(rele));
rpol=real(asin(sin(rele)./cos(rlat)));
rpol(cos(rlat)==0)=0;
pol = rad2deg(rpol);
lat = rad2deg(rlat);

idx = find(razi>pi/2 & razi < 3*pi/2 & (rele < pi/2 | rele > 3*pi/2));
pol(idx)=180-pol(idx);
idx = find(~(razi>pi/2 & razi < 3*pi/2) & rele > pi/2 & rele < 3*pi/2);
pol(idx)=180-pol(idx);

end


