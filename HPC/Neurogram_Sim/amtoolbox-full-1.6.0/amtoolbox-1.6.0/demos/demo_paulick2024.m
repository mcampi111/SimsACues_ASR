%demo_paulick2024 Demonstration of the CASP model PAULICK2024
%
%   This is a basic demonstration of the way CASP makes a decision on
%   detectablility in an example task: Intensity discrimination of a 1-kHz tone
%   for a single particular presentation. The backend of CASP is designed for adapative 
%   nAFC paradigms and the code here calculates the correlation and makes a
%   decision for that single particular presentation. 
%
%   Note that the code here does not go through the entire adaptive procedure 
%   to find the threshold. For a full implementation of the adapative procedure
%   and more details, see Paulick et al. (2024).
%
%   See also: paulick2024 exp_paulick2024
%
%   References:
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_paulick2024.php


%   #Author: Lily Paulick (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% ----------- CREATE SIGNALS ------------ %%

% intensity discrimination 1kHz tone
fs = 44100;
fc = 1000; 
dur = 0.2; % tone duration (in s)

  % Generate tone:
tone = sig_tone(fc, dur, fs); 
tone = fade(tone,0.01,fs); 

 % 'Masker' interval
mask_spl = 20; % Signal SPL (in dB) 
mask = scaletodbspl(tone,mask_spl); 
mask = [mask; zeros(0.5*fs-length(mask),1)];

 % 'Target' interval
tar_spl = mask_spl + 1; % 1 dB above signal SPL, tracking variable
tar = scaletodbspl(tone,tar_spl); 
tar = [tar; zeros(0.5*fs-length(tar),1)];

 % 'Supra-threshold' representation
supra_spl = mask_spl + 5; % 5 dB above signal SPL 
supra = scaletodbspl(tone,supra_spl); 
supra = [supra; zeros(0.5*fs-length(supra),1)];

 % 'Reference' representation
ref_spl = mask_spl; % signal SPL
ref = scaletodbspl(tone,ref_spl);
ref = [ref; zeros(0.5*fs-length(ref),1)];

%% ------ Build stored template and reference ------- %%

[int_rep_supra, Ysup,fc_aud,fc_mod,fsR] = paulick2024(supra, fs);
[int_rep_ref, Yref,~,~] = paulick2024(ref, fs);

int_rep = int_rep_supra;
int_rep_ref1 = int_rep_ref;
adap_supra = Ysup.adaptation;
adap_ref = Yref.adaptation;

av = 1; % average over multiple iterations - in this case, it is a deterministic signal so not necessary
if av >= 2
    for ii = 1:av - 1
    
%         supra = tone/rms(tone)*20e-6.*10.^(supra_spl/20); % Amplitude in Pa;
        supra = scaletodbspl(tone, supra_spl);
        supra = [supra; zeros(0.5*fs-length(supra),1)];
        
%         ref = tone/rms(tone)*20e-6.*10.^(ref_spl/20); % Amplitude in Pa;
        ref = scaletodbspl(tone, ref_spl);
        ref = [ref; zeros(0.5*fs-length(ref),1)];

        [int_rep_supra, Ysup,~,~] = paulick2024(supra, fs);    
        [int_rep_ref, Yref,~,~] = paulick2024(ref, fs);
    
        adap_supra = adap_supra + Ysup.adaptation;
        adap_ref   = adap_ref   + Yref.adaptation;
        
        int_rep = int_rep + int_rep_supra;
        int_rep_ref1 = int_rep_ref1 + int_rep_ref;
    
    end
end

adap_diff = (adap_supra - adap_ref)/av; % save template at output of adaptation loops for ROI analysis
roi = paulick2024_roi(adap_diff,fs,fc_aud); % find relevant auditory frequency channels 

% template - difference between supra-threshold and reference 
template = (int_rep - int_rep_ref1)/av;
c = sqrt(fsR/sum(template .^ 2,'all','omitnan')); % normalise template
template = c*template;

% store reference
reference = int_rep_ref1/av;

%% ----- Build internal representations of intervals ------ %%

int_rep_tar = paulick2024(tar, fs);
int_rep_tar = int_rep_tar - reference;   % subtract reference signal
    
int_rep_mask = paulick2024(mask, fs);
int_rep_mask = int_rep_mask - reference; % subtract reference signal

%% --------- Calculate correlations ------------ %%

corr_tar  = paulick2024_corr(int_rep_tar(:,roi.idx,:),template(:,roi.idx,:),fs,roi.freq,fc_mod);
corr_mask = paulick2024_corr(int_rep_mask(:,roi.idx,:),template(:,roi.idx,:),fs,roi.freq,fc_mod);

% Final correlation
corr_fin = 1/fsR*max(0,corr_tar.fin - max(0,corr_mask.fin));

% ----- Make decision ------- %
  % define type of nAFC experiment, e.g.
nAFC = 2;     % 2 intervals
rule = [1 2]; % 1up-2down tracking rule
decision = paulick2024_decision(corr_fin,nAFC,rule); % if decision = 1 detected; decision = 0 not detected

if decision == 1
    amt_disp('Target interval has been correctly identified','documentation');
elseif decision == 0
    amt_disp('Target interval could not be correctly identified','documentation');
else
    amt_disp('A decision could not be made','documentation');
end

