function stage_g = lyon2011_stageg(CAR_coeffs, undamping)
% lyon2011_stageg Obtain unity gain
%
%   Usage:
%     stage_g = lyon2011_stageg(CAR_coeffs, undamping)
%
%   Input parameters:
%     CAR_coeffs         : struct containing the CARFAC coefficients
%     undamping          : relative undamping
%
%   Output parameters:
%     stage_g            : gain
%
%   LYON2011_STAGEG returns the stage gain g needed to get unity gain at DC.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_stageg.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Mihajlo Velimirovic (2023): unused code removed
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.


% Return the stage gain g needed to get unity gain at DC,
% using a quadratic approximation.

stage_g = CAR_coeffs.ga_coeffs .* (undamping.^2) + ...
    CAR_coeffs.gb_coeffs .* undamping + CAR_coeffs.gc_coeffs;
