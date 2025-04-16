function conductance = lyon2011_detect(x_in)
%lyon2011_detect Calculates conductance using a sigmoidal detection nonlinearity
%
%   Usage: conductance = lyon2011_detect(x_in)
%
%   Input parameters:
%     x_in : input signal
%
%   Output parameters:
%     conductance : conductance
%
%   An IHC-like sigmoidal detection nonlinearity for the CARFAC.
%   Resulting conductance is in about [0...1.3405]
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/lyon2011_detect.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #License: Apache2
%   #Author: Richard F. Lyon (2013): original implementation (https://github.com/google/carfac)
%   #Author: Amin Saremi (2016): adaptations for the AMT
%   #Author: Clara Hollomey (2021): integration in the AMT 1.0
%   #Author: Piotr Majdak (2024): rudimentary clean up for the AMT 1.6

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.




a = 0.175;   % offset of low-end tail into neg x territory
% this parameter is adjusted for the book, to make the 20% DC
% response threshold at 0.1

set = x_in > -a;
z = x_in(set) + a;

% zero is the final answer for many points:
conductance = zeros(size(x_in));
conductance(set) = z.^3 ./ (z.^3 + z.^2 + 0.1);

