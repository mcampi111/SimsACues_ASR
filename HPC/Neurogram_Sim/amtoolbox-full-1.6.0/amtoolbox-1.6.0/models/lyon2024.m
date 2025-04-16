function [CF, decim_naps, naps, BM, ohc, agc, ihc_potential] = lyon2024(input_waves, CF)
%lyon2024 The cascade of asymmetric resonators with fast-acting compression (CARFAC) model (two-capacitor version)
%   Usage: [CF, decim_naps, naps, BM, ohc, agc] = lyon2024(input_waves, CF);
%          [CF, decim_naps, naps, BM, ohc, agc, ihc_potential] = lyon2024(input_waves, CF);
%
%
%   Input parameters:
%     input_waves      : Audio signal sampled at the rate of CF.fs. Size: (*time x ears*).
%     CF               : Structure describing the model design and state. 
%                        Usually, this is the output of LYON2024_DESIGN and 
%                        LYON2024_INIT, see EXP_LYON2024 for an example.
%
%   Output parameters:
%     CF               : The updated CF structure, see LYON2024_DESIGN for more details.
%     decim_naps       : Neural activity patterns (NAPs) time-decimated by
%                        CF.seglen.
%     naps             : NAPs. Size: (*time x frequency x ears*).
%     BM               : Motion of the basilar membrane (BM) as the filter outputs
%                        before the inner hair cell (IHC) processing.
%     ohc              : Diagnosing internals. Meaning unclear.
%     agc              : Diagnosing internals. Meaning unclear. 
%     ihc_potential    : IHC potential equivalent (unit unclear). 
%
%   LYON2024(..), as known as the CARFAC v2 model, is a model of the auditory 
%   periphery, reflecting the automatic-gain-control function of the auditory
%   system and maintaining the time-domain zero-crossings depending on 
%   the signal level. It is built as a cascade of asymmetric resonators with
%   fast-acting compression (CARFAC). This model a modification of LYON2011:
%
%   1. The high-pass filter (HPF) has been moved from IHC stage to the stage 
%      with the cascade of resonators.
%
%   2. Two capacitors are used (instead of one as in LYON2011).
%
%
%   License
%   -------
%
%   This model is licensed under the Apache License Version 2.0. Further usage details 
%   are provided in the in the AMT directory "licences".
%
%   See also:   demo_lyon2024 exp_lyon2024 lyon2024_init lyon2024_design lyon2011 
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/lyon2024.php


%   #StatusDoc: OK
%   #StatusCode: OK
%   #Verification: Qualified
%   #License: Apache2
%   #Author: Mihajlo Velimirovic (2023): Original implementation for the AMT.
%   #Author: Piotr Majdak (2024): Integration in the AMT 1.6.

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.

  if CF.IHC_params.one_cap
    error('lyon2024 (CARFAC v2) needs two capacitors. See lyon2024_create.')
  end

  if CF.IHC_params.ac_corner_Hz > 0 || CF.CAR_params.ac_corner_Hz <= 0
    error('lyon2024 (CARFAC v2) moved HPF from IHC to CAR stage. See lyon2024_create.')
  end

  % Level correction because CARFAC works in non-standard amplitude units.
input_waves = input_waves * sqrt(1/10); %  0 dB FS corresponds to an SPL of 104 dB



[n_samp, n_ears] = size(input_waves);
n_ch = CF.n_ch;

if n_ears ~= CF.n_ears
  error('Number of input channels does not match the number of n_ears coefficient')
end

if ~isfield(CF, 'seglen')  % If no seglen specified...
  CF.seglen = round(CF.fs/50);  % anything should work; this is 20 ms.
end
seglen = CF.seglen;
n_segs = ceil(n_samp / seglen);

if nargout > 1
  % make decimated detect output:
  decim_naps = zeros(n_segs, CF.n_ch, CF.n_ears);
else
  decim_naps = [];
end

if nargout > 2
  % make decimated detect output:
  naps = zeros(n_samp, CF.n_ch, CF.n_ears);
else
  naps = [];
end

if nargout > 3
  BM = zeros(n_samp, n_ch, n_ears);
else
  BM = [];
end

if nargout > 4
  ohc = zeros(n_samp, n_ch, n_ears);
else
  ohc = [];
end

if nargout > 5
  agc = zeros(n_samp, n_ch, n_ears);
else
  agc = [];
end

if nargout > 6
  for ear = 1:n_ears
    if ~isfield(CF.ears(ear).IHC_state, 'cap1_voltage')
      error('To get the IHC potential, please use the two-cap version.')
    end
  end

  ihc_potential = zeros(n_samp, n_ch, n_ears);
else
  ihc_potential = [];
end

for seg_num = 1:n_segs
  if seg_num == n_segs
    % The last segement may be short of seglen, but do it anyway:
    k_range = (seglen*(seg_num - 1) + 1):n_samp;
  else
    k_range = seglen*(seg_num - 1) + (1:seglen);
  end
  % Process a segment to get a slice of decim_naps, and plot AGC state:
  if ~isempty(ihc_potential)
    [seg_naps, CF, seg_BM, seg_ohc, seg_agc, seg_ihc_potential] = local_runsegment(...
      CF, input_waves(k_range, :));
  elseif ~isempty(BM)
    [seg_naps, CF, seg_BM, seg_ohc, seg_agc] = local_runsegment(...
      CF, input_waves(k_range, :));
  else
    [seg_naps, CF] = local_runsegment(CF, input_waves(k_range, :));
  end

  if ~isempty(BM)
    for ear = 1:n_ears
      % Accumulate segment BM to make full BM
      BM(k_range, :, ear) = seg_BM(:, :, ear);
    end
  end

  if ~isempty(naps)
    for ear = 1:n_ears
      % Accumulate segment naps to make full naps
      naps(k_range, :, ear) = seg_naps(:, :, ear);
    end
  end

  if ~isempty(ohc)
    for ear = 1:n_ears
      % Accumulate segment naps to make full naps
      ohc(k_range, :, ear) = seg_ohc(:, :, ear);
    end
  end

  if ~isempty(agc)
    for ear = 1:n_ears
      % Accumulate segment naps to make full naps
      agc(k_range, :, ear) = seg_agc(:, :, ear);
    end
  end

  if ~isempty(decim_naps)
    for ear = 1:n_ears
      decim_naps(seg_num, :, ear) = CF.ears(ear).IHC_state.ihc_accum / ...
        seglen;
      CF.ears(ear).IHC_state.ihc_accum = zeros(n_ch,1);
    end
  end

  if ~isempty(ihc_potential)
    for ear = 1:n_ears
      % Accumulate segment IHC capacitor voltage to make full IHC vector
      ihc_potential(k_range, :, ear) = seg_ihc_potential(:, :, ear);
    end
  end

%   PM: This functionality does plotting while calculating. Consider doing that when flags are implemented.
%   if AGC_plot_fig_num
%     figure(AGC_plot_fig_num); hold off; clf
%     maxmax = 0;
%     for ear = 1:n_ears
%       hold on
%       for stage = 1:4
%         stage_response = 2^(stage-1) * CF.ears(ear).AGC_state(stage).AGC_memory;
%         plot(stage_response);
%         maxmax = max(maxmax, max(stage_response));
%       end
%     end
%     axis([0, CF.n_ch+1, 0.0, maxmax * 1.01 + 0.002]);
%     drawnow
%   end

end  % segment loop
return


function [naps, CF, BM, seg_ohc, seg_agc, seg_ihc_potential] = local_runsegment(...
  CF, input_waves)
% This function runs the CARFAC; that is, filters a 1 or more channel
% sound input segment to make one or more neural activity patterns (naps);
% it can be called multiple times for successive segments of any length,
% as long as the returned CF with modified state is passed back in each
% time.
%
% input_waves is a column vector if there's just one audio channel;
% more generally, it has a row per time sample, a column per audio channel.
%
% naps has a row per time sample, a column per filterbank channel, and
% a layer per audio channel if more than 1.
% BM is basilar membrane motion (filter outputs before detection).
%
% the input_waves are assumed to be sampled at the same rate as the
% CARFAC is designed for; a resampling may be needed before calling this.
%
% The function works as an outer iteration on time, updating all the
% filters and AGC states concurrently, so that the different channels can
% interact easily.  The inner loops are over filterbank channels, and
% this level should be kept efficient.
%
% seg_ohc seg_agc are optional extra outputs useful for seeing what the
% ohc nonlinearity and agc are doing; both in terms of extra damping.
%
% seg_ihc_potential is also optional, and is used for getting the internal IHC
% state, comparable to the IHC potential.

if nargout > 2
  do_BM = 1;
else
  do_BM = 0;
end

[n_samp, n_ears] = size(input_waves);

if n_ears ~= CF.n_ears
  error('bad number of input_waves channels passed to CARFAC_Run_Segment')
end

if ~isfield(CF, 'open_loop')  % Find open_loop in CF or default it.
  CF.open_loop = 0;
end

if ~isfield(CF, 'linear_car')  % Find linear in CF or default it.
  CF.linear_car = 0;
end

if ~isfield(CF, 'use_delay_buffer')  % To let CAR be fully parallel.
  CF.use_delay_buffer = 0;
end

n_ch = CF.n_ch;
naps = zeros(n_samp, n_ch, n_ears);  % allocate space for result
if do_BM
  BM = zeros(n_samp, n_ch, n_ears);
  seg_ohc = zeros(n_samp, n_ch, n_ears);
  seg_agc = zeros(n_samp, n_ch, n_ears);
end

if nargout > 5
  seg_ihc_potential = zeros(n_samp, n_ch, n_ears);
else
  seg_ihc_potential = [];
end

% A 2022 addition to make open-loop running behave.  In open_loop mode, these
% coefficients are set, per AGC filter outputs, when we CARFAC_Close_AGC_Loop
% on AGC filter output updates.  They drive the zB and g coefficients to the
% intended value by the next update, but if open_loop they would just keep
% going, extrapolating.  The point of open_loop mode is to stop them moving,
% so we need to make sure these deltas are zeroed in case the mode is switched
% from closed to open, as in some tests to evaluate the transfer functions
% before and after adapting to a signal.
if CF.open_loop
  % The interpolators may be running if it was previously run closed loop.
  for ear = 1:CF.n_ears
    CF.ears(ear).CAR_state.dzB_memory = 0;  % To stop intepolating zB.
    CF.ears(ear).CAR_state.dg_memory = 0;  % To stop intepolating g.
  end
end

% Apply control coeffs to where they are needed.
for ear = 1:CF.n_ears
  CF.ears(ear).CAR_coeffs.linear = CF.linear_car;  % Skip OHC nonlinearity.
  CF.ears(ear).CAR_coeffs.use_delay_buffer = CF.use_delay_buffer;
end

%detects = zeros(n_ch, n_ears);
for k = 1:n_samp
  % at each time step, possibly handle multiple channels
  for ear = 1:n_ears

    [car_out, CF.ears(ear).CAR_state] = lyon2024_carstep( ...
      input_waves(k, ear), CF.ears(ear).CAR_coeffs, ...
      CF.ears(ear).CAR_state);

      % update IHC state & output on every time step, too
    [ihc_out, CF.ears(ear).IHC_state] = lyon2024_ihcstep( ...
      car_out, CF.ears(ear).IHC_coeffs, CF.ears(ear).IHC_state); 

      % run the AGC update step, decimating internally,
    [CF.ears(ear).AGC_state, AGC_updated] = lyon2024_agcstep( ...
      ihc_out, CF.ears(ear).AGC_coeffs, CF.ears(ear).AGC_state);

    % save some output data:
    naps(k, :, ear) = ihc_out;  % output to neural activity pattern
    if do_BM
      BM(k, :, ear) = car_out;
      state = CF.ears(ear).CAR_state;
      seg_ohc(k, :, ear) = state.zA_memory;
      seg_agc(k, :, ear) = state.zB_memory;
    end

    if ~isempty(seg_ihc_potential)
      seg_ihc_potential(k, :, ear) = 1 - CF.ears(ear).IHC_state.cap1_voltage;
    end
  end

    % connect the feedback from AGC_state to CAR_state when it updates;
    % do it for all ears together due to potential mixing across them
  if AGC_updated
    
    if n_ears > 1
        % do multi-aural cross-coupling: mix the stages that updated (leading stages at phase 0)
        % The following for loop corresponds to the CARFAC_Cross_Couple file in the original implementation. 
      n_stages = CF.ears(1).AGC_coeffs(1).n_AGC_stages;
      for stage = 1:n_stages
        if CF.ears(1).AGC_state(stage).decim_phase > 0
          break  % all recently updated stages are finished
        else
          mix_coeff = CF.ears(1).AGC_coeffs(stage).AGC_mix_coeffs;
          if mix_coeff > 0  % Typically stage 1 has 0 so no work on that one.
            this_stage_sum = 0;
              % sum up over the ears and get their mean:
            for ear = 1:n_ears
              stage_state = CF.ears(ear).AGC_state(stage).AGC_memory;
              this_stage_sum = this_stage_sum + stage_state;
            end
            this_stage_mean = this_stage_sum / n_ears;
            % now move them all toward the mean:
            for ear = 1:n_ears
              stage_state = CF.ears(ear).AGC_state(stage).AGC_memory;
              CF.ears(ear).AGC_state(stage).AGC_memory = ...
                stage_state +  mix_coeff * (this_stage_mean - stage_state);
            end
          end
        end
      end
    end
    
    if ~CF.open_loop
        % Starts the interpolation of zB and g.
      decim1 = CF.AGC_params.decimation(1);
      for ear = 1:CF.n_ears
        undamping = 1 - CF.ears(ear).AGC_state(1).AGC_memory; % stage 1 result
          % degrade the OHC active undamping if the ear is less than healthy:
        undamping = undamping .* CF.ears(ear).CAR_coeffs.OHC_health;
          % Update the target stage gain for the new damping. 
		  % This corresponds to CARFAC_Stage_g in the original implementation. 
        new_g = CF.ears(ear).CAR_coeffs.ga_coeffs .* (undamping.^2) + ...
                CF.ears(ear).CAR_coeffs.gb_coeffs .* undamping + CF.ears(ear).CAR_coeffs.gc_coeffs;
          % set the deltas needed to get to the new damping:
        CF.ears(ear).CAR_state.dzB_memory = ...
          (CF.ears(ear).CAR_coeffs.zr_coeffs .* undamping - ...
          CF.ears(ear).CAR_state.zB_memory) / decim1;
        CF.ears(ear).CAR_state.dg_memory = ...
          (new_g - CF.ears(ear).CAR_state.g_memory) / decim1;
      end
    end
  end
end


