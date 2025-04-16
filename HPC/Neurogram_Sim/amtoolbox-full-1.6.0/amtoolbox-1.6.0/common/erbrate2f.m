function f = erbrate2f(erbrate,model)
%erbrate2f ERB rate to frequency: Calculate the frequency associated with an ERB rate
%   Usage: f = erbrate2f(erbrate);
%          f = erbrate2f(erbrate, model);
%
%   Input parameters:
%     erbrate : ERB rate (in Cams) as the number of auditory filters, each with the bandwidth of 1 ERB. 
%               The ERB rate describes the number of ERBs below the frequency f. 
%     model:    String selecting the model for the frequency calculation. The following
%               models can be used:
%
%               - 'glasberg1990': Eq. 4 from Glasberg and Moore (1990) or Eq. 2 from Moore 
%                 et al. (1997). Default. 
%
%               - 'moore1983': Inverse of the Eq. 5 of Moore and Glasberg (1983). This 
%                 is an older model and it is provided for compatibility with older models only. 
%
%
%   Output parameters: 
%     f    : Center frequency of the auditory filter (in Hz).
%               
%   
%   ERBRATE2F(erbrate) calculates the center frequency (in Hz) of an auditory filter which can 
%   associated with the ERB rate of erbrate (in Cams). The ERB rate is also sometimes described as the 
%   ERB scale, ERB number, or E. The unit of erbrate is also known as Cams, 
%   see e.g., Moore et al. (2016). 
%
%   ERBRATE2F(erbrate) or ERBRATE2F(erbrate,'glasberg1990') calculates the frequency according 
%   to the inverse of Eq. 4 from Glasberg and Moore (1990) or inverse of Eq. 2 from Moore et al. (1997).
%   This is the same as the deprecated function erb2fc.
%
%   ERBRATE2F(erbrate,'moore1983') calculates the frequency according 
%   to the inverse of Eq. 5 of Moore and Glasberg (1983).
%
%
%   See also: f2erbrate
%
%   References:
%     B. C. J. Moore, B. R. Glasberg, A. Varathanathan, and
%     J. Schlittenlacher. A loudness model for time-varying sounds
%     incorporating binaural inhibition. Trends in Hearing,
%     20:2331216516682698, 2016. PMID: 28215113.
%     
%     B. C. J. Moore, B. R. Glasberg, and T. Baer. A Model for the Prediction
%     of Thresholds, Loudness, and Partial Loudness. J. Audio Eng. Soc,
%     45(4):224--240, 1997.
%     
%     B. Moore and B. Glasberg. Suggested formulae for calculating
%     auditory-filter bandwidths and excitation patterns. The Journal of the
%     Acoustical Society of America, 74:750--753, 1983.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/erbrate2f.php


%   #Author: John Culling (2021): original implementation
%   #Author: Clara Hollomey (2021): integration in the AMT
%   #Author: Piotr Majdak (2024): integration of the Glasberg and Moore (1990) formula based on erb2fc and documentation upgrade for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

if ~exist('model','var'), model='glasberg1990'; end

switch model
  case 'moore1983'
	f = (0.312 - (exp((erbrate - 43)/11.17)) * 14.675) ./ (exp((erbrate - 43)/11.17) - 1);
	f = f * 1000; 	
  case 'glasberg1990'
    f = (10.^(erbrate/21.366)-1)./4.368;
    f = f * 1000;
  otherwise
    error('Unknown model for the conversion.');
end






