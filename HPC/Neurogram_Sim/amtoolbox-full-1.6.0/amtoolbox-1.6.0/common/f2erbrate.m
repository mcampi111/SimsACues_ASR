function erbrate = f2erbrate(f, model)
%f2erbrate Frequency to ERB rate: Calculate the ERB rate for a given frequency
%   Usage: erbrate = f2erbrate(f);
%          erbrate = f2erbrate(f, model);
%
%   Input parameters: 
%     f    : Center frequency of the auditory filter (in Hz)
%     model: String selecting the model for the ERB-rate calculation. The following
%            models can be used:
%
%            - 'glasberg1990': Eq. 4 from Glasberg and Moore (1990) or Eq. 2 from Moore 
%              et al. (1997). Default. 
%
%            - 'moore1983': Eq. 5 of Moore and Glasberg (1983). This is an older model
%              and it is provided for compatibility with older models only. 
%
%
%   Output parameters: 
%     erbrate : ERB rate (in Cams) for the frequency f. 
%                           
%
%   F2ERBRATE(f) calculates the ERB rate (in Cams) of an auditory filter with the 
%   center frequency f (in Hz). The ERB rate describes the number of auditory filters 
%   (each with the bandwidth of one ERB) below the frequency f. The ERB rate is also sometimes described
%   as the ERB scale, ERB number, or E. The unit of erbrate is usually Cams, 
%   see e.g., Moore et al. (2016). 
%
%   F2ERBRATE(f) or F2ERBRATE(f,'glasberg1990') calculates the ERB rate according 
%   to the Eq. 4 from Glasberg and Moore (1990) or Eq. 2 from Moore et al. (1997).
%   This is the same as the deprecated function fc2erb.
%
%   F2ERBRATE(f,'moore1983') calculates the ERB rate according 
%   to the Eq. 5 of Moore and Glasberg (1983). This is an older model
%   and it is provided for compatibility with older models only. 
%
%
%   See also: erbrate2f
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
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/f2erbrate.php


%   #Author: John Culling (2021): original implementation
%   #Author: Clara Hollomey (2022): integration for the AMT 1.2
%   #Author: Piotr Majdak (2024): integration of the Moore and Glasberg (1983) formula based on fc2erb and documentation upgrade for the AMT 1.6

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
	f = f / 1000;
	erbrate = 11.17 * log((f+0.312)./(f+14.675)) + 43;
  case 'glasberg1990'
    f = f / 1000;
    erbrate = 21.366 * log10(4.368*f + 1);
  otherwise
    error('Unknown model for the conversion.');
end


