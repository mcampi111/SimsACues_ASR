function [output,cf] = verhulst2015(insig,fs,fc_flag,varargin)
%verhulst2015 Cochlear transmission-line model (improved version)
%
%   Usage: output = verhulst2015(insig,fs,fc,subject,irregularities,sheraPo)
%
%   Input parameters:
%        insig          : Acoustic signal (in Pa). Size: (*time x ear*).
%        fs             : Sampling rate (in Hz).
%        fc_flag        : Either a vector with frequencies specifying the probe positions
%                         along basilar-membrane sections, or 'all' to probe all
%                         1000 cochlear sections, or 'abr' to probe 401 locations
%                         between 112 and 12000 Hz.
%
%   Output parameters:
%       V  : Velocity of the basilar membrane sections. Size: (*time x section x ear*).
%       Y  : Displacement of the basilar membrane sections. Size: (*time x section x ear*).
%       E  : Sound pressure at the middle ear.
%       CF : Actual center frequencies (in Hz) of the probed basiliar-membrane sections. Size: section.
%
%   VERHULST2015(..) computes the displacement at various sections of the basilar membrane and their
%   velocity of the movement. For more details and parameters, see arg_VERHULST2015. 
%
%   VERHULST2015(..) also accepts the following flags among many others:
%
%     'progress'      Display the calculation progress. Default. 
%
%     'silent'        No progress display. Opposite of 'progress'. 
%
%     'no_debug'      No display of debugging information. Default. 
%
%     'debug'         Display additional debugging information. 
%                     Opposite of 'no_debug'.
%
%
%   See also: verhulst2015 verhulst2015_cn
%             verhulst2015_ic middleearfilter 
%
%   License
%   --------
%
%   This model is licensed under the UGent Academic License. Further usage details are provided
%   in the UGent Academic License which can be found in the AMT directory "licences" and at
%   <https://raw.githubusercontent.com/HearingTechnology/Verhulstetal2018Model/master/license.txt>.
%
%   References:
%     S. Verhulst, H. Bharadwaj, G. Mehraei, C. Shera, and
%     B. Shinn-Cunningham. Functional modeling of the human auditory
%     brainstem response to broadband stimulation. The Journal of the
%     Acoustical Society of America, 138(3):1637--1659, 2015.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/verhulst2015.php


%   #License: ugent
%   #StatusDoc: Perfect
%   #StatusCode: Good
%   #Verification: Unknown
%   #Requirements: MATLAB M-Signal PYTHON C
%   #Author: Alejandro Osses (2020): primary implementation.
%   #Author: Piotr Majdak (2021): adaptations for the AMT 1.0.
%   #Author: Piotr Majdak (2024): Documentation improvements.

% This file is licenced under the terms of the UGent Academic License, which details can be found in the AMT directory "licences" and at <https://raw.githubusercontent.com/HearingTechnology/Verhulstetal2018Model/master/license.txt>.
% For non-commercial academic research, you can use this file and/or modify it under the terms of that license. This file is distributed without any warranty; without even the implied warranty of merchantability or fitness for a particular purpose. 


amt_info('once');
% ------ Checking of input parameters ------------

if nargin<3
	error('%s: Too few input arguments.',upper(mfilename));
end

if ~isnumeric(insig)
	error('%s: insig must be numeric.',upper(mfilename));
end

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
    error('%s: fs must be a positive scalar.',upper(mfilename));
end
definput.import={'verhulst2015'};  % load defaults from arg_verhulst2015

[flags,keyvals]  = ltfatarghelper({},definput,varargin);

IrrPct = keyvals.IrrPct;
storeflag = ' ';
if flags.do_oae, storeflag = [storeflag 'e']; end
if flags.do_y  , storeflag = [storeflag 'y']; end
if flags.do_ihc, storeflag = [storeflag 'i']; end

[Nr_signals,idx]=min(size(insig));

irregularities=keyvals.irr_on.*ones(1,Nr_signals);

%%% Fix model parameters so far: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subject = keyvals.subject; % seed
non_linear_type = keyvals.non_linear_type;

% Number of neurones: 13-3-3 => no synaptopathy, any loss of neurones => synaptopathy
numH = keyvals.numH;
numM = keyvals.numM;
numL = keyvals.numL;

if idx == 1
    error('If multiple signals are used as input make sure each column is one signal')
end

%%% Stage 1A. Outer ear: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.do_outerear
    % Same outer ear filter as in other peripheral models (e.g., Jepsen2008)
    hp_fir = headphonefilter(fs);% Getting the filter coefficients at fs
    N = ceil(length(hp_fir)/2);  % group delay for a FIR filter of order length(hp_fir)
    M = size(insig,2);
    insig = [insig; zeros(N,M)]; % group delay compensation: step 1 of 2.
    insig = filter(hp_fir,1,insig); % filtering
    insig = insig(N+1:end,1:M); % group delay compensation: step 2 of 2
end

%%% Stage 1B. Middle ear: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.do_middleear
    [b,a] = middleearfilter(fs,'verhulst2015');
    insig = filter(b,a,insig);
end

%%% Stage 2. Cochlear filter bank - Transmission line model: %%%%%%%%%%%%%%
%         2.1 Signal preprocessing:
fs_in = fs;
if fs ~= keyvals.fs_up
    insig = resample(insig,keyvals.fs_up,fs);
    fs = keyvals.fs_up;
end
stim=transpose(insig); % transpose it (python C-style row major order)

if(ischar(fc_flag)) %if probing all sections 1001 output (1000 sections plus the middle ear)
    switch  fc_flag
        case 'all'
            Nr_sections = 1000;
        case 'half'
            Nr_sections = 500;
        case 'abr'
            Nr_sections = 401;
        otherwise
            error('fc flag not recognised it should be either ''all'',''abr'',''half'', or a numeric array');
    end
    fc_str = fc_flag;
else
    % then fc is a numeric array that will be passed as a column vector
    fc_flag=round(fc_flag(:));
    fc_str = 'custom CF(s)';
    Nr_sections = length(fc_flag);
end

probes=fc_flag;

  % Load poles for the selected hearing profile
poles=amt_load('verhulst2015','Poles.mat','Poles');
if ~isfield(poles.Poles,keyvals.hearing_profile)
  error(['Hearing profile ' keyvals.hearing_profile ' not available.']);
end
sheraPo=poles.Poles.(keyvals.hearing_profile);

channels = Nr_signals;
L_samples = length(stim(1,:));

amt_disp('VERHULST 2015: The following parameters will be passed to Python:',flags.disp);
amt_disp(['  Number of signals to be processed: ',num2str(channels),' channels'],flags.disp);
amt_disp(['  Cochlear hearing profile: ',keyvals.hearing_profile,' (poles between ',num2str(sheraPo(1)),' and ',num2str(sheraPo(end)),')'],flags.disp);
amt_disp(['  Number of auditory nerve fibres: (',num2str([numH,numM,numL]),') (HSR,MSR,LSR)'],flags.disp);
amt_disp(['  Number of cochlear sections to be stored: flag ',num2str(fc_str),' (all=1000, half=500, abr=401)'],flags.disp);
amt_disp(['  Seed number: ',num2str(subject),' (subject ''variable'')'],flags.disp);
amt_disp(['  Irregularities=',num2str(irregularities),' (1=on,0=off), IrrPrct=',num2str(IrrPct)],flags.disp);
amt_disp(['  Non linear type=',num2str(non_linear_type),'(''vel'' or ''disp'')'],flags.disp);
amt_disp(['  Extra variables to be saved: ',num2str(storeflag),' (storeflag)'],flags.disp);
if ~flags.do_silent
  amt_disp(''); % start of volatile display
  amt_disp('Cochlear processing...','volatile');
end

% prepare inputs
in.stim=stim; in.fs=fs; in.channels=channels; in.subject=subject;
in.sheraPo=sheraPo; in.irregularities=irregularities; in.probes=probes;
in.storeflag=storeflag; in.IrrPct=IrrPct;
in.non_linear_type=non_linear_type;
in.version_year=2015;
% define output structure
out.cf=[Nr_sections 1 Nr_signals];
out.v=[Nr_sections L_samples Nr_signals];
if flags.do_y, out.y=[Nr_sections L_samples Nr_signals]; end
if flags.do_oae, out.e=[L_samples 1 Nr_signals]; end
% call python
out=amt_extern('Python','verhulst2015','run_cochlear_model.py',in,out);

fs_abr = keyvals.subfs; % default subfs = 20000 Hz
fs_an  = keyvals.subfs;
DECIMATION = fs/keyvals.subfs;
output = [];
% process the outputs
for i=1:Nr_signals
    if ~flags.do_silent
      amt_disp(['Neural processing ' num2str(i) ' of ' num2str(Nr_signals) '...'],'volatile');
    end
    
    cf=out.cf(:,:,1);
    v=out.v(:,:,i)';
    if flags.do_y, output(i).y=resample(out.y(:,:,i)',fs_in,fs); end
    if flags.do_oae, output(i).oae=resample(out.e(:,:,i),fs_in,fs); end
    output(i).fs_bm=fs_in;

    %%% Stage 3. Inner hair cell model: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    outsig = verhulst2015_ihctransduction(v,fs,keyvals); % unscaled input

    if flags.do_ihc, output(i).ihc = outsig; end

    % Reducing the sampling frequency: Decimation.
    n = 30;
    for ii = 1:size(outsig,2)
        Vm_res(:,ii) = decimate(outsig(:,ii),DECIMATION,n,'fir'); % n-th order FIR filter before decimation
    end
    Vm_res(1:DECIMATION,:) = repmat(outsig(1,:),DECIMATION,1);

    % Now that Vm_res has been decimated we can reduce the sampling frequency
    % of v and ihc (if do_ihc):
    v = resample(v,fs_in,fs);
    if flags.do_v, output(i).v = v; end

    if flags.do_ihc
        output(i).ihc = resample(output(i).ihc,fs_in,fs);
        output(i).fs_ihc=fs_in;
    end

    if flags.do_an || flags.do_cn || flags.do_ic
        %%% Stage 4: Auditory nerve model and Wave I: %%%%%%%%%%%%%%%%%%%%%%%%%
        %% Re-code from ANF_Sarah.py

        % HSR neurones
        if numH ~= 0
            kSR  = keyvals.kSR_H;
            anfH = verhulst2015_auditorynerve(Vm_res,fs_abr,kSR,cf);
        else
            error('There should be at least one HSR neurone, set numH to a non-null value...')
        end

        % MSR neurones
        if numM ~= 0
            kSR  = keyvals.kSR_M;
            anfM = verhulst2015_auditorynerve(Vm_res,fs_abr,kSR,cf);
        else
            anfM = zeros(size(Vm_res));
        end
        % LSR neurones
        if numL ~= 0
            kSR  = keyvals.kSR_L;
            anfL = verhulst2015_auditorynerve(Vm_res,fs_abr,kSR,cf);
        else
            anfL = zeros(size(Vm_res)); % empty array if no anfL, saves some computation power
        end

        if flags.do_anfH
            output(i).anfH = anfH;
        end
        if flags.do_anfM
            output(i).anfM = anfM;
        end
        if flags.do_anfL
            output(i).anfL = anfL;
        end

        outsig = numL*anfL+numM*anfM+numH*anfH;
        if flags.do_an
            output(i).an_summed = outsig;
        end

        % Loading scaling constants for Wave I, III, and V:
        M1 = keyvals.M1;
        M3 = keyvals.M3;
        M5 = keyvals.M5;

        switch Nr_sections
            case {401,500}
                % same cochlear tuning in both configurations:
                cal_factor = 1;
            case 1000
                % more ''dense'' cochlear resolution (twice as many channels):
                cal_factor = 0.5;
            otherwise
                cal_factor = 1;
        end

        output(i).w1 = cal_factor*M1*sum(outsig,2);

        %%% Stage 5: Cochlear nucleus: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Re-code from ICClicksRatio_withalpha.m

        Tex = keyvals.Tex_cn;
        Tin = keyvals.Tin_cn;
        dly = keyvals.dly_cn;
        A   = keyvals.Acn;
        S   = keyvals.Scn;
        outsig = verhulst2015_cn(outsig,fs_abr,Tex,Tin,dly,A,S);
        if flags.do_cn
            if ~iscell(outsig)
                output(i).cn = outsig;
            else
                output(i).cn_mfb = outsig;
                output(i).cn = il_sum_cell(outsig);
            end
        end

        if flags.do_no_mfb
            % Only one CN filter, 'outsig' is numeric:
            output(i).w3 = cal_factor*M3*sum(outsig,2);
        end
        if flags.do_mfb
            error('Not validated yet...')
            % % CN from the modulation filter bank: outsig is a cell variable
            % output(i).w3 = cal_factor*M3*sum(il_sum_cell(outsig),2);
        end

        %%% Stage 6: Inferior Colliculus: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Re-code from ICClicksRatio_withalpha.m
        Tex = keyvals.Tex_ic;
        Tin = keyvals.Tin_ic;
        dly = keyvals.dly_ic;
        A   = keyvals.Aic;
        S   = keyvals.Sic;
        outsig = verhulst2015_ic(outsig,fs_abr,Tex,Tin,dly,A,S);
        if flags.do_ic
            if ~iscell(outsig)
                output(i).ic = outsig;
            else
                output(i).ic_mfb = outsig;
                output(i).ic = il_sum_cell(outsig);
            end

        end
        if flags.do_no_mfb
            % Only one IC filter, 'outsig' is numeric:
            output(i).w5 = cal_factor*M5*sum(outsig,2);
        end
        if flags.do_mfb
            error('Not validated yet...')
            % % IC from the modulation filter bank: outsig is a cell variable
            % output(i).w5 = cal_factor*M5*sum(il_sum_cell(outsig),2);
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    output(i).cf = cf;
    output(i).fs_abr=fs_abr;
    output(i).fs_an=fs_an;
end
amt_disp(); %end of volatile display
output(1).keyvals = keyvals;



