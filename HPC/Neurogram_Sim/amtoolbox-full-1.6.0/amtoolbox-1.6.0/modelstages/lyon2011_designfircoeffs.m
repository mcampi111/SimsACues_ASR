function [FIR, OK] = lyon2011_designfircoeffs(n_taps, delay_variance, mean_delay, n_iter)
%lyon2011_designfircoeffs Computes the FIR coeffs
%  Usage: function [FIR, OK] = lyon_designfircoeffs(n_taps, delay_variance, mean_delay, n_iter)
%
%   The smoothing function is a space-domain smoothing, but it considered
%   here by analogy to time-domain smoothing, which is why its potential
%   off-centeredness is called a delay.  Since it's a smoothing filter, it is
%   also analogous to a discrete probability distribution (a p.m.f.), with
%   mean corresponding to delay and variance corresponding to squared spatial
%   spread (in samples, or channels, and the square thereof, respecitively).
%   Here we design a filter implementation's coefficient via the method of
%   moment matching, so we get the intended delay and spread, and don't worry
%   too much about the shape of the distribution, which will be some kind of
%   blob not too far from Gaussian if we run several FIR iterations.
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_designfircoeffs.php


%   #StatusDoc: Submitted
%   #StatusCode: Submitted
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Mihajlo Velimirovic (2023): integration as a separate stage based on local function of lyon2011_design
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.


% reduce mean and variance of smoothing distribution by n_iterations:
mean_delay = mean_delay / n_iter;
delay_variance = delay_variance / n_iter;
switch n_taps
  case 3
    % based on solving to match mean and variance of [a, 1-a-b, b]:
    a = (delay_variance + mean_delay*mean_delay - mean_delay) / 2;
    b = (delay_variance + mean_delay*mean_delay + mean_delay) / 2;
    FIR = [a, 1 - a - b, b];
    OK = FIR(2) >= 0.25;
  case 5
    % based on solving to match [a/2, a/2, 1-a-b, b/2, b/2]:
    a = ((delay_variance + mean_delay*mean_delay)*2/5 - mean_delay*2/3) / 2;
    b = ((delay_variance + mean_delay*mean_delay)*2/5 + mean_delay*2/3) / 2;
    % first and last coeffs are implicitly duplicated to make 5-point FIR:
    FIR = [a/2, 1 - a - b, b/2];
    OK = FIR(2) >= 0.15;
  otherwise
    error('Bad n_taps in local_designFIRcoeffs');
end

