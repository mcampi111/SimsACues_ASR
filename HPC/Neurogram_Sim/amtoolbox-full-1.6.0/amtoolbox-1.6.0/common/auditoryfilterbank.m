function [outsig, fc] = auditoryfilterbank(insig, fs, varargin)
%auditoryfilterbank Linear Gammatone auditory filterbank
%   Usage: [outsig, fc] = auditoryfilterbank(insig, fs);
%          [outsig, fc] = auditoryfilterbank(insig, fs, flow);
%          [outsig, fc] = auditoryfilterbank(insig, fs, flow, fhigh);
%
%   Input parameters:
%     insig  : Acoustic signal. Size: (*time x channels*).
%     fs     : Sampling rate (in Hz).
%     flow   : Optional frequency (in Hz) of the lowest filter. 
%              Default: 80 Hz. 
%     fhigh  : Optional frequency (in Hz) of the highest filter. 
%              Default: 8 kHz. 
%
%   Output parameters:
%     outsig : Filtered output. Size: (*time x numfc x channels*).
%     fc     : Center frequencies (in Hz) of the applied filterbank. 
%              The number of filters numfc is the result of flow, fhigh*
%              and bwmul. Default: 31.
%  
%   AUDITORYFILTERBANK(insig, fs) applies the Gammatone filterbank to the
%   signal insig sampled with fs. The filterbank will be composed of 
%   31 filters from 80 Hz to 8 kHz spaced 1 ERB apart.
%  
%   [outsig, fc] = AUDITORYFILTERBANK(...) additionally returns the center
%   frequencies fc of the filterbank.
%
%   This function takes the following optional key-value pairs:
%
%     'flow',flow    As flow.
%
%     'fhigh',fhigh  As fhigh.
%
%     'basef',basef  Center one filter exactly at basef (in Hz) and spread
%                    other filters accordingly. Default: [], which means 
%                    that the filters will be spread optimally between 
%                    flow and fhigh. 
%
%     'bwmul',bwmul  Spacing of the auditory filters in the ERB rate. 
%                    Default: 1, which means that filters will be spaced 
%                    one ERB apart.
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/auditoryfilterbank.php


%   #Author: Peter L. Soendergaard (2011): Original implementation.
%   #Author: Piotr Majdak (2016): Removed obsolete flag 'langendijk'.
%   #Author: Clara Hollomey (2021): Option 'lavandier2022' added.
%   #Author: Piotr Majdak (2024): Major documentation and explicit evaluation of 'lavandier2022' for work for AMT 1.6. 

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
  
% ------ Checking of input parameters ------------

if nargin<2
  error('%s: Too few input arguments.',upper(mfilename));
end

if ~isnumeric(insig) 
  error('%s: insig must be numeric.',upper(mfilename));
end

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
  error('%s: fs must be a positive scalar.',upper(mfilename));
end

definput.import={'auditoryfilterbank'}; % load from arg_auditoryfilterbank
[flags,keyvals,flow,fhigh]  = ltfatarghelper({'flow','fhigh'},definput,varargin);

% ------ do the computation -------------------------
if flags.do_default
    % find the center frequencies used in the filterbank, 1 ERB spacing
    fc = erbspacebw(flow, fhigh, keyvals.bwmul, keyvals.basef);

    % Calculate filter coefficients for the gammatone filter bank.
    [gt_b, gt_a]=gammatone(fc, fs, 'complex');

    % Apply the Gammatone filterbank
    outsig = 2*real(ufilterbankz(gt_b,gt_a,insig));
end

if flags.do_lavandier2022
    fc = varargin{1};
    outsig = comp_auditoryfilterbank_singlefc(insig, fs, fc);
end


