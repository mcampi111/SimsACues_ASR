function [out, clean, noisy] = relanoiborra2019(insig_clean, insig_noisy, fs, varargin)
%RELANOIBORRA2019 Modulation filterbank (based on DRNL)
%   Usage: out = relanoiborra2019(insig_clean, insig_noisy, fs, varargin)
%          out = relanoiborra2019(insig_clean, insig_noisy, fs, flow, fhigh, varargin)
%          [out, clean, noisy] = relanoiborra2019([..])
%
%   Input parameters:
%     insig_clean : Clean speech template signal
%
%     insig_noisy : Noisy speech target signal
%
%     fs          : Sampling frequency (Hz)
%
%     flow        : Lowest center frequency of auditory filterbank (Hz)
%
%     fhigh       : Highest center frequency of auditory filterbank (Hz)
%
%
%   Output parameters:
%     out : Correlation metric structure. It contains the following fields:
%
%           dint      : Correlation values for each modulation band.
%
%           dsegments : Correlation values for each time window and modulation band.
%
%           dfinal    : Final average correlation
%
%
%   RELANOIBORRA2019 builds the internal representations of the template and 
%   target signals. For the correct initialisation of the adaptation stage of the model, 
%   the speech signals (clean template and noisy targets) need to be prepanned, i.e.,
%   padded with non-zero signals. By default, the internal
%   representations are thus assessed for two appended repetitions of each 
%   sound, but ultimately only the second repetition is used by the back-end
%   stage of the model. The prepanning can be used in three configurations:
%
%     'prepanning'          Automatic prepanning by the model assuming two subsequent sound 
%                           presentations but only keeping the second presentation for modelling. 
%                           If N_org is provided, the prepanning will be done for N_org 
%                           samples. If N_org is not provided, the prepanning will be done 
%                           for the singal length, but a minimum of 1.5 s (this duration seems 
%                           to be long enough to ensure statistically equivalent results.
%
%     'no_prepanning'       No pre-panning is applied at all. This option is faster but 
%                           may lead to an overestimation of the onset of the internal 
%                           representations during the decision stage and is thus 
%                           not recommended. 
%
%     'prepanning_external'  External prepanning by the user, i.e., the input signals 
%                            are already prepanned by N_prepanning samples.
%
%
%   RELANOIBORRA2019 also takes the following optional key-value pairs:
%
%     'N_org',N_org  Length of original sentence required for prepanning. 
%                    Default is double the length of insig_clean. 
%
%     'subject',sbj  Subject profile for the DRNL definition. Default: 'NH' 
%
%     'N_prepanning',N_prepanning  Samples of prepanning, used for truncating
%                                  the internal representations during the decision stage.
%                                  Required when using 'prepanning_external'.
%
%
%   The model has been optimized to work with speech signals, and the
%   preprocesing and variable names follow this principle. The model is
%   also designed to work with broadband signals. In order to avoid undesired
%   onset enhancements in the adaptation loops, the model expects to recive a
%   prepaned signal to initialize them.
%
%
%   References:
%     H. Relaño-Iborra, J. Zaar, and T. Dau. A speech-based computational
%     auditory signal processing and perception model. The Journal of the
%     Acoustical Society of America, 146(5), 2019.
%     
%     M. Jepsen, S. Ewert, and T. Dau. A computational model of human
%     auditory signal processing and perception. The Journal of the
%     Acoustical Society of America, 124(1), 2008.
%     
%
%   See also: ihcenvelope relanoiborra2019_drnl
%             relanoiborra2019_mfbtd joergensen2013_sim
%             exp_osses2022 dau1997
%
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/relanoiborra2019.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Qualified
%   #Requirements: M-Stats M-Signal M-Control
%   #Author: Helia Relano Iborra (March 2019): v4.0 provided to the AMT team
%   #Author: Clara Hollomey (2021): adapted to the AMT
%   #Author: Piotr Majdak (2021): adapted to the AMT 1.0
%   #Author: Alejandro Osses (2023): Adding pre-panning (previously hard-coded in exp file)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%% Auditory filtering:
if isoctave
   warning(['Currently this model is only fully functional under MATLAB.']); 
end

definput.import={'relanoiborra2019'}; % load defaults from arg_relanoiborra2019
[flags,kv]  = ltfatarghelper({'flow','fhigh'},definput,varargin);

if flags.do_prepanning
    if isempty(kv.N_org)
        warning('%s.m: This model requires a pre-panning, i.e., a padding of samples before the input signal of interest is processed. The default value from the article will be used',mfilename);
        N_org = min([length(insig), round(1.5*fs)]);
    else
        N_org = kv.N_org; 
    end

    %%% Pre-panning:
    if N_org > length(insig_clean)
        warning('%s.m: The maximum pre-panning is equal to the length of the input signal');
        N_org = length(insig_clean);
    end
    idxf_prepaning = length(insig_clean);
    idxi_prepaning = idxf_prepaning - N_org + 1;
    N_prepanning = idxf_prepaning - idxi_prepaning + 1;

    insig_clean = [insig_clean(idxi_prepaning:idxf_prepaning); insig_clean];
    insig_noisy = [insig_noisy(idxi_prepaning:idxf_prepaning); insig_noisy];
end
if flags.do_no_prepanning
    N_prepanning = 0;
end
if flags.do_prepanning_external
    N_prepanning = kv.N_prepanning; % if external prepanning, the prepanning length needs to be explicitly given
end
%%% End of prepaning

[clean_mfb, fc_mod, clean_afb, fc] = relanoiborra2019_featureextraction(insig_clean, fs, 'argimport',flags,kv);
[noisy_mfb, ~, noisy_afb] = relanoiborra2019_featureextraction(insig_noisy, fs, 'argimport',flags,kv);

% 'idxi' and 'idxf' are used to remove the internal representation that 
%     corresponds to the prepaned signal. So, idxi and idxf define the 
%     internal representation with the same length as the original input signals:
idxi = N_prepanning+1;
idxf = size(clean_mfb,1);
out = relanoiborra2019_decision(clean_mfb(idxi:idxf, :, :), ...
                                noisy_mfb(idxi:idxf, :, :), fs, fc, fc_mod,'argimport',flags,kv);
clean.afb = clean_afb;
clean.fc = fc;
clean.mfb = clean_mfb;
clean.fmod = fc_mod;
clean.idxi = idxi; % first sample after prepanning
clean.idxf = idxf; % last sample

noisy.afb = noisy_afb;
noisy.fc = fc;
noisy.mfb = noisy_mfb;
noisy.fmod = fc_mod;

%   [out,fc,mfc] = relanoiborra2019_preproc(insig, fs, varargin);
%     varargout{1} = fc;
%     varargout{2} = mfc;


