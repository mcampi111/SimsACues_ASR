function definput=arg_paulick2024(definput)
% ARG_paulick2024
%
%   #License: GPL
%   #Author: Lily Paulick (2024)
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_paulick2024.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%% General

definput.flags.disp = {'no_debug','debug'};
definput.keyvals.dboffset = dbspl(1); % dB Full scale convention of this model

%% AFB Parameters

definput.keyvals.flow    = 250; % minimum frequency of the auditory filterbank
definput.keyvals.fhigh   = 8000; % maximum frequency of the auditory filterbank
definput.keyvals.Naud    = 50; % number of freq channels in the AFB

definput.keyvals.subject = 'NH'; % subject specification, NH - Normal Hearing
definput.keyvals.model   = 'paulick2024'; % model parameter set, e.g. 'jepsen2008' or 'paulick2024'




