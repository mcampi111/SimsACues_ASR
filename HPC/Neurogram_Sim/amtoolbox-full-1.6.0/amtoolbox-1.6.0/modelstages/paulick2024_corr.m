function out = paulick2024_corr(x,template,fs,fc_aud,fc_mod,varargin)
%paulick2024_corr  Correlation coefficient between target and template
%
%   Usage: out = paulick2024_corr(x, template, fs, fc_aud, fc_mod);
%
%   Input parameters:
%     x        : Internal representation of the target as obtained from PAULICK2024.
%     template : Internal representation of the supra-threshold template 
%                as obtained from PAULICK2024.
%     fs       : Sampling rate (in Hz).
%     fc_aud   : Centre frequencies (in Hz) of the auditory filterbank.
%     fc_mod   : Centre frequencies (n Hz) of the modulation filterbank. 
%
%   Output parameters:
%     out : Structure with the correlation metric:
%
%           - int*: Correlation coefficients for each modulation band.
%
%           - fin*: Final averaged correlation coefficient. 
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/paulick2024_corr.php


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
end;

if ~isnumeric(x) 
  error('%s: insig must be numeric.',upper(mfilename));
end;

if ~isnumeric(template) 
  error('%s: template must be numeric.',upper(mfilename));
end;

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
  error('%s: fs must be a positive scalar.',upper(mfilename));
end

definput.import={'paulick2024'};

[flags,kv]  = ltfatarghelper({'flow','fhigh'},definput,varargin);

[dim1,dim2,dim3] = size(template);
idx = 1:dim2; 

mutarget = nan(dim3,1);    
for mm = 1:dim3

    % remove auditory channels below 1/4 of the modulation frequency 
        % in case not already done in the internal representation signals
    rule_4th = find(fc_aud > 4*fc_mod(mm));
    rule_4th = idx(rule_4th);

    if strcmp(kv.model,'jepsen2008') % original CASP correlates over all three dimensions simulatenously
        temp_av = 0;
        tar_av = 0;
    elseif strcmp(kv.model,'paulick2024') % revised CASP takes into account across frequency differences
        temp = template(:,rule_4th,mm);
        temp_av = mean(temp(:));
        temp = x(:,rule_4th,mm);
        tar_av = mean(temp(:));
    end

    mutarget(mm) = sum(sum((x(:,rule_4th,mm) - tar_av).*(template(:,rule_4th,mm) - temp_av)));
    
end

out.int = mutarget;
out.fin = sum(mutarget,'omitnan');



