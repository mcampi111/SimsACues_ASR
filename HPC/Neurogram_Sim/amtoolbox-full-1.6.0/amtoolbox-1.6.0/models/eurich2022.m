function [processed, mpar] = eurich2022(mRef, mTest,mpar)
%EURICH2022  Binaural detection model based on two-hemisphere code and interaural incoherence interference
%   Usage: [processed, mpar] = eurich2022(mRef, mTest,mpar)
%
%   Input parameters:
%     mRef     : Binaural reference signal
%     mTest    : Binaural test signal
%     mpar     : Model parameters
%
%   Output parameters:
%     processed  : Processed model outputs (reference and test, concatenated)
%     mpar       : Modified model parameters
%
%   EURICH2022 is a binaural detection model based on two-hemisphere code. 
%   It involves interaural incoherence interference. For binaural reference and test 
%   signals, it computes the complex correlation coefficient (gamma) representing the
%   two-hemisphere encoding found in mammals' medial superior olives (MSO). 
%   To account for degraded binaural detection for maskers with frequency-dependent 
%   interaural coherence, an across-frequency interference mechanisms of interaural 
%   incoherence is introduced. Additionally, the model computes the DC power to account 
%   for energetic unmasking. EURICH2022_processing computes these features based 
%   on a binaural signal. Then, EURICH2022_decision derives the model's sensitivity 
%   based on these computed features. 
%
%   mpar is an optional structure with the following parameters:
%
%     - fs:                             sampling frequency of model
%     - Filters_per_ERB_aud:            spacing of peripheral filter central frequencies in ERB
%     - GT_bandwidth_factor:            factor of gammatone filter bandwidth relative to "standard" (i.e. ERB = 79 Hz @500Hz)
%     - GT_lowest_center_frequency:     lower bound of gammatone filterbank
%     - GT_highest_center_frequency:    higher bound of gammatone filterbank
%     - GT_fix_center_frequency:        fixed center frequency of one of the gammatone filterbank's filters
%     - GT_filterorder:                 filter order of gammatone filterbank
%     - interference_sigma:             std of the Gaussian window used for the across-frequency incoherence interference
%     - iKernelThresh:                  threshold above which a value of the Gaussian filter window is used
%     - rho_max                         upper limit of encoded interaural coherence (i.e. internal noise)
%     - monaural_internal_noise_sigma:  std of the Gaussian, level-dependent internal noise of the monaural feature
%     - binaural_internal_noise_sigma:  std of the Gaussian internal noise of the binaural feature
%     - target_channel:                 index of the channel to be selected for processing in EURICH2022_decision
%
%
%   See also: exp_eurich2022 eurich2022_processing eurich2022_decision
%
%   References:
%     B. Eurich, J. Encke, S. D. Ewert, and M. Dietz. Lower interaural
%     coherence in off-signal bands impairs binaural detection. The Journal
%     of the Acoustical Society of America, 151(6):3927--3936, 06 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/eurich2022.php


%   #StatusDoc: Submitted
%   #StatusCode: Submitted
%   #Verification: Unknown
%   #Author: Bernhard Eurich (2022)
%   #Author: Piotr Majdak (2023): integration in the AMT

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 



% process Reference and Test signals
[processed_mRef,mpar]  = eurich2022_processing(mRef,mpar);
[processed_mTest,mpar] = eurich2022_processing(mTest,mpar);

processed = cat(1,processed_mRef, processed_mTest);



