function [mappingData] = kelvasa2015_calibratemapping(varargin)
%kelvasa2015_calibratemapping  Produces necessary mappings for KELVASA2015
%   Usage: mappingData = kelvasa2015_calibratemapping(varargin);
%
%   Input parameters:
%     varargin      : All parameters required for model. If
%                     this is not included, default parameters are loaded.
%
%   Output parameters: 
%     mappingData : Calculated mapping data, including the following fields:
%
%                   - calibHRTFsig*: Signal levels. Size: (*N x M x S*) with 
%                     N being the range of azimuthal
%                     angles overwhich the signal was computed,
%                     M being the number of time samples, and
%                     S being the number of audio channels.
% 
%                   - calSpikeDiffPerNeuronPerAzi*: Matrix of chan2-chan1 spike 
%                     rate differences (in spikes/s). Size: (*N x A x B*) with
%                     N being the range of azimuthal angles over which the signal was computed, 
%                     A being the number of simulated AN fibers, and 
%                     B is the number of time bins.
%                                        
%                   - calSpikeRatePerNeuronPerLevel*: Matrix of spike rates (in spikes/s). 
%                     Size: (*L x A*) with L being the range of signal SPLs (in dB) 
%                     and A being the number of simulated AN fibers.
% 
%                   - calParameters*: Structure of model paramters used in processing calibration stimulus.
% 
%
%   KELVASA2015_CALIBRATEMAPPING(varargin) processes a user-specified 
%   calibration sound file and extracts the necessary data required to map 
%   simulated bilateral neural outputs onto a predicted azimuthal angle. 
%   This function computes data required by all three localization models 
%   described in Kelvasa and Dietz (2015) and can therefore take several
%   hours to process.
% 
%   See also: kelvasa2015
%
%   References:
%     D. Kelvasa and M. Dietz. Auditory model-based sound direction
%     estimation with bilateral cochlear implants. Trends in Hearing,
%     19:2331216515616378, 2015.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/kelvasa2015_calibratemapping.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #Requirements: MATLAB M-Signal M-Stats
%   #Author: Daryl Kelvasa (2016): original implementation.
%   #Author: Mathias Dietz (2016): original implementation.
%   #Author: Clara Hollomey (2022): integration in the AMT. 
%   #Author: Piotr Majdak (2024): major documentation rewrite for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

definput.import={'kelvasa2015'};
[flags,kv]  = ltfatarghelper({},definput,varargin);


%% Load HRTF data
HRTF = amt_load('kelvasa2015',kv.HRTFfile);
[~,ind_elev] = min(abs(HRTF.SourcePosition(:,2)-kv.HRTFelevation));
[~,ind_dist] = min(abs(HRTF.SourcePosition(:,3)-kv.HRTFsourceDistance));                
ind = find(sum([HRTF.SourcePosition(:,2) == HRTF.SourcePosition(ind_elev,2),...
                HRTF.SourcePosition(:,3) == HRTF.SourcePosition(ind_dist,3)],2)...
                ==2);           
HRTFnew.SourcePosition = HRTF.SourcePosition(ind,:);
HRTFnew.Data.IR = HRTF.Data.IR(ind,kv.HRTFchannels,:);   
HRTFnew.Data.SamplingRate = HRTF.Data.SamplingRate;
HRTF = HRTFnew;

%% Set dB SPL offset
dboffset=71.778;

%% Main Code
%Initialize variables
              
[signal, fs] = amt_load('kelvasa2015',kv.localizationModelCalibWav);
signal = signal(1:6*fs,:);
sigLengthSec = size(signal,1)/fs;
signal = resample(signal,kv.FS_ACE,fs);
numWindows = sigLengthSec/kv.timeWindowSec; 
numNeurons = kv.N_nervecells;
spikeRatePerNeuron = zeros(2,numNeurons,numWindows);
spikeDiffPerNeuronPerAzi = zeros(numel(kv.azis),numNeurons,numWindows);


%% Calibration of the AN Linear Rate Difference and Max Likelihood model 
    
for ang = 1 : numel(kv.azis)
	tic

      %HRTF filter signal and choose microphone channels       
	[~,ind_ang] = min(abs(HRTF.SourcePosition(:,1)-kv.azis(ang)));

	HRIR = resample(squeeze(HRTF.Data.IR(ind_ang,:,:))',...
			kv.FS_ACE,HRTF.Data.SamplingRate);        

	HRTFchan1 = ifft(fft(signal).*fft(HRIR(:,1),numel(signal)));
	HRTFchan2 = ifft(fft(signal).*fft(HRIR(:,2),numel(signal)));
	HRIR = [HRTFchan1,HRTFchan2];

	if kv.azis(ang) == 0
		  temp = HRIR(:,1)./rms(HRIR(:,1));
		  scalor = scaletodbspl(kv.localizationModelCalibStimulusLevelDB,[],dboffset);
		  scalor = rms(temp.*scalor)/rms(HRIR(:,1));
	end

	HRIR = HRIR .* scalor;                          

	mappingData.calibHRTFsig(ang,:,:) = HRIR; 

	  %Process signal with CI and AN models for right and left channels
    for chan = 1 : 2
 
          %ACE CI processing strategy
        [electrodogram, vTime] = ...
                                kelvasa2015_ciprocessing(HRIR(:,chan),...
                                kv.FS_ACE,'argimport',flags,kv);
        
          %Fredelake Hohmann CI/AN model
        [APvec] = ...
                                kelvasa2015_anprocessing(electrodogram,...
                                vTime, 'argimport',flags,kv);
                            
        [spikeRatePerNeuron(chan,:,:), ~] = ...
                                kelvasa2015_anbinning(APvec,...
                                sigLengthSec,'argimport',flags,kv);
                            
    end
    
    spikeDiffPerNeuronPerAzi(ang,:,:) = squeeze(spikeRatePerNeuron(2,:,:) - ...
                                        spikeRatePerNeuron(1,:,:));  

	a = toc;
	timeLeft = round((a*(numel(kv.azis)- ang))/60);
	amt_disp(['calibrating with ',kv.localizationModelCalibWav,'.wav at ',...
			   num2str(kv.localizationModelCalibStimulusLevelDB),...
		      ' dB. Estimated minutes left to complete: ', num2str(timeLeft)],'volatile');
end
amt_disp();

%% Calibration of the AN Rate Level localization model
% %Initialize variables
spikeRatePerNeuronPerLevel = zeros(numel(kv.dBRange), numNeurons);
 
signal =  squeeze(mappingData.calibHRTFsig(1,:,1))';

for level = 1 : numel(kv.dBRange)
tic
                                 
%Adjust signal to level over which to compute rate level slopes (???)
                  temp = signal./rms(signal);
                  scalor = scaletodbspl(kv.dBRange(level),[],dboffset);
                  scalor = rms(temp.*scalor)/rms(signal(:,1));
                  HRTFsig = scalor.*signal;

%Process signal with CI and AN models for right and left channels
        [electrodogram, vTime] = ...
                                kelvasa2015_ciprocessing(HRTFsig,...
                                kv.FS_ACE,'argimport',flags,kv);
                           
        [APvec] = ...
                                kelvasa2015_anprocessing(electrodogram,...
                                vTime,'argimport',flags,kv);
                            
        [spikeRatePerNeuron, ~] = ...
                                kelvasa2015_anbinning(APvec,...
                                sigLengthSec, 'argimport',flags,kv);  
         
        %Compute mean spike rate over all time windows                    
        spikeRatePerNeuronPerLevel(level,:) = mean(spikeRatePerNeuron,2);

        
        a = toc; timeLeft = round((a*(numel(kv.dBRange)- level))/60);
        amt_disp(['Calibration with ',...
                 kv.localizationModelCalibWav,'.wav at ',...
                 num2str(kv.localizationModelCalibStimulusLevelDB),...
                 ' dB Time left (min):', num2str(timeLeft)],'volatile');                        
end
amt_disp();

mappingData.calSpikeDiffPerNeuronPerAzi = spikeDiffPerNeuronPerAzi;
mappingData.calSpikeRatePerNeuronPerLevel = spikeRatePerNeuronPerLevel;
mappingData.calParameters = kv;


