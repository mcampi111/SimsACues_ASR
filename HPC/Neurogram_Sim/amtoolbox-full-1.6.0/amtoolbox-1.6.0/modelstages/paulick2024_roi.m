function roi = paulick2024_roi(insig,fs,fc_aud,varargin)
%paulick2024_roi  Region of interest of auditory frequencies based on a supra-threshold template
%
%   Usage: roi = paulick2024_roi(insig, fs, fc_aud, fc_mod);
%
%   Input parameters:
%     insig    : Internal representation of the auditory process obtained from PAULICK2024.
%     fs       : Sampling rate (in Hz).
%     fc_aud   : Vector with centre frequencies (in Hz) of the auditory filterbank. 
%
%   Output parameters:
%     roi : Structure containing the correlation metrics with the following fields:
%
%           - idx*: Indices of relevant frequency channels.
%
%           - freq*: Centre frequencies (in Hz) of relevant frequency channels.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/paulick2024_roi.php


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

if ~isnumeric(insig) 
  error('%s: insig must be numeric.',upper(mfilename));
end;

smoothed_signal = nan(size(insig)); % smooth signal
for ii = 1:size(insig,2)
    win_size = 25/fc_aud(ii)*fs; 
    smoothed_signal(:,ii) = movmean(insig(:,ii), win_size);
end

met = rms(smoothed_signal);
[~,Iaud] = max(met); % Find channel with largest rms

aux = find(met >= 0.5*max(met)); % Find channels with rms >= 0.5*max
Imin = aux(1); Imax = aux(end); 

% Minimum range
[~,minI] = min(abs(fc_aud - 1/sqrt(2)*fc_aud(Iaud))); 
Imin = min(minI,Imin);

[~,maxI] = min(abs(fc_aud - sqrt(4)*fc_aud(Iaud)));
Imax = max(maxI,Imax);

roi.idx = Imin:Imax;
roi.freq = fc_aud(Imin:Imax);
