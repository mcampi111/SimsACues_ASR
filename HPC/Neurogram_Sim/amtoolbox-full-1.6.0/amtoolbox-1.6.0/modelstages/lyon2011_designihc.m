function IHC_coeffs = lyon2011_designihc(IHC_params, fs, n_ch)
%lyon2011_designihc Computes the IHC coefficients
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_designihc.php


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

  if IHC_params.just_hwr
    IHC_coeffs = struct( ...
      'n_ch', n_ch, ...
      'just_hwr', 1, ...
      'ac_coeff', 2 * pi * IHC_params.ac_corner_Hz / fs);
  else
    if IHC_params.one_cap
      gmax = lyon2011_detect(10);  % output conductance at a high level
      rmin = 1 / gmax;
      c = IHC_params.tau_out * gmax;
      ri = IHC_params.tau_in / c;
      % to get approx steady-state average, double rmin for 50% duty cycle
      saturation_current = 1 / (2/gmax + ri);
      % also consider the zero-signal equilibrium:
      g0 = lyon2011_detect(0);
      r0 = 1 / g0;
      rest_current = 1 / (ri + r0);
      cap_voltage = 1 - rest_current * ri;
      IHC_coeffs = struct( ...
        'n_ch', n_ch, ...
        'just_hwr', 0, ...
        'ac_coeff', 2 * pi * IHC_params.ac_corner_Hz / fs, ...
        'lpf_coeff', 1 - exp(-1/(IHC_params.tau_lpf * fs)), ...
        'out_rate', rmin / (IHC_params.tau_out * fs), ...
        'in_rate', 1 / (IHC_params.tau_in * fs), ...
        'one_cap', IHC_params.one_cap, ...
        'output_gain', 1 / (saturation_current - rest_current), ...
        'rest_output', rest_current / (saturation_current - rest_current), ...
        'rest_cap', cap_voltage);
    else
      g1max = lyon2011_detect(10);  % receptor conductance at high level
      r1min = 1 / g1max;
      c1 = IHC_params.tau1_out * g1max;  % capacitor for min depletion tau
      r1 = IHC_params.tau1_in / c1;  % resistance for recharge tau
      % to get approx steady-state average, double r1min for 50% duty cycle
      saturation_current1 = 1 / (2*r1min + r1);  % Approximately.
      % also consider the zero-signal equilibrium:
      g10 = lyon2011_detect(0);
      r10 = 1/g10;
      rest_current1 = 1 / (r1 + r10);
      cap1_voltage = 1 - rest_current1 * r1;  % quiescent/initial state

      % Second cap similar, but using receptor voltage as detected signal.
      max_vrecep = r1 / (r1min + r1);  % Voltage divider from 1.
      % Identity from receptor potential to neurotransmitter conductance:
      g2max = max_vrecep;  % receptor resistance at very high level
      r2min = 1 / g2max;
      c2 = IHC_params.tau2_out * g2max;  % capacitor for min depletion tau
      r2 = IHC_params.tau2_in / c2;  % resistance for recharge tau
      % to get approx steady-state average, double r2min for 50% duty cycle
      saturation_current2 = 1 / (2 * r2min + r2);
      % also consider the zero-signal equilibrium:
      rest_vrecep = r1 * rest_current1;
      g20 = rest_vrecep;
      r20 = 1 / g20;
      rest_current2 = 1 / (r2 + r20);
      cap2_voltage = 1 - rest_current2 * r2;  % quiescent/initial state

      IHC_coeffs = struct(...
        'n_ch', n_ch, ...
        'just_hwr', 0, ...
        'ac_coeff', 2 * pi * IHC_params.ac_corner_Hz / fs, ...
        'lpf_coeff', 1 - exp(-1/(IHC_params.tau_lpf * fs)), ...
        'out1_rate', r1min / (IHC_params.tau1_out * fs), ...
        'in1_rate', 1 / (IHC_params.tau1_in * fs), ...
        'out2_rate', r2min / (IHC_params.tau2_out * fs), ...
        'in2_rate', 1 / (IHC_params.tau2_in * fs), ...
        'one_cap', IHC_params.one_cap, ...
        'output_gain', 1 / (saturation_current2 - rest_current2), ...
        'rest_output', rest_current2 / (saturation_current2 - rest_current2), ...
        'rest_cap2', cap2_voltage, ...
        'rest_cap1', cap1_voltage);
    end
  end
