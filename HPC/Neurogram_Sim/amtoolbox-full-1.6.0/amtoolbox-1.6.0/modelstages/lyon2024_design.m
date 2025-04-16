function CF = lyon2024_design(n_ears, fs, one_cap, ihc_high_pass, CF_CAR_params, CF_AGC_params, CF_IHC_params)
%lyon2024_design Provides default coefficients needed to run the model
%
%   Usage:
%     CF = lyon2024_design(n_ears, fs, one_cap, ihc_high_pass, CF_CAR_params, CF_AGC_params, CF_IHC_params)
%
%
%   Input parameters:
%     n_ears        : Number of audio channels, i.e, ears.
%     fs            : Sampling frequency (in Hz) of the model and the audio signals.
%     one_cap       : Optional flag for using a single capacitor in the network. 
%                     Default: 0 (i.e., use two capacitors).
%                     Used only if CF_IHC_params is not set.
%     ihc_high_pass : Optional flag showing how the AC will be coupled,
%                     Used only if CF_IHC_params is not set.
%
%                     - 1: AC coupling will be done at the IHC stage. Default. 
%
%                     - 0: AC coupling will be done in the CAR stage as in LYON2011.
%                     
%     CF_CAR_params : Structure with the pole-zero filter cascade parameters
%                     with the following fields: 
% 
%                     - velocity_scale*: Velocity nonlinearity. Default: 0.1.
%
%                     - v_offset*: Offset gives a quadratic part. Default: 0.04.
%
%                     - min_zeta*: Minimum damping factor in mid-freq channels. Default: 0.10.
%
%                     - max_zeta*: Maximum damping factor in mid-freq channels. Default: 0.35.
%
%                     - first_pole_theta*: Meaning unclear. Default: 0.85pi.
%
%                     - zero_ratio*: Distance of a zero above a pole. Default: sqrt(2).
%
%                     - high_f_damping_compression*: Scaling (between 0 and 1) of the zeta compression. Default: 0.5.
%
%                     - ERB_per_step*: Number of frequency channels per EERB. Default: 0.5.
%
%                     - min_pole_Hz*: Lowest frequency (in Hz). Default: 30 Hz.
%
%                     - ERB_break_freq*: Greenwood map's break frequency (Unit unclear). Default: 165.3.
%
%                     - ERB_Q*: Glasberg and Moore's high-CF ratio. Default: 1000/(24.7*4.37).
%
%                     - ac_corner_Hz*: Corner frequency (in Hz) of the high-pass filter in the
%                       CAR stage (e.g., at basilar membrane). Set ac_corner_Hz*
%                       to a non-zero to enable the filter in CAR stage.
%                       Set ac_corner_Hz to 0 to disable the filter.
%                       Default: 0 (i.e., enabled in the CAR stage).
%
%     CF_AGC_params : Structure with the automatic gain control parameters:
%
%                     - n_stages*: Number of AGC stages. Default: 4.
%
%                     - time_constants*: Time constants of the AGC stages. 
%                       Default: 0.002 4^{([0, 1, 2, 3])}.
%
%                     - AGC_stage_gain*: Gain of each stage to next slower stage.
%                       Default: 2.
%
%                     - decimation*: How often to update the AGC states. 
%                       Default: [8, 2, 2, 2].
%
%                     - AGC1_scales*: Scales (in units of channels) of the 
%                       AGC1 stages. Default: {sqrt 2} ^ {([0, 1, 2, 3])}. 
%
%                     - AGC2_scales*: Scales (in units of channels) of the 
%                       AGC2 stages. Default: {1.65 sqrt 2} ^ {([0, 1, 2, 3])}. 
%      
%                     - AGC_mix_coeff*: Mix of the AGCs (meaning unclear).
%                       Default: 0.5.
%
%     CF_IHC_params : Structure with the inner hair cell parameters:
%
%                     - just_hwr*: The mode of the IHC processing: 
%
%                       - 0: Normal IHC processing as described in Lyon et al. (2024). 
%                         Default. 
% 
%                       - 1: Simplified IHC processing by using a simple 
%                         half-way rectification. 
%                  
%                     - one_cap*: As in the input parameter one_cap.
%
%                     - ac_corner_Hz*: Corner frequency (in Hz) of the IHC.
%                       If 0, it the high-pass will be done in the CAR stage.
%                       Default: If ihc_high_pass is 0, ac_corner_Hz will be 0 Hz. 
%                       If ihc_high_pass is 1, ac_corner_Hz will be 20 Hz. 
%
%                     - tau_lpf*: Meaning unclear (in s). Default: 80 microseconds.
%
%                     - tau_out*: Depletion, meaning unclear (in s). Default: 0.5 ms.
%
%                     - tau_in*: Recovery, meaning unclear (in s). Default: 0.01.
%
%                     - tau1_out*: Depletion, meaning unclear (in s). Default: 0.5 ms.
%
%                     - tau1_in*: Recovery, meaning unclear (in s). Default: 0.2 ms.
%
%                     - tau2_out*: Depletion, meaning unclear (in s). Default: 1 ms. 
%
%                     - tau2_in*: Recovery, meaning unclear (in s). Default: 10 ms.
%
%
%   Output parameters:
%     CF: Structure containing all filter coefficients: 
%
%         - fs*: Sampling frequency (in Hz). 
%
%         - max_channels_per_octave*: Number of frequency channels per octave. 
%
%         - CAR_params*: Structure with the pole-zero filter cascade parameters. 
%           Fields as in CF_CAR_params. 
%         
%         - AGC_params*: Structure with the automatic gain control parameters. 
%           Fields as CF_AGC_params. 
%
%         - IHC_params*: Structure with the inner hair cell parameters. 
%           Fields as in CF_IHC_params. 
%         
%         - n_ch*: Number of frequency channels. 
%
%         - pole_freqs*: Vector with center frequencies (in Hz). Length: n_ch. 
%
%         - ears*: Structure array containing the parameters and states. Per ear, 
%           the following fields are output: 
%
%           - CAR_coeffs*: Output from LYON2024_DESIGNFILTERS.
%
%           - AGC_coeffs*: Output from LYON2024_DESIGNAGC.
%
%           - IHC_coeffs*: Output from LYON2024_DESIGNIHC.
%
%         - n_ears*: Number of ears to be processed. 
%
%         - open_loop*: 0, meaning unclear. 
%
%         - linear_car*: 0, meaning unclear. 
%
%                   
%
%   See also:  lyon2024_init lyon2024 exp_lyon2024
%
%   References:
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2024_design.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Qualified
%   #License: Apache2
%   #Author: Mihajlo Velimirovic (2023): Implementation in the AMT based on lyon2011_design.
%   #Author: Piotr Majdak (2024): Copied from lyon2011, adaptations for lyon2024 for AMT 1.6.

%   This file is licensed unter the Apache License Version 2.0 which details can
%   be found in the AMT directory "licences" and at
%   <http://www.apache.org/licenses/LICENSE-2.0>.
%   You must not use this file except in compliance with the Apache License
%   Version 2.0. Unless required by applicable law or agreed to in writing, this
%   file is distributed on an "as is" basis, without warranties or conditions
%   of any kind, either express or implied.


if nargin < 1
  n_ears = 1;  % if more than 1, make them identical channels;
  % then modify the design if necessary for different reasons
end

if nargin < 2
  fs = 22050;
end

if nargin < 3
  one_cap = 0;
end

if nargin < 4
  ihc_high_pass = 0;
end

if nargin < 5
  car_ac_corner_Hz = 0;
  if ~ihc_high_pass
    car_ac_corner_Hz = 20;
  end
  CF_CAR_params = struct( ...
    'velocity_scale', 0.1, ...  % for the velocity nonlinearity
    'v_offset', 0.04, ...  % offset gives a quadratic part
    'min_zeta', 0.10, ... % minimum damping factor in mid-freq channels
    'max_zeta', 0.35, ... % maximum damping factor in mid-freq channels
    'first_pole_theta', 0.85*pi, ...
    'zero_ratio', sqrt(2), ... % how far zero is above pole
    'high_f_damping_compression', 0.5, ... % 0 to 1 to compress zeta
    'ERB_per_step', 0.5, ... % assume G&M's ERB formula
    'min_pole_Hz', 30, ...
    'ERB_break_freq', 165.3, ...  % 165.3 is Greenwood map's break freq.
    'ERB_Q', 1000/(24.7*4.37), ...  % Glasberg and Moore's high-cf ratio
    'ac_corner_Hz', car_ac_corner_Hz);  % to enable high-pass filter in CAR stage, set to 20.
end

if nargin < 6
  CF_AGC_params = struct( ...
    'n_stages', 4, ...
    'time_constants', 0.002 * 4.^(0:3), ...
    'AGC_stage_gain', 2, ...  % gain from each stage to next slower stage
    'decimation', [8, 2, 2, 2], ...  % how often to update the AGC states
    'AGC1_scales', 1.0 * sqrt(2).^(0:3), ...   % in units of channels
    'AGC2_scales', 1.65 * sqrt(2).^(0:3), ... % spread more toward base
    'AGC_mix_coeff', 0.5);
end

if nargin < 7
  % HACK: these constants control the defaults
  just_hwr = 0;        % bool; 0 for normal/fancy IHC; 1 for HWR
  if ihc_high_pass
    ihc_ac_corner_Hz = 20;
  else
    ihc_ac_corner_Hz = 0;
  end
  CF_IHC_params = struct( ...
    'just_hwr', just_hwr, ...  % not just a simple HWR
    'one_cap', one_cap, ...    % bool; 0 for new two-cap hack
    'ac_corner_Hz', ihc_ac_corner_Hz, ... % to enable high-pass in IHC, set to 20
    'tau_lpf', 0.000080, ...   % 80 microseconds smoothing twice
    'tau_out', 0.0005, ...     % depletion tau is pretty fast
    'tau_in', 0.010, ...       % recovery tau is slower
    'tau1_out', 0.000500, ...  % depletion tau is fast 500 us
    'tau1_in', 0.000200, ...   % recovery tau is very fast 200 us
    'tau2_out', 0.001, ...     % depletion tau is pretty fast 1 ms
    'tau2_in', 0.010);         % recovery tau is slower 10 ms
end


% first figure out how many filter stages (PZFC/CARFAC channels):
pole_Hz = CF_CAR_params.first_pole_theta * fs / (2*pi);
n_ch = 0;
while pole_Hz > CF_CAR_params.min_pole_Hz
  n_ch = n_ch + 1;
  pole_Hz = pole_Hz - CF_CAR_params.ERB_per_step * ...
    f2erb(pole_Hz, CF_CAR_params.ERB_break_freq, CF_CAR_params.ERB_Q);
end
% Now we have n_ch, the number of channels, so can make the array
% and compute all the frequencies again to put into it:
pole_freqs = zeros(n_ch, 1);
pole_Hz = CF_CAR_params.first_pole_theta * fs / (2*pi);
for ch = 1:n_ch
  pole_freqs(ch) = pole_Hz;
  pole_Hz = pole_Hz - CF_CAR_params.ERB_per_step * ...
    f2erb(pole_Hz, CF_CAR_params.ERB_break_freq, CF_CAR_params.ERB_Q);
end
% Now we have n_ch, the number of channels, and pole_freqs array.

max_channels_per_octave = log(2) / log(pole_freqs(1)/pole_freqs(2));

% Convert to include an ear_array, each w coeffs and state...
CAR_coeffs = lyon2024_designfilters(CF_CAR_params, fs, pole_freqs);
AGC_coeffs = lyon2024_designagc(CF_AGC_params, fs, n_ch);
IHC_coeffs = lyon2024_designihc(CF_IHC_params, fs, n_ch); % here we need the lyon2024 version!

if ~xor(CAR_coeffs.ac_coeff > 0, IHC_coeffs.ac_coeff > 0)
  error('ac_corner_Hz should be set at exactly one place (CAR stage or IHC).');
end

% Copy same designed coeffs into each ear (can do differently in the
% future, e.g. for unmatched OHC_health).
for ear = 1:n_ears
  ears(ear).CAR_coeffs = CAR_coeffs;
  ears(ear).AGC_coeffs = AGC_coeffs;
  ears(ear).IHC_coeffs = IHC_coeffs;
end

CF = struct( ...
  'fs', fs, ...
  'max_channels_per_octave', max_channels_per_octave, ...
  'CAR_params', CF_CAR_params, ...
  'AGC_params', CF_AGC_params, ...
  'IHC_params', CF_IHC_params, ...
  'n_ch', n_ch, ...
  'pole_freqs', pole_freqs, ...
  'ears', ears, ...
  'n_ears', n_ears, ...
  'open_loop', 0, ...
  'linear_car', 0);

