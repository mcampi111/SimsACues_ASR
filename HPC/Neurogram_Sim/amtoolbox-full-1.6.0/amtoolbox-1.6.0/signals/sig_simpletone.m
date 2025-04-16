function outsig = sig_simpletone(fc,fs, varargin)
%SIG_ITDSIN Generate a mono simpe tone (i.e. sinusoid)
%   Usage: outsig = sig_simpletone(fc,fs)
%
%   Input parameters:
%       fc      : carrier frequency of the sinusoid (Hz)
%       fs      : sampling rate (Hz)
%
%   Output parameters:
%       outsig  : one channel sinusoid of 1 second
%
%   SIG_SIMPLETONE(fc,fs,duration) generates a sinusoid with a 
%   frequency of fc. Duration is parametrized.
%
%   The output is scaled to have a maximum value of 1-eps.
%
%   Additional input parameters: 
%   ----------------------------
%
%     'duration'         Duration of sound in seconds. Default: 1.
%
%   #Author: Roberto Barumerli
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_simpletone.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% ------ Checking of input parameters ---------

%% Check input options
definput.keyvals.duration = 1;

[~, kv]  = ltfatarghelper({}, ...
                             definput, varargin);

if ~isnumeric(fc) || ~isscalar(fc) || fc<0
    error('%s: f must be a positive scalar.',upper(mfilename));
end

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
    error('%s: fs must be a positive scalar!',upper(mfilename));
end


% Create a one second time 
t = (1:(kv.duration*fs))/fs;

% Right signal
outsig = sin(2*pi*fc.*t)';

% Scale outsig
outsig = outsig / (max(abs(outsig(:)))+eps);

