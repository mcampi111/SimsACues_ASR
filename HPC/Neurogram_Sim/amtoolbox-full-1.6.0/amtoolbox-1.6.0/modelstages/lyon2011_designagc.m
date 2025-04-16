function AGC_coeffs = lyon2011_designagc(AGC_params, fs, n_ch)
%lyon2011_designagc Computes the AGC coeffs
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_designagc.php


%   #StatusDoc: Submitted
%   #StatusCode: OK
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

        [AGC_spatial_FIR, FIR_OK] = lyon2011_designfircoeffs( ...
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
    else
      AGC_coeffs(stage).decimation = AGC_params.decimation(stage);
      decim = decim * AGC_params.decimation(stage);  % net decim to this stage
      % epsilon is how much new input to take at each update step:
      AGC_coeffs(stage).AGC_epsilon = 1 - exp(-decim / (tau * fs));

      % effective number of smoothings in a time constant:
      ntimes = tau * (fs / decim);  % typically 5 to 50

      % decide on target spread (variance) and delay (mean) of impulse
      % response as a distribution to be convolved ntimes:
      % TODO (dicklyon): specify spread and delay instead of scales???
      delay = (AGC2_scales(stage) - AGC1_scales(stage)) / ntimes;
      spread_sq = (AGC1_scales(stage)^2 + AGC2_scales(stage)^2) / ntimes;

      % get pole positions to better match intended spread and delay of
      % [[geometric distribution]] in each direction (see wikipedia)
      u = 1 + 1 / spread_sq;  % these are based on off-line algebra hacking.
      p = u - sqrt(u^2 - 1);  % pole that would give spread if used twice.
      dp = delay * (1 - 2*p +p^2)/2;
      polez1 = p - dp;
      polez2 = p + dp;
      AGC_coeffs(stage).AGC_polez1 = polez1;
      AGC_coeffs(stage).AGC_polez2 = polez2;

      % try a 3- or 5-tap FIR as an alternative to the double exponential:
      n_taps = 0;
      FIR_OK = 0;
      n_iterations = 1;
      while ~FIR_OK
        switch n_taps
          case 0
            % first attempt a 3-point FIR to apply once:
            n_taps = 3;
          case 3
            % second time through, go wider but stick to 1 iteration
            n_taps = 5;
          case 5
            % apply FIR multiple times instead of going wider:
            n_iterations = n_iterations + 1;
            if n_iterations > 16
              error('Too many n_iterations in lyon2011_designagc');
            end
          otherwise
            % to do other n_taps would need changes in lyon2011_spatialsmooth
            % and in lyon2011_designfircoeffs
            error('Bad n_taps in lyon2011_designagc');
        end
        [AGC_spatial_FIR, FIR_OK] = lyon2011_designfircoeffs( ...
          n_taps, spread_sq, delay, n_iterations);
      end
      % when FIR_OK, store the resulting FIR design in coeffs:
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
