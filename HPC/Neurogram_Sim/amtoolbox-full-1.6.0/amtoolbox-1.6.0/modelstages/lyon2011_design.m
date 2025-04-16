function CF = lyon2011_design(n_ears, fs, CF_CAR_params, CF_AGC_params, CF_IHC_params)
%lyon2011_design Computes all the coefficients needed to run the model
%
%   Usage:
%     CF = lyon2011_design(n_ears, fs, CF_CAR_params, CF_AGC_params, CF_IHC_params)
%
%
%   Input parameters:
%     n_ears        : Number of input signals
%     fs            : Sampling frequency (Hz)
%     CF_CAR_params : A struct with the pole-zero filter cascade parameters
%     CF_AGC_params : A struct with the automatic gain control parameters
%     CF_IHC_params : A struct with the inner hair cell parameters
%
%   Output parameters:
%     CF            : filter coefficients
%
%
%   CF_CAR_params consists of the following field, among others:
%
%     'ac_corner_Hz',ac_corner_Hz  Corner frequency (Hz) of the high-pass filter in the 
%                                  CAR stage (e.g., at basilar membrane). Set ac_corner_Hz 
%                                  to a non-zero to enable the filter in CAR stage. 
%                                  Set ac_corner_Hz to 0 to disable the filter. 
%                                  Default is 0, i.e., enabled in the IHC stage.
%                                  The filter should be enabled either in CAR or IHC stage. 
%
%
%   CF_IHC_params consists of the following field, among others:
%
%     'ac_corner_Hz',ac_corner_Hz  Corner frequency (Hz) of the high-pass filter in the 
%                                  IHC stage. Set ac_corner_Hz 
%                                  to a non-zero to enable the filter in IHC stage. 
%                                  Set ac_corner_Hz to 0 to disable the filter. 
%                                  Default is 20, i.e., enabled in the IHC stage.
%                                  The filter should be enabled either in CAR or IHC stage. 
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_design.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2022): Addition of open_loop, linear_car, OHC_health, and a new design strategy
%   #Author: Mihajlo Velimirovic (2023): Addition of ac_coeff and a new way of calculating the decimation
%   #Author: Mihajlo Velimirovic (2023): Local functions removed and support for lyon2024 added. 
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

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
    'ac_corner_Hz', 0); % to enable high-pass filter in CAR stage, set to 20.
end

if nargin < 4
  CF_AGC_params = struct( ...
    'n_stages', 4, ...
    'time_constants', 0.002 * 4.^(0:3), ...
    'AGC_stage_gain', 2, ...  % gain from each stage to next slower stage
    'decimation', [8, 2, 2, 2], ...  % how often to update the AGC states
    'AGC1_scales', 1.0 * sqrt(2).^(0:3), ...   % in units of channels
    'AGC2_scales', 1.65 * sqrt(2).^(0:3), ... % spread more toward base
    'AGC_mix_coeff', 0.5);
end

if nargin < 5
  % HACK: these constants control the defaults
  one_cap = 1;         % bool; 1 for Allen model, as text states we use
  just_hwr = 0;        % bool; 0 for normal/fancy IHC; 1 for HWR

  CF_IHC_params = struct( ...
    'just_hwr', just_hwr, ...  % not just a simple HWR
    'one_cap', one_cap, ...    % bool; 0 for new two-cap hack
    'ac_corner_Hz', 20, ...    % to enable high-pass in IHC, set to 20
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
CAR_coeffs = lyon2011_designfilters(CF_CAR_params, fs, pole_freqs);
AGC_coeffs = lyon2011_designagc(CF_AGC_params, fs, n_ch);
IHC_coeffs = lyon2011_designihc(CF_IHC_params, fs, n_ch);

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

