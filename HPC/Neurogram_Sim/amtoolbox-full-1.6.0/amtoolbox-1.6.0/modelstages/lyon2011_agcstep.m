function [state, updated] = lyon2011_agcstep(detects, coeffs, state)
%lyon2011_agcstep active gain control step of the CARFAC model
%   Usage: [state, updated] = lyon2011_agcstep(detects, coeffs, state);
%
%   Input parameters:
%     detects     : detection indices
%     coeffs      : filter coefficients
%     state       : struct containing the internal model state
%
%   Output parameters:
%     state       : struct containing the internal model state
%     updated     : flag, indicates if there is new output
%
%   One-time step of the automatic gain control (AGC) state update;
%   decimates internally.
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_agcstep.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2022): revert of the code to better correspond to https://github.com/google/carfac
%   #Author: Clara Hollomey (2021): integration in the AMT 1.3
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.

stage = 1;
AGC_in = coeffs(1).detect_scale * detects;
[state, updated] = local_agcrecurse(coeffs, AGC_in, stage, state);


function [state, updated] = local_agcrecurse(coeffs, AGC_in, ...
  stage, state)
% function [state, updated] = local_agcrecurse(coeffs, AGC_in, ...
%   stage, state)

% decim factor for this stage, relative to input or prev. stage:
decim = coeffs(stage).decimation;
% decim phase of this stage (do work on phase 0 only):
decim_phase = mod(state(stage).decim_phase + 1, decim);
state(stage).decim_phase = decim_phase;

% accumulate input for this stage from detect or previous stage:
state(stage).input_accum = state(stage).input_accum + AGC_in;

% nothing else to do if it's not the right decim_phase
if decim_phase == 0
  % do lots of work, at decimated rate.
  % decimated inputs for this stage, and to be decimated more for next:
  AGC_in = state(stage).input_accum / decim;
  state(stage).input_accum(:) = 0;  % reset accumulator

  if stage < coeffs(1).n_AGC_stages
    state = local_agcrecurse(coeffs, AGC_in, stage+1, state);
    % and add its output to this stage input, whether it updated or not:
    AGC_in = AGC_in + ...
      coeffs(stage).AGC_stage_gain * state(stage + 1).AGC_memory;
  end

  AGC_stage_state = state(stage).AGC_memory;
  % first-order recursive smoothing filter update, in time:
  AGC_stage_state = AGC_stage_state + ...
    coeffs(stage).AGC_epsilon * (AGC_in - AGC_stage_state);
  % spatial smooth:
  AGC_stage_state = ...
    lyon2011_spatialsmooth(coeffs(stage), AGC_stage_state);
  % and store the state back (in C++, do it all in place?)
  state(stage).AGC_memory = AGC_stage_state;

  updated = 1;  % Bool to say we have new output.
else
  updated = 0;
end


