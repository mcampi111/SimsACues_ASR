function [int_rep, Y, fc_aud, fc_mod, fsR] = paulick2024(insig, fs, varargin)
%paulick2024 Computational auditory signal processing and perception (CASP) model 
%   Usage: [int_rep, Y, fc_aud, fc_mod] = paulick2024(insig, fs, ...);
%
%   Input parameters:
%     insig  : Column vector with the acoustic signal (in Pa). Size: (*time*).
%     fs     : Sampling rate (in Hz).
%
%   Output parameters:
%     int_rep: Internal representation of the auditory process. 
%              Size: (*time x fc_aud x fc_mod*).
%     Y      : Structure containing the output of various model stages
%              with the following fields: 
%
%              - OM*: Output after outer-and middle ear filtering.
%
%              - BM*: Output of auditory filterbank (DRNL) stage
%                representing the velocity at the basilar membrane.
%
%              - IHC*: Output of the IHC transduction stage representing
%                the potential of the IHCs. 
%
%              - adaptation*: Output of the adaptation stage after 
%                the modulation filterbank representing the processing
%                at the level of brain stem.
%
%     fc_aud : Centre frequencies (in Hz) of the auditory filterbank. 
%     fc_mod : Centre frequencies (in Hz) of the modulation filterbank.
%     fsR    : Sampling frequency (in Hz) after resampling of insig.
%
%   PAULICK2024(..) computes the internal representation of the signal insig*
%   as known as the CASP model described in Paulick et al., (2024). 
%   The model returns the output signals of each model stage. The model 
%   stages consist of an outer-and middle ear filter, DRNL filterbank,
%   IHC model, adaptation stage and modulation filterbank. 
% 
%   *Note**: This code also implementats the 2008 version of the CASP model,
%   described in Jepsen et al., (2008). This model can be evoked
%   by using the kay-value pair 'model','jepsen2008'. 
%   While the implementation is as close as possible, it is based on the 
%   (limited) description in the Jepsen et al. (2008) and cannot
%   be fully verified. The primary focus of this code is the revised 
%   model as described in Paulick et al. (2024).
%
%         
%
%   See also: exp_paulick2024 demo_paulick2024 paulick2024_drnl paulick2024_corr 
%             paulick2024_decision paulick2024_ihc paulick2024_roi
%   
%
%   References:
%     M. Jepsen, S. Ewert, and T. Dau. A computational model of human
%     auditory signal processing and perception. The Journal of the
%     Acoustical Society of America, 124(1), 2008.
%     
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/paulick2024.php


%   #Requirements: MATLAB M-Signal M-Stats
%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Qualified
%   #Author: Lily Paulick (2024): Original implementation. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
  
% ------ Checking of input parameters ------------
if nargin<2
  error('%s: Too few input arguments.',upper(mfilename));
end

if ~isnumeric(insig) 
  error('%s: insig must be numeric.',upper(mfilename));
end

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
  error('%s: fs must be a positive scalar.',upper(mfilename));
end

definput.import={'paulick2024'}; % load defaults from arg_paulick2024

[flags,kv]  = ltfatarghelper({'flow','fhigh'},definput,varargin);

% provide adequate structure
Y = struct('OM',[],... 
    'BM',[],...        
    'IHC',[],...
    'adaptation',[]); 

% -------------- Outer/Middle ear filtering -------------- %
b_hp = headphonefilter(fs); % calc headphone filtercoeffs
b_me = middleearfilter(fs);

insig = filter(b_hp,1,insig); % Outer-ear filterring
insig = filter(b_me,1,insig); % middle-ear-ear filterring

Y.OM = insig;

% -------------- DRNL filterbank -------------- %
fc_aud = erbspace(kv.flow, kv.fhigh, kv.Naud);
outsig = zeros(length(insig),kv.Naud); % channels are in colums
for n = 1:kv.Naud
    outsig(:,n) = paulick2024_drnl(insig,fc_aud(n),fs,kv.subject,kv.model); 
end

Y.BM = outsig; 

% -------------- IHC stage -------------- %
if strcmp(kv.model,'jepsen2008') 
    outsig = ihcenvelope(outsig, fs, 'ihc_relanoiborra2019');  % Half-wave rectification & LP
elseif strcmp(kv.model,'paulick2024')
    outsig = paulick2024_ihc(outsig,fs);
end

if strcmp(kv.model,'jepsen2008') % only for CASP2008
    outsig = outsig*10^(50/20);  % Gain to compensate for the Outer/middle ear attenuation
    outsig = outsig.^2;          % Expansion (Auditory nerve)   
end  

Y.IHC = outsig;  

% -------------- Adaptation -------------- %
if strcmp(kv.model,'jepsen2008') % original parameters (2008 CASP) 
    minlvl = 1e-5; 
    tau = [0.005 0.05 0.129 0.253 0.500];
    lim = 10;
elseif strcmp(kv.model,'paulick2024')  % revised parameters (2024 CASP)

     % freq. specific model parameters
    minlvls = 1e-6*[114.6010 112.6388 110.5593 115.6323 122.8003 128.3473 129.4167 130.5499 134.9603 140.6641... 
        146.7089 147.9811 148.9594 149.9962 142.9728 133.7308 123.9364 116.7957 110.2674 103.3490...
        96.4875 89.5786 82.2569 74.4976 66.1913 57.3802 48.0427 42.4791 40.9715 39.3738...
        37.6163 31.9073 25.8572 19.4456 14.2276 11.9080 9.4499 6.8449 5.6897 6.3316... 
        7.0118 7.7326 7.1594 6.2346 5.2545 4.2159 3.5157 2.7790 1.9983 1.1709];
    minlvls_f = erbspace(250,8000,50);
    minlvls = [minlvls_f(:) minlvls(:)];

    minlvl = nan(1,kv.Naud);
    for ii = 1:kv.Naud
        [~,idx] = min(abs(minlvls(:,1) - fc_aud(ii)));
        minlvl(ii) = minlvls(idx,2);
    end
    
    tau = [0.007 0.0318 0.0878 0.2143 0.5];
    lim = 10;	
end    

outsig = adaptloop(outsig, fs, lim, minlvl, tau); 
Y.adaptation = outsig;

resamp = 4; % resample factor
resampleLen = floor(length(insig)/resamp);
fsR = fs / resamp; 

if ( resamp > 1 )
        outsig = resample(outsig,1,resamp);
end
outsig = outsig(1:resampleLen,:);

% -------------- Modulation filterbank -------------- %
[outsig,fc_mod] = modfilterbank(outsig,fsR,fc_aud);

% Build three-dimensional output
int_rep = nan(resampleLen,kv.Naud,length(fc_mod)); 
for ii = 1:length(fc_aud)
    Nmod = size(outsig{ii},2);
    int_rep(:,ii,1:Nmod) = outsig{ii};
end


