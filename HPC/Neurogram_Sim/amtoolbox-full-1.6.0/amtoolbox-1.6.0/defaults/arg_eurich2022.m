function definput=arg_eurich2022(definput)
%   #Author: Bernhard Eurich (2022): original implementation
%   #Author: Piotr Majdak (2023): adaptation to AMT 1.5
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_eurich2022.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

definput.keyvals.fs                             = 48000;
definput.keyvals.GT_filters_per_ERBaud          = 1; % filters per ERB (narrower spacing causes very long computation times)
definput.keyvals.GT_bandwidth_factor            = 1; % "standard" filter bandwidth
definput.keyvals.GT_lowest_center_frequency     = 67; % Hz
definput.keyvals.GT_fix_center_frequency        = 500; % one filter will be centered here --> fc
definput.keyvals.GT_highest_center_frequency    = 1000; % just central channel for now
definput.keyvals.GT_filterorder                 = 4;
definput.keyvals.interference_sigma             = 0.5;
definput.keyvals.iKernelThresh                  = 1e-3; % treshold above which a value of the Gaussian filter window is used
definput.keyvals.rho_max                        = 0.9; 
definput.keyvals.monaural_internal_noise_sigma  = 0.4;
definput.keyvals.binaural_internal_noise_sigma  = 0.2;
definput.keyvals.target_channel                 = 9; % only the 9th channel (=at 500 Hz) will be evaluated per default

