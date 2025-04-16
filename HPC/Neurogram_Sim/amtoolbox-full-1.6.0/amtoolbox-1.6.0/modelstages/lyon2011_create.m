function CF = lyon2011_create(n_ears, fs, zero_v_offset, ohc_health)
%LYON2011_CREATE computes all the coefficients needed to run Lyon's
%  CARFAC model
%
%   Usage:
%     CF = lyon2011_create(n_ears, fs, zero_v_offset, ohc_health)
%
%
%   Input parameters:
%     n_ears        : number of input signals
%     fs            : sampling frequency [Hz]
%     zero_v_offset : bool to turn off most quadratic distortion (0)
%     ohc_health    : frequency/health pairs ([[0, 1.0]; [20000, 1.0]])
%
%   Output parameters:
%     CF            : The CARFAC model structure with coefficients
%
%   Defaults to Glasberg & Moore's ERB curve:
%   ERB_break_freq = 1000/4.37;  % 228.833  (or does it use Greenberg???)
%   ERB_Q = 1000/(24.7*4.37);    % 9.2645
%
%   All args are defaultable; for sample/default args see the code; they
%   make 71 channels (with Greenberg's ERB_break_freq = 165.3 Hz) at
%   default fs = 22050, more at higher rates.
%
%   This function designs the CARFAC (Cascade of Asymmetric Resonators with
%   Fast-Acting Compression); that is, it take bundles of parameters and
%   computes all the filter coefficients needed to run it.
%
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_create.php


%   #StatusDoc: Submitted
%   #StatusCode: OK
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Mihajlo Velimirovic (2023): integration in the AMT
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

if nargin < 1
  n_ears = 1;  % if more than 1, make them identical channels;
  % then modify the design if necessary for different reasons
end

if nargin < 2
  fs = 22050;
end

if nargin < 3
  zero_v_offset = 0;
end

if nargin < 4
  ohc_health = [[0, 1.0]; [20000, 1.0]];
end

% Modify some params and re-design if desired.
CF = lyon2011_design(n_ears, fs);
if zero_v_offset
  % Redesign with zero v_offset in CAR_params to override default 0.04.
  CF_CAR_params = CF.CAR_params;
  CF_CAR_params.v_offset = 0;
  CF = lyon2011_design(n_ears, fs, CF_CAR_params);
end

% Modify the OHC_health coeffs after design is done.
for ear = 1:CF.n_ears
  if (size(ohc_health, 3) > 1)
    health_points = squeeze(ohc_health(ear, :, :));  % Multi-ear option.
  else
    health_points = ohc_health;
  end
  if isempty(health_points)
    health_points = [[0, 1.0]];
  end
  % Extrapolate, DC to 50 kHz.
  if health_points(1,1) > 0
    health_points = [[0, health_points(1,2)]; health_points];
  end
  if health_points(end,1) < max(CF.pole_freqs)
    health_points = [health_points; ...
      [max(CF.pole_freqs), health_points(end,2)]];
  end
  % Interpolate ohc_health points to channel nominal frequencies.
  CF.ears(ear).CAR_coeffs.OHC_health = interp1( ...
    health_points(:,1), health_points(:,2), CF.pole_freqs, 'linear', 0.0);
end

