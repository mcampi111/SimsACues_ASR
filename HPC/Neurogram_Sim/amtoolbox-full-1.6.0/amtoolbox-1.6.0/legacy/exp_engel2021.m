function exp_engel2021(varargin)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/legacy/exp_engel2021.php


%   #Author: Piotr Majdak (2023):  added as legacy for exp_engel2022

    warning(['EXP_ENGEL2021 was renamed to EXP_ENGEL2022 to match the actual publication year.' 10 10 ...            
            'Call EXP_ENGEL2022 directly to remove this warning.' 10 ...
            'Forwarding to EXP_ENGEL2022...']);
    exp_engel2022(varargin{:});
end

