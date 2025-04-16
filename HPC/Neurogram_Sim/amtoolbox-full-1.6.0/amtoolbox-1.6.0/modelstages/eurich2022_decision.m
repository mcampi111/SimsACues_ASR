function dprime = eurich2022_decision(processed,mpar)
%eurich2022_decision  Decision stage of the Eurich et al. (2022) model 
%   Usage: dprime = eurich2022_decision(processed,mpar)
%
%   Input parameters:
%     processed : Matrix containing the processed stimulus from eurich2022_processing
%
%     mpar      : Structure with the following model parameters:
%
%      - fs:                             sampling frequency of model
%      - Filters_per_ERB_aud:            spacing of peripheral filter central frequencies in ERB
%      - GT_bandwidth_factor:            factor of gammatone filter bandwidth relative to "standard" (i.e. ERB = 79 Hz @500Hz)
%      - GT_lowest_center_frequency:     lower bound of gammatone filterbank
%      - GT_highest_center_frequency:    higher bound of gammatone filterbank
%      - GT_fix_center_frequency:        fixed center frequency of one of the gammatone filterbank's filters
%      - GT_filterorder:                 filter order of gammatone filterbank
%      - interference_sigma:             std of the Gaussian window used for the across-frequency incoherence interference
%      - iKernelThresh:                  threshold above which a value of the Gaussian filter window is used
%      - rho_max                         upper limit of encoded interaural coherence (i.e. internal noise)
%      - monaural_internal_noise_sigma:  std of the Gaussian, level-dependent internal noise of the monaural feature
%      - binaural_internal_noise_sigma:  std of the Gaussian internal noise of the binaural feature
%      - target_channel:                 index of the channel to be selected for processing in EURICH2022_DECISION
%   
%   
%   Output parameters:
%     dprime                   : combined sensitivity indices of binaural and monaural feature
%
%
%   See also: eurich2022 exp_eurich2022
%
%   References:
%     B. Eurich, J. Encke, S. D. Ewert, and M. Dietz. Lower interaural
%     coherence in off-signal bands impairs binaural detection. The Journal
%     of the Acoustical Society of America, 151(6):3927--3936, 06 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/eurich2022_decision.php


%   #Author: Bernhard Eurich (2022): original implementation
%   #Author: Piotr Majdak (2023): adaptation to AMT 1.4

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

binaural_feature_ref  = processed(1,:);
binaural_feature_test = processed(3,:);

monaural_feature_ref  = processed(2,:);
monaural_feature_test = processed(4,:);

% binaural decision
dprime_binaural_multichannel = abs(binaural_feature_ref - binaural_feature_test) / mpar.binaural_internal_noise_sigma;

% monaural decision
delta_P = abs(monaural_feature_test - monaural_feature_ref);
dprime_monaural_multichannel = delta_P ./ mean([monaural_feature_test; monaural_feature_ref],1) / mpar.monaural_internal_noise_sigma;


if find(mpar.target_channel)
    dprime_binaural = dprime_binaural_multichannel(mpar.target_channel);
    dprime_monaural  = dprime_monaural_multichannel(mpar.target_channel);
else
    dprime_binaural = max(dprime_binaural_multichannel);
    dprime_monaural = max(dprime_monaural_multichannel);
end


dprime = sqrt(dprime_binaural^2 + dprime_monaural^2);


end
