function nlf = lyon2011_ohcnlf(velocities, CAR_coeffs)
%lyon2011_ohcnlf Velocity after OHC processing
%
%   Usage:
%     nlf = lyon2011_ohcnlf(velocities, CAR_coeffs)
%
%   Input parameters:
%     velocities : input velocities
%     CAR        : struct, CAR coefficients
%
%   Output parameters:
%     nlf        : velocity after OHC processing
%
%   LYON2011_OHCNLF approximates the velocity after outer
%   hair cell processing. It starts with a quadratic nonlinear 
%   function, and limits it via a
%   rational function; results are enforced to go to zero at high
%   absolute velocities, so it will do nothing there.
%
%   See also:  lyon2011 demo_lyon2011
%
%   References:
%     R. F. Lyon. Cascades of two-pole–two-zero asymmetric resonators are
%     good models of peripheral auditory function. The Journal of the
%     Acoustical Society of America, 130(6), 2011.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_ohcnlf.php


%   #StatusDoc: Submitted
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

% This file is licensed unter the Apache License Version 2.0 which details can
% be found in the AMT directory "licences" and at
% <http://www.apache.org/licenses/LICENSE-2.0>.
% You must not use this file except in compliance with the Apache License
% Version 2.0. Unless required by applicable law or agreed to in writing, this
% file is distributed on an "as is" basis, without warranties or conditions
% of any kind, either express or implied.


nlf = 1 ./ (1 + ...
  (velocities * CAR_coeffs.velocity_scale + CAR_coeffs.v_offset) .^ 2 );



