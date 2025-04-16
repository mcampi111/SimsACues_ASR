function CF = lyon2011_closeagcloop(CF)
%lyon2011_closeagcloop Active gain control loop
%   Usage: [CF, decim_naps, naps, BM, ohc, agc] = lyon2011_closeagcloop(CF,input_waves, AGC_plot_fig_num, open_loop);
%
%
%   Input parameters:
%     CF              : Structure with the filterbank design and
%                       state; if you want to break the input up into
%                       segments, you need to use the updated CF
%                       to keep the state between segments.
%
%   Output parameters:
%     CF              : Updated structure
%
%
%   See also: lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_closeagcloop.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2022): degrade the OHC active undamping if the ear is less than healthy
%   #Author: Mihajlo Velimirovic (2022): unused code removed
%   #Author: Piotr Majdak (2024): clean up and doc clarifications for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

% fastest decimated rate determines interp needed:
decim1 = CF.AGC_params.decimation(1);

for ear = 1:CF.n_ears
  undamping = 1 - CF.ears(ear).AGC_state(1).AGC_memory; % stage 1 result
  % degrade the OHC active undamping if the ear is less than healthy:
  undamping = undamping .* CF.ears(ear).CAR_coeffs.OHC_health;
  % Update the target stage gain for the new damping:
  new_g = lyon2011_stageg(CF.ears(ear).CAR_coeffs, undamping);

  % set the deltas needed to get to the new damping:
  CF.ears(ear).CAR_state.dzB_memory = ...
    (CF.ears(ear).CAR_coeffs.zr_coeffs .* undamping - ...
    CF.ears(ear).CAR_state.zB_memory) / decim1;
  CF.ears(ear).CAR_state.dg_memory = ...
    (new_g - CF.ears(ear).CAR_state.g_memory) / decim1;
end


