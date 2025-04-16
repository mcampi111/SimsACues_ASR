function [Y, prob] = paulick2024_decision(mue,nAFC,rule,varargin)
%paulick2024_decision Decision and probability detecting a signal
%
%   Usage: Y = paulick2024_decision(mue, nAFC, rule);
%          [Y, prob] = paulick2024_decision(..);
%
%   Input parameters:
%     mue        : Correlation coefficient from PAULICK2024_CORR. 
%     nAFC       : Number of available choices in the simulated AFC task, must be 2, 3, or 4. 
%     rule       : Two-entry vector containing reflecting the tracking rule in the adaptive procedure.
%                  The first entry defines the amount of steps when going up, 
%                  the second scalar defines the amount of steps when going down, 
%                  e.g., [1 2] defines a 1-up-2-down adaptive procedure. 
%
%   Output parameters:
%     Y :    Decision of the simulated subject:
%
%            - 1: target detected. 
%
%            - 0: target not detected. 
%
%     prob:  Probability used to obtain the decision Y.
%
%     
%   See also: paulick2024 demo_paulick2024
%
%   References:
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/paulick2024_decision.php


%   #Author: Lily Paulick (2024): Original implementation. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
  
% ------ Checking of input parameters ------------
if nargin<3
  error('%s: Too few input arguments.',upper(mfilename));
end

if ~(rule(1) == 1)
  error('%s: only 1up - n down implemented.',upper(mfilename));
end

definput.import={'paulick2024'};

[flags,kv]  = ltfatarghelper({'flow','fhigh'},definput,varargin);

% Define internal noise variance
if strcmp(kv.model,'jepsen2008')
    in_var = 130;
elseif strcmp(kv.model,'paulick2024')
    in_var = 40;
end

switch nAFC
    case 2
	    prob = 1 - (erfc((((mue / sqrt(in_var)) * 0.707) - 0) * 0.7071068) / 2);
    case 3
	    prob = 1 - (erfc((((mue / sqrt(in_var)) * 0.765) - 0.423) * 0.7071068) / 2);
    case 4
 	    prob = 1 - (erfc((((mue / sqrt(in_var)) * 0.810) - 0.668) * 0.7071068) / 2);
    otherwise
	    error('CASP:mdecide', 'Only 2-, 3- and 4-AFC procedures are implemented');
end

if rule(1) == 1 && prob > (1 / (2 .^ (1/rule(2))))
    Y = 1;
else
    Y = 0;
end



