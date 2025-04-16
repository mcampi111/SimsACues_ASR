function definput=arg_decheveigne2023(definput)
%ARG_DECHEVEIGNE2023
%   #Author: Alejandro Osses (2023): New argument function for the model decheveigne2023.m
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_decheveigne2023.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

definput.flags.refractoriness = {'no_refractoriness','refractoriness'};
definput.flags.jitter = {'no_jitter','jitter'};
definput.keyvals.recfun = 0; % Recovery function. Default=0 (no refractoriness)
definput.keyvals.dead_time = 0.001; % (s). Dead time used for refractoriness. Default=1 ms
definput.keyvals.nfibers = 1; % Default=1
definput.keyvals.sigma = 0; % Default if 'jitter' is applied

