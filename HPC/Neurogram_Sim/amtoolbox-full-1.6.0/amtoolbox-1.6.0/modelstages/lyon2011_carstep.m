function [car_out, state] = lyon2011_carstep(x_in, CAR_coeffs, state)
%lyon2011_carstep One-sample update step of the filtering
%
%   Usage: [car_out, state] = lyon2011_carstep(x_in, CAR_coeffs, state);
%
%   Input parameters:
%     x_in          : Sample of the input signal
%     CAR_coeffs    : Filter coefficients from the filter design
%     state         : Structure with the filter states from the previous step
%
%   Output parameters:
%     car_out       : Filtered output sample
%     state         : Structure with the updated filter states
%
%   LYON2011_CARSTEP updates the filter cascade state taking into account
%   outer hair cell feedback. 
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_carstep.php


%   #StatusDoc: OK
%   #StatusCode: OK
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2023): implementation CAR_coeffs.linear and CAR_coeffs.ac_coeff
%   #Author: Piotr Majdak (2024): clean up and doc clarifications for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

  % do the DOHC stuff:
g = state.g_memory + state.dg_memory;  % interp g
zB = state.zB_memory + state.dzB_memory; % AGC interpolation state
  % update the nonlinear function of "velocity", and zA (delay of z2):
zA = state.zA_memory;
v = state.z2_memory - zA;
if CAR_coeffs.linear
  nlf = 1;
else
  % nlf = CARFAC_OHC_NLF(v .* widen, CAR_coeffs);  % widen v with feedback
  nlf = lyon2011_ohcnlf(v, CAR_coeffs);
end

% zB * nfl is "undamping" delta r:
r = CAR_coeffs.r1_coeffs + zB .* nlf; 
zA = state.z2_memory;

% now reduce state by r and rotate with the fixed cos/sin coeffs:
z1 = r .* (CAR_coeffs.a0_coeffs .* state.z1_memory - ...
  CAR_coeffs.c0_coeffs .* state.z2_memory);
% z1 = z1 + inputs;
z2 = r .* (CAR_coeffs.c0_coeffs .* state.z1_memory + ...
  CAR_coeffs.a0_coeffs .* state.z2_memory);

if isfield(CAR_coeffs, 'use_delay_buffer') && CAR_coeffs.use_delay_buffer
  % To avoid the sequential ripple, use zY as delay per stage.
  % Optional fully-parallel update uses a delay per stage.
  zY = state.zY_memory;
  zY(2:end) = zY(1:(end-1));  % Propagate delayed last outputs zy
  zY(1) = x_in;  % fill in new input
  z1 = z1 + zY;  % add new stage inputs to z1 states
  zY = g .* (CAR_coeffs.h_coeffs .* z2 + zY);  % Outputs from z2
else
  zY = CAR_coeffs.h_coeffs .* z2;  % partial output
  % Ripple input-output path, instead of parallel, to avoid delay...
  % this is the only part that doesn't get computed "in parallel":
  in_out = x_in;
  for ch = 1:length(zY)
    % could do this here, or later in parallel:
    z1(ch) = z1(ch) + in_out;
    % ripple, saving final channel outputs in zY
    in_out = g(ch) * (in_out + zY(ch));
    zY(ch) = in_out;
  end
end

% put new state back in place of old
% (z1 is a genuine temp; the others can update by reference in C)
state.z1_memory = z1;
state.z2_memory = z2;
state.zA_memory = zA;
state.zB_memory = zB;
state.zY_memory = zY;
state.g_memory = g;

% If ac_coeff is positive, AC couple the zY, with 20 Hz corner.
% If ac_coeff is 0 here, it is done in IHC step.
if CAR_coeffs.ac_coeff > 0
  ac_diff = zY - state.ac_coupler;
  state.ac_coupler = state.ac_coupler + CAR_coeffs.ac_coeff * ac_diff;
  car_out = ac_diff;
else
  car_out = zY;
end





