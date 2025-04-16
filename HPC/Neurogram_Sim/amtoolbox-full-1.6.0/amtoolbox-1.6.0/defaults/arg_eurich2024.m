function mpar = arg_eurich2024
%   #Author: Bernhard Eurich (2024): Original implementation and integration in the AMT
%   #Author: Piotr Majdak (2024): Small adaptions for the AMT 1.6
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_eurich2024.php


% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

% frontend (eurich2024)
mpar.fs        					    = 48000; % sampling rate (in Hz)
mpar.GT_filters_per_ERBaud          = 1; % filters per ERB
mpar.GT_bwfactor                    = 1;
mpar.GT_lowest_center_frequency     = 315; % (in Hz)
mpar.GT_fix_center_frequency        = 500; % one filter will be centered here --> fc
mpar.GT_highest_center_frequency    = 12500; % just central channel for now
mpar.GT_filterorder                 = 4;
mpar.interference_sigma             = 0; 
mpar.iKernelThresh                  = 1e-3; % treshold above which a value of the Gaussian filter window is used
mpar.window                         = 2; 
mpar.env_lowpass_fc                 = 150; % Hz
mpar.env_lowpass_n                  = 1;
mpar.mso_rolloff                    = 1300; % below: Gamma based on fine structure; above: on envelopes (in Hz)
mpar.ild_lim                        = 10; % from Fleßner 17 (in dB)
mpar.rho_max                        = 0.9; 
mpar.FrameLen                       = 0.4; % (in samples)

% backend (eurich2024_backend)
mpar.mon_min = 0;
mpar.mon_max = 26;
mpar.bin_min = 0;
mpar.bin_max =  23; 
mpar.ild_weight =1/13;
mpar.ild_lim = 5; % 10 in total

