function CAR_coeffs = lyon2024_designfilters(CAR_params, fs, pole_freqs)
%lyon2024_designfilters Design the filter coefficients
%
%   No documentation provided yet. 
%
%   See also:  lyon2024 demo_lyon2024 lyon2024_design
%
%   References:
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2024_designfilters.php


%   #StatusDoc: Submitted
%   #StatusCode: Submitted
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): Original implementation (https://github.com/google/carfac), as lyon2011_designfilters.
%   #Author: Mihajlo Velimirovic (2023): Integration as a separate stage based on local function of lyon2011_design, as lyon2011_designfilters.
%   #Author: Piotr Majdak (2024): Rudimentary clean up for the AMT 1.6, as lyon2011_designfilters.
%   #Author: Piotr Majdak (2024): Copied from lyon2011_init, adaptations for lyon2024 for AMT 1.6.


% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

  n_ch = length(pole_freqs);

  % the filter design coeffs:
  % scalars first:
  CAR_coeffs = struct( ...
    'n_ch', n_ch, ...
    'velocity_scale', CAR_params.velocity_scale, ...
    'v_offset', CAR_params.v_offset, ...
    'ac_coeff', 2 * pi * CAR_params.ac_corner_Hz / fs);

  % don't really need these zero arrays, but it's a clue to what fields
  % and types are needed in other language implementations:
  CAR_coeffs.r1_coeffs = zeros(n_ch, 1);
  CAR_coeffs.a0_coeffs = zeros(n_ch, 1);
  CAR_coeffs.c0_coeffs = zeros(n_ch, 1);
  CAR_coeffs.h_coeffs = zeros(n_ch, 1);
  CAR_coeffs.g0_coeffs = zeros(n_ch, 1);
  CAR_coeffs.ga_coeffs = zeros(n_ch, 1);
  CAR_coeffs.gb_coeffs = zeros(n_ch, 1);
  CAR_coeffs.gc_coeffs = zeros(n_ch, 1);

  CAR_coeffs.OHC_health = ones(n_ch, 1);  % 0 to 1 to derate OHC activity.

  % zero_ratio comes in via h.  In book's circuit D, zero_ratio is 1/sqrt(a),
  % and that a is here 1 / (1+f) where h = f*c.
  % solve for f:  1/zero_ratio^2 = 1 / (1+f)
  % zero_ratio^2 = 1+f => f = zero_ratio^2 - 1
  f = CAR_params.zero_ratio^2 - 1;  % nominally 1 for half-octave

  % Make pole positions, s and c coeffs, h and g coeffs, etc.,
  % which mostly depend on the pole angle theta:
  theta = pole_freqs .* (2 * pi / fs);

  c0 = sin(theta);
  a0 = cos(theta);

  % different possible interpretations for min-damping r:
  % r = exp(-theta * CF_CAR_params.min_zeta).
  % Compress theta to give somewhat higher Q at highest thetas:
  ff = CAR_params.high_f_damping_compression;  % 0 to 1; typ. 0.5
  x = theta/pi;
  theta = pi * (x - ff * x.^3);  % when ff is 0, this is just theta,
  %                       and when ff is 1 it goes to zero at theta = pi.
  max_zeta = CAR_params.max_zeta;
  CAR_coeffs.r1_coeffs = (1 - theta .* max_zeta);  % "r1" for the max-damping condition

  min_zeta = CAR_params.min_zeta;
  if min_zeta <= 0  % Use this to do a new design strategy
    local_low_level_q = pole_freqs ./ f2erb( ...
      pole_freqs, CAR_params.ERB_break_freq, CAR_params.ERB_Q);
    % Number of overlapping channels is about ERB_per_step^-1, so this:
    min_zetas = CAR_params.ERB_per_step^-0.5 ./ (2*local_low_level_q);
    min_zetas = min(min_zetas, 0.75*max_zeta);  % Keep some low CF action.
    % "r1" for the max-damping condition
    CAR_coeffs.r1_coeffs = exp(-theta .* max_zeta);
    r0_coeffs = exp(-theta .* min_zetas);  % min_damping condition.
    CAR_coeffs.zr_coeffs = r0_coeffs - CAR_coeffs.r1_coeffs;
  else
    % Increase the min damping where channels are spaced out more, by pulling
    % toward f2erb/pole_freqs (close to 0.1 at high f)
    min_zetas = min_zeta + 0.25*(f2erb(pole_freqs, ...
      CAR_params.ERB_break_freq, CAR_params.ERB_Q) ./ pole_freqs - min_zeta);
    CAR_coeffs.r1_coeffs = (1 - theta .* max_zeta);  % "r1" for the max-damping condition
    CAR_coeffs.zr_coeffs = theta .* ...
      (max_zeta - min_zetas);  % how r relates to undamping
  end

  % undamped coupled-form coefficients:
  CAR_coeffs.a0_coeffs = a0;
  CAR_coeffs.c0_coeffs = c0;

  % the zeros follow via the h_coeffs
  h = c0 .* f;
  CAR_coeffs.h_coeffs = h;

  % Efficient approximation with g as quadratic function of undamping.
  % First get g at both ends and the half-way point.
  undamping = 0.0;
  g0 = local_designstageg(CAR_coeffs, undamping);
  undamping = 1.0;
  g1 = local_designstageg(CAR_coeffs, undamping);
  undamping = 0.5;
  ghalf = local_designstageg(CAR_coeffs, undamping);
  % Store fixed coefficients for A*undamping.^2 + B^undamping + C
  CAR_coeffs.ga_coeffs = 2*(g0 + g1 - 2*ghalf);
  CAR_coeffs.gb_coeffs = 4*ghalf - 3*g0 - g1;
  CAR_coeffs.gc_coeffs = g0;

  % Set up initial stage gains.
  undamping = CAR_coeffs.OHC_health;  % Typically just ones.
  % this function needs to take CAR_coeffs even if we haven't finished
  % constucting it by putting in the g0_coeffs:
  CAR_coeffs.g0_coeffs = local_designstageg(CAR_coeffs, undamping);
  
  
  function [ideal_g] = local_designstageg(CAR_coeffs, undamping)
% local_designstageg Obtain unity gain
%
%   Input parameters:
%     CAR_coeffs         : struct containing the CARFAC coefficients
%     undamping          : relative undamping
%
%   Output parameters:
%     ideal_g            : gain
%
%   Return the stage gain g needed to get unity gain at DC
%   See also CARFAC_Stage_g, simplified approximation used at run time,
%   based on quadratic coefficient computed at Design time.
%

r1 = CAR_coeffs.r1_coeffs;  % at max damping
a0 = CAR_coeffs.a0_coeffs;
c0 = CAR_coeffs.c0_coeffs;
h  = CAR_coeffs.h_coeffs;
zr = CAR_coeffs.zr_coeffs;
r  = r1 + zr .* undamping;  % r at specified damping
n  = 1 - 2*r.*a0 + r.^2;
d  = 1 - 2*r.*a0 + h.*r.*c0 + r.^2;
ideal_g = n ./ d;
