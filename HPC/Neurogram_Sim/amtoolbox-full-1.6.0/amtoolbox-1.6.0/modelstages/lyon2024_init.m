function CF = lyon2024_init(CF)
%lyon2024_init Initialize the CARFAC v2 model
%
%   Usage:
%     CF = lyon2024_init(CF)
%
%   Input parameters: 
%     CF: Structure with the model parameters as output from LYON2024_DESIGN.
%
%   Output parameters: 
%     CF: Initialized structure, ready to be processed by the model LYON2024. 
%
%   LYON2024_INIT(..) allocates the state vector storage in the CF structure
%   for one or more ears of CF. 
%
%
%   See also:  lyon2024 lyon2024_design
%
%   References:
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2024_init.php


%   #StatusDoc: OK
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): Original implementation, as lyon2011_init (https://github.com/google/carfac).
%   #Author: Amin Saremi (2016): Adaptations for the AMT, as lyon2011_init.
%   #Author: Clara Hollomey (2021): Integration in the AMT 1.0, as lyon2011_init.
%   #Author: Mihajlo Velimirovic (2023): Unused code removed, local functions renamed, as lyon2011_init.
%   #Author: Piotr Majdak (2024): Copied from lyon2011_init, adaptations for lyon2024 for AMT 1.6.

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.



n_ears = CF.n_ears;

for ear = 1:n_ears
  % for now there's only one coeffs, not one per ear
  CF.ears(ear).CAR_state = local_carinitstate(CF.ears(ear).CAR_coeffs);
  CF.ears(ear).IHC_state = local_ihcinitstate(CF.ears(ear).IHC_coeffs);
  CF.ears(ear).AGC_state = local_agcinitstate(CF.ears(ear).AGC_coeffs);
end


function state = local_carinitstate(coeffs)
n_ch = coeffs.n_ch;
state = struct( ...
  'z1_memory', zeros(n_ch, 1), ...
  'z2_memory', zeros(n_ch, 1), ...
  'zA_memory', zeros(n_ch, 1), ...
  'zB_memory', coeffs.zr_coeffs, ...
  'dzB_memory', zeros(n_ch, 1), ...
  'zY_memory', zeros(n_ch, 1), ...
  'g_memory', coeffs.g0_coeffs, ...
  'dg_memory', zeros(n_ch, 1), ...
  'ac_coupler', zeros(n_ch, 1));


function state = local_agcinitstate(coeffs)
n_ch = coeffs(1).n_ch;
n_AGC_stages = coeffs(1).n_AGC_stages;
state = struct([]);
for stage = 1:n_AGC_stages
  % Initialize state recursively...
  state(stage).AGC_memory = zeros(n_ch, 1);
  state(stage).input_accum = zeros(n_ch, 1);
  state(stage).decim_phase = 0;  % integer decimator phase
end


function state = local_ihcinitstate(coeffs)
n_ch = coeffs.n_ch;
if coeffs.just_hwr
  state = struct( ...
    'ihc_accum', zeros(n_ch, 1), ...
    'ac_coupler', zeros(n_ch, 1) ...
    );
else
  if coeffs.one_cap
    state = struct( ...
      'ihc_accum', zeros(n_ch, 1), ...
      'cap_voltage', coeffs.rest_cap * ones(n_ch, 1), ...
      'lpf1_state', coeffs.rest_output * ones(n_ch, 1), ...
      'lpf2_state', coeffs.rest_output * ones(n_ch, 1), ...
      'ac_coupler', zeros(n_ch, 1) ...
      );
  else
    state = struct( ...
      'ihc_accum', zeros(n_ch, 1), ...
      'cap1_voltage', coeffs.rest_cap1 * ones(n_ch, 1), ...
      'cap2_voltage', coeffs.rest_cap2 * ones(n_ch, 1), ...
      'lpf1_state', coeffs.rest_output * ones(n_ch, 1), ...
      'ac_coupler', zeros(n_ch, 1) ...
      );
  end
end




