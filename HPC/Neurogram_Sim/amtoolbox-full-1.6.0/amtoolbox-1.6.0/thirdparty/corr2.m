function R = corr2(x,y)
%CORR2 AMT's replacement for Matlab's corr2 function
%
%   This file avoids the requirement for the Image Processing Toolbox
%   within the AMT. 
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/thirdparty/corr2.php


%   #Author: Piotr Majdak (2023): implemented for the AMT 1.5

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose.

x = x- mean(x(:)); % remove the bias from x
y = y- mean(y(:)); % remove the bias from x
R = sum(sum(x.*y))/sqrt(sum(sum(x.*x))*sum(sum(y.*y))); % calc sum(x*y) normalized by average energy



