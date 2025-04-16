function data = data_hassager2016
%data_hassager2016 Externalization ratings as a function of spectral smoothness
%   Usage: data = data_hassager2016;
%         
%   Output parameters:
%     data : structure containing the listeners' ratings for the 
%            direct-sound condition with the following fields:
%
%            - B*: Vector with the eleven bandwidth factors (in ERB).
%
%            - angle*: Vector with the two source angles (in degrees).
%
%            - rating*: An 11-by-2 matrix with the externalization ratings.
%
%
%   References:
%     H. G. Hassager, F. Gran, and T. Dau. The role of spectral detail in the
%     binaural transfer function on perceived externalization in a
%     reverberant environment. The Journal of the Acoustical Society of
%     America, 139(5):2992--3000, 2016.
%     
%
%   See also: hassager2016 exp_hassager2016
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/data/data_hassager2016.php


%   #Author: Robert Baumgartner (2016)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


data.B = [nan,0.316, 0.570, 1.03, 1.85, 3.33, 6.0, 10.8, 19.5 35.0, 63.1];

data.angle = [0,50];

data.rating = ...
  [ 4.79,4.73,4.70,4.67,4.43,3.65,2.81,1.97,1.60,1.49,1.30;
    4.94,4.92,4.94,4.85,4.79,4.33,3.86,3.21,2.59,2.08,1.60 ]';

end


