function stage_state = lyon2011_spatialsmooth(coeffs, stage_state)
%lyon2011_spatialsmooth Spatial smoothing using FIR coefficients
%
%   Usage: stage_state = lyon2011_spatialsmooth(coeffs, stage_state)
%
%   Input parameters:
%     coeffs      : structure with all coefficients, containing 
%                   the field AGC_spatial_FIR from the AGC stage. 
%                   This field needs to be an array 
%                   with 3 entries containing the FIR coefficients.
%     stage_state : state to be smoothed
%
%   Output parameters:
%     stage_state : smoothed state
%
%   LYON2011_SPATIALSMOOTH performs spatial smoothing. 
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_spatialsmooth.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2023): Removed the consideration of AGC_spatial_n_taps, works for 3 taps only
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can 
% be found in the AMT directory "licences" and at 
% <http://www.apache.org/licenses/LICENSE-2.0>. 
% You must not use this file except in compliance with the Apache License 
% Version 2.0. Unless required by applicable law or agreed to in writing, this 
% file is distributed on an "as is" basis, without warranties or conditions 
% of any kind, either express or implied.

% 1 iteration, 3-tap FIR.
% ignore n_iterations, implicitly 1; ignore AGC_spatial_n_taps, too.
FIR_coeffs = coeffs.AGC_spatial_FIR;
% Just mix in some left and right neighbors like in book figure 19.6:
stage_state = ...
  FIR_coeffs(1) * stage_state([1, 1:(end-1)], :) + ...
  FIR_coeffs(2) * stage_state + ...
  FIR_coeffs(3) * stage_state([2:end, end], :);

