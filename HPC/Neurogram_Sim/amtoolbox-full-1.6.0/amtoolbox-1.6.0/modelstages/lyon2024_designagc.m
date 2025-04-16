function AGC_coeffs = lyon2024_designagc(AGC_params, fs, n_ch)
%lyon2024_designagc Computes the AGC coefficients
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2024_designagc.php


%   #StatusDoc: Submitted
%   #StatusCode: OK
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): Original implementation (https://github.com/google/carfac), as lyon2024_designagc.
%   #Author: Mihajlo Velimirovic (2023): Integration as a separate stage based on local function of lyon2011_design.
%   #Author: Piotr Majdak (2024): Rudimentary clean up for the AMT 1.6, as lyon2024_designagc.
%   #Author: Piotr Majdak (2024): Copied from lyon2011, adaptations for lyon2024 for AMT 1.6.

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

  n_AGC_stages = AGC_params.n_stages;

  % AGC1 pass is smoothing from base toward apex;
  % AGC2 pass is back, which is done first now (in double exp. version)
  AGC1_scales = AGC_params.AGC1_scales;
  AGC2_scales = AGC_params.AGC2_scales;

  decim = 1;

  total_DC_gain = 0;

  %%
  % Convert to vector of AGC coeffs
  AGC_coeffs = struct([]);
  for stage = 1:n_AGC_stages
    AGC_coeffs(stage).n_ch = n_ch;
    AGC_coeffs(stage).n_AGC_stages = n_AGC_stages;
    AGC_coeffs(stage).AGC_stage_gain = AGC_params.AGC_stage_gain;
    tau = AGC_params.time_constants(stage);  % time constant in seconds

    new_way = 1;  % To try it out...
    if new_way
      % Instead of starting with decimation ratios, start with 3-tap FIR
      % and 1 iteration, and find decimation ratios that work.
      % decide on target spread (variance) and delay (mean) of impulse
      % response as a distribution to be convolved ntimes:
      % TODO (dicklyon): specify spread and delay instead of scales???
      n_taps = 3;
      n_iterations = 1;
      stage_decim = AGC_params.decimation(stage);
      FIR_OK = 0;
      while ~FIR_OK
        try_decim = decim * stage_decim;  % net decim through this stage.
        ntimes = tau * (fs / try_decim);
        delay = (AGC2_scales(stage) - AGC1_scales(stage)) / ntimes;
        spread_sq = (AGC1_scales(stage)^2 + AGC2_scales(stage)^2) / ntimes;

        [AGC_spatial_FIR, FIR_OK] = local_designfircoeffs( ...
          n_taps, spread_sq, delay, n_iterations);
        if ~FIR_OK
          stage_decim = stage_decim - 1;
          if stage_decim < 1
            error('AGC design failed.')
          end
        end
      end
      if stage_decim < 2
        disp('Warning:  No decimation, inefficient AGC design.')
      end
      decim = decim * stage_decim;  % Overall decimation through this stage.
      % Here we should have valid FIR filter and decim for the stage.
      AGC_coeffs(stage).AGC_epsilon = 1 - exp(-decim / (tau * fs));
      AGC_coeffs(stage).decimation = stage_decim;
      AGC_coeffs(stage).AGC_spatial_iterations = n_iterations;
      AGC_coeffs(stage).AGC_spatial_FIR = AGC_spatial_FIR;
      AGC_coeffs(stage).AGC_spatial_n_taps = n_taps;
    end

    % accumulate DC gains from all the stages, accounting for stage_gain:
    total_DC_gain = total_DC_gain + AGC_params.AGC_stage_gain^(stage-1);

    % TODO (dicklyon) -- is this the best binaural mixing plan?
    if stage == 1
      AGC_coeffs(stage).AGC_mix_coeffs = 0;
    else
      AGC_coeffs(stage).AGC_mix_coeffs = AGC_params.AGC_mix_coeff / ...
        (tau * (fs / decim));
    end
  end

  % adjust stage 1 detect_scale to be the reciprocal DC gain of the AGC filters:
  AGC_coeffs(1).detect_scale = 1 / total_DC_gain;
  
  function [FIR, OK] = local_designfircoeffs(n_taps, delay_variance, mean_delay, n_iter)
%local_designfircoeffs Computes the FIR coeffs
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

