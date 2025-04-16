function [ideal_g] = lyon2011_designstageg(CAR_coeffs, undamping)
% lyon2011_designstageg Obtain unity gain
%
%   Usage:
%     ideal_g = lyon2011_designstageg(CAR_coeffs, undamping)
%
%   Input parameters:
%     CAR_coeffs         : struct containing the CARFAC coefficients
%     undamping          : relative undamping
%
%   Output parameters:
%     ideal_g            : gain
%
%   Return the stage gain g needed to get unity gain at DC
%   See also CARFAC_Stage_g, simplified approximation used at run time,
%   based on quadratic coefficient computed at Design time.
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_designstageg.php


%   #StatusDoc: Submitted
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Mihajlo Velimirovic (2023): integration in the AMT
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.

r1 = CAR_coeffs.r1_coeffs;  % at max damping
a0 = CAR_coeffs.a0_coeffs;
c0 = CAR_coeffs.c0_coeffs;
h  = CAR_coeffs.h_coeffs;
zr = CAR_coeffs.zr_coeffs;
r  = r1 + zr .* undamping;  % r at specified damping
n  = 1 - 2*r.*a0 + r.^2;
d  = 1 - 2*r.*a0 + h.*r.*c0 + r.^2;
ideal_g = n ./ d;
