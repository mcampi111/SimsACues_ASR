function [lat,pol]=cart2horpolar(X,Y,Z)
%cart2horpolar Convert from Cartesian to horizontal-polar coordinate system
%
%   Usage:    [lat,pol]=cart2horpolar(x,y,z);
%
%   Input parameters:
%     x     : X coordinate. Can be scalar or a vector. 
%     y     : Y coordinate. Must be scalar or the size of x.
%     z     : Z coordinate. Must be scalar or the size of x.
%
%   Output parameters:
%     lat     : Lateral angle in degrees, ranging from -90 ^circ to +90 ^circ.
%     pol     : Polar angle in degress, ranging from -90 ^circ to +270 ^circ.
%
%   [lat,pol]=CART2HORPOLAR(x,y,z); converts the Cartesian coordinates x,y,z,*
%   into the coordinates of the horizontal-polar system as shown in Fig. 2
%   in Majdak et al., (2013). In that coordinate system, a point on a sphere 
%   is described by the lateral angle lat and polar angle pol.
%
%   See also: sph2horpolar
%
%   References:
%     P. Majdak, T. Walder, and B. Laback. Effect of long-term training on
%     sound localization performance with spectrally warped and band-limited
%     head-related transfer functions. The Journal of the Acoustical Society
%     of America, 134:2148--2159, 2013.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/cart2horpolar.php


%   #Author: Harald Ziegelwanger (2011): Original implementation of sph2hor
%   #Author: Robert Baumgartner (2015): Major modification of sph2hor
%   #Author: Piotr Majdak (2024): rewrite as cart2horpolar for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

  % remove noise below eps
X(abs(X)<eps)=0;
Y(abs(Y)<eps)=0;
Z(abs(Z)<eps)=0;

  % horizontal polar system as rotated spherical coordinates with negative azimuth direction
[pol,nlat] = cart2sph(X,Z,-Y);
pol = rad2deg(pol);
lat = rad2deg(-nlat);

  % adjust the polar angle range
pol = mod(pol+90,360)-90;

end


