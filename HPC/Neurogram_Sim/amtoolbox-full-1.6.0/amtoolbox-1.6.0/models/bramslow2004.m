function [audout, fc] = bramslow2004(insig, fs, varargin)
%bramslow2004 Loudness model considering hearing loss (AUDMOD)
%
%   Usage: [audout, fc] = bramslow2004(insig,fs);
%          [audout, fc] = bramslow2004(insig,fs,...);
%
%   Input parameters:
%     insig     : Acoustic signal (in Pa). 
%     fs        : Sampling rate (in Hz).
%
%   Output parameters:
%     audout : Structure containing the following:
%
%              - EC*: Row vector with ERB rates (in Cams) of the filters (typically 3 to 32). 
%                Size: NoChan (defined by the input parameter 'NoChan', 
%                default: 30 channels). 
%
%              - fc*: Row vector with center frequencies (in Hz) of the filters. Size: NoChan.
%
%              - ERB_R*: Row vector with the excitation pattern at the hearing thresholds (in dB). Size: NoChan.
%
%              - ERB_UCL*: Row vector with the excitation pattern at the uncomfortabe levels (UCLs, in dB). Size: NoChan.
%
%              - FFT_Power*: Column vector with total powers (in dB) of individual signal frames. 
%                Size: frames, being floor(insig/In_FrmSize)
%                defined by the input parameter 'In_FrmSize' (default: 8192 samples).
%
%              - ERB_SPL*: Matrix with SPLs in ERB bands, used for level dependencies of filterbank (in dB).
%                Size: (*frames x NoChan*). 
%
%              - ERB_Power*: Vector with the total power (in dB) in ERB bands. Size: (*frames x 1*).
%
%              - Roex_SPL*: Matrix with SPLs (in dB) of the excitation patterns (from the Roex filters). 
%                Size: (*frames x NoChan*). 
%
%              - Total_Excitation*: Column vector with the total SPL (in dB) of the excitation
%                of the individual signal frames. Size: frames.
%
%              - ERB_Loudness*: Matrix with the specific loudness (in sone) per ERB band and
%                the individual signal frames. Size: (*frames x NoChan*). 
%                
%              - Loudness*: Column vector with the total loudness (in sone) of the 
%                individual signal frames. Size: frames. 
%
%     fc     : Output channel center frequencies (in Hz). The same as audout.fc.
%
%
%   audout = BRAMSLOW2004(insig,fs) computes the internal representation of the
%   signal insig sampled at a frequency of fs. The main output is 
%   audout.Loudness which returns the loudness (in sone) of the individual
%   frames of the input signal insig. 
%
%   BRAMSLOW2004(..) also accepts the following flags among many others:
%
%     'no_debug'      No display of debugging information. Default. 
%
%     'debug'         Display additional debugging information. 
%                     Opposite of 'no_debug'.
%
%   See also other flags and key-value pairs in arg_BRAMSLOW2004.
%
%
%   [audout,fc] = BRAMSLOW2004(...) additionally returns the center
%   frequencies of the filterbank.
%
%   The processing blocks in the model are as follows:
%
%   - FFT spectrum, e.g., 512 frequencies to obtain a power spectrum.
%
%   - Corrections for sound-field type, coupler type, and static transmission 
%     factors (e.g., middle ear), applied in the frequency domain.
%
%   - The signal power is determined in 1 ERB wide bands, by summing the 
%     power spectrum (f) within the limits of each band.  These powers are 
%     used to adjust the filterbank.
% 
%   - The FFT power spectrum is multiplied by a filterbank, consisting of 
%     30 auditory filters whose shape depends on hearing loss and on the 
%     signal power. The filterbank concept is based on work from Moore, 
%     Glasberg, Patterson and others at the University of Cambridge and uses
%     rounded exponential (roex) filters. The roex filterbank output is 
%     called the excitation pattern.
%
%   - The parameters for hearing loss (thresholds) are converted from dB HL
%     to dB SPL and used to modify frequency selectivity in the filterbank 
%     and sensitivity in the loudness function.
%
%   - The roex filterbank output (E) is passed on to the specific loudness 
%     function converting excitation in each channel to specific loudness (N').
%     The total loudness of an incoming signal is calculated by summing the 
%     specific loudness across bands.
%
%
%
%   See also: demo_bramslow2004 exp_bramslow2004 
%
%   References:
%     L. Bramsløw Nielsen. An Auditory Model with Hearing Loss. Technical
%     report, Eriksholm Research Centre, Snekkersten, 1993.
%     
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%     L. Bramsløw. An auditory loudness model with hearing loss. In
%     Baltic-Nordic Acoustics Meeting, pages 318--323, 2024.
%     
%     B. R. Glasberg and B. Moore. Derivation of auditory filter shapes from
%     notched-noise data. Hearing Research, 47(1-2):103--138, 1990.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/bramslow2004.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Verified
%   #Requirements: M-Signal
%   #Author: Lars Bramslow (1993): Original C code
%   #Author: Graham Naylor (1994): Updates to model
%   #Author: Tayyib Arshad (2007): Ported to Matlab
%   #Author: Lars Bramslow (2024): Integration into AMT
%   #Author: Piotr Majdak (2024): Integration for AMT 1.6.0

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%% ------ Checking of input parameters and setting defaults ------------
if nargin<2
    error('%s: Too few input arguments.',upper(mfilename));
end

if ~isnumeric(insig)
    error('%s: insig must be numeric.',upper(mfilename));
end

if ~isnumeric(fs) || ~isscalar(fs) || fs<=0
    error('%s: fs must be a positive scalar.',upper(mfilename));
end

definput.import={'bramslow2004'}; % load defaults from arg_bramslow2004

[flags,keyvals]  = ltfatarghelper({},definput,varargin);

InSamps = length(insig);
NoFrames= floor(InSamps/keyvals.In_FrmSize);    % labw / szymon: skip last partial frame

%% default matlab version here
if flags.do_MATLAB
    
      % initialization
    EXTAGRAMPOINTS = 13;
    E_Bin = [keyvals.In_FrmSize,1];    
    for Chan = 1:1:EXTAGRAMPOINTS
          % from dB HL to dB SPL in 4153 artificial ear (ISO 389)
        keyvals.AGLoss(Chan) = keyvals.AGLoss(Chan) + keyvals.RET4153(Chan);
        keyvals.AG_UCL(Chan) = keyvals.AG_UCL(Chan) + keyvals.RET4153(Chan);
    end
      %   Calc fc (in Hz)
    for Chan = 1:1:keyvals.NoChan
        audout.EC(Chan)  = Chan + (keyvals.E_Beg-1);
         audout.fc(Chan) = erbrate2f(audout.EC(Chan));
    end
    
    AGF = [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500];
    AGFs_E = f2erbrate(AGF);
    
    if keyvals.Process == 0
        AvgFrames = 'ALL';
        FramesToAvg = 1;
    else
        if keyvals.Process == 1
            AvgFrames = 'SINGLE';
            FramesToAvg = 1;
        else
            AvgFrames = 'SINGLE';
            FramesToAvg = keyvals.Process;
        end
    end
    
      %   Read entire input signal into matrix of frames
    [In_Buffer, In_NoSamps, keyvals.RMS]=bramslow2004_getframe(insig, keyvals.In_FrmSize, NoFrames, keyvals.Cal_RMS, keyvals.RMS, keyvals.Cal_dB); 
    amt_disp(sprintf('     bramslow2004: Read signal, duration %2.1f s', In_NoSamps/fs),flags.disp);    
    
    for j = 1:(keyvals.In_FrmSize/2)
        f_Hz = j*fs/keyvals.In_FrmSize;
        E_Bin(j) = f2erbrate(f_Hz);
    end
      % Filters do not widen with loss here
    Widen = false;
    
    amt_disp('     bramslow2004: Initialize: Calibrating 0 dB SPL, HTL and UCL...',flags.disp);
    ts = tic;
    E_0=bramslow2004_exc0dbspl(keyvals.In_FrmSize, fs, flags.TransFact, Widen, keyvals.AGLoss, ...
	    keyvals.RET4153, AGFs_E, keyvals.NoChan, keyvals.E_Beg, keyvals.E_End, E_Bin(1:end));
    
    amt_disp('     bramslow2004: Calculating HTL...',flags.disp);
    [ERB_R, E_TQ]=bramslow2004_htl(keyvals.In_FrmSize, fs, flags.TransFact, Widen, keyvals.AGLoss, keyvals.RET4153, AGFs_E, keyvals.NoChan, keyvals.E_Beg, keyvals.E_End, E_Bin(1:end));
    audout.ERB_R = ERB_R'; 
    
    amt_disp('     bramslow2004: Calculating UCL...',flags.disp);
    [audout.ERB_UCL]=bramslow2004_ucl(keyvals.In_FrmSize, fs, flags.TransFact, keyvals.NoChan, Widen, keyvals.AG_UCL,keyvals.AGLoss, keyvals.RET4153, AGFs_E, keyvals.E_Beg, keyvals.E_End, E_Bin(1:end));
    telapsed = toc(ts);
    amt_disp(sprintf('     bramslow2004: Initialization done in %2.3f s', telapsed),flags.disp);
    
      % Normal widen from here
    Widen = true;
    
    PowerSpec = zeros(floor(size(In_Buffer,1)/FramesToAvg), keyvals.In_FrmSize/2);
    Power_Spec = PowerSpec;
    for CurFrame = 1:1:size(In_Buffer,1)
        Power_Spec(CurFrame,:) = bramslow2004_powerspectrum(In_Buffer(CurFrame,:));
    end
    
      %   calcualting power spectra...
    if strcmp (AvgFrames, 'ALL')
          % Power spectrum averaging
        amt_disp('     bramslow2004: Power spectrum averaging...',flags.disp);
        PowerSpec = sum (Power_Spec(1:end,:))./NoFrames;
    else
          % Loudness averaging / frame averaging
        for Currframe = 1:1:(ceil(In_NoSamps/keyvals.In_FrmSize)-1)
              % Spectrum averaging 
            if strcmp (AvgFrames, 'SINGLE')
                if FramesToAvg < 2
                    PowerSpec(Currframe,:) = Power_Spec(Currframe,:);
                else
                    a = 1;
                    b = FramesToAvg;
                    
                    for avg = 1:1: ((ceil(In_NoSamps/keyvals.In_FrmSize)-1)/FramesToAvg)
                        PowerSpec(avg,:) = sum(Power_Spec(a:b,:))./FramesToAvg;
                        a = a + FramesToAvg;
                        b = b + FramesToAvg;
                    end
                end
            end
        end
    end
    siz = size(PowerSpec);
    siz = siz(1);
    
      % Process signal frame-by-frame----------------------------------------
    amt_disp(sprintf('     bramslow2004: Loudness calculation %d frames', siz),flags.disp);
    ts = tic;
    audout.FFT_Power=zeros(siz,1); 
    audout.ERB_Power=zeros(siz,1);
    audout.Loudness=zeros(siz,1); 
    audout.Total_Excitation=zeros(siz,1);
    for frame = 1:1:siz
          % Input power
        audout.FFT_Power(frame) = 10*log10(sum(PowerSpec(frame,:)));        
          % Coupler correction
        PowerSpec(frame,:) = bramslow2004_couplcorr(PowerSpec(frame,:), flags.Coupler, keyvals.In_FrmSize, fs);        
          %   Static frequency weighting (equal loudness)
        PowerSpec(frame,:) = bramslow2004_equloudn(PowerSpec(frame,:), flags.TransFact, keyvals.In_FrmSize, fs);        
          %   Energy in ERB bands
        [audout.ERB_SPL(frame,1:keyvals.NoChan), audout.ERB_Power(frame)] = bramslow2004_erbenergy(PowerSpec(frame,:), keyvals.NoChan, keyvals.In_FrmSize, fs, Widen, keyvals.AGLoss, keyvals.RET4153, AGFs_E,  keyvals.E_Beg, keyvals.E_End); 
          %   Excitation pattern from roex filters
        [audout.Roex_SPL(frame,:), E_Vector, HTLL]=bramslow2004_roexfilt(PowerSpec(frame,:), audout.ERB_SPL(frame,:), keyvals.In_FrmSize, fs, keyvals.NoChan, Widen, AGFs_E, keyvals.AGLoss, keyvals.RET4153, keyvals.E_Beg, keyvals.E_End, E_Bin);
          %   Specific and total loudness
        [audout.ERB_Loudness(frame,:), TotLoudn]= bramslow2004_specloudn(E_Vector, E_0, E_TQ, audout.ERB_UCL, HTLL, keyvals.NoChan, keyvals.E_Beg, keyvals.E_End, keyvals.Binaural);
        audout.Loudness(frame) = TotLoudn;        
        [~, audout.Total_Excitation(frame)]=bramslow2004_excpatrn(E_Vector, keyvals.NoChan);
        
    end  % frame
    
    telapsed = toc(ts);
    amt_disp(sprintf('     bramslow2004: Loudness calc done in %2.3f s, %2.3f s per frame', telapsed, telapsed/siz),flags.disp);
    fc = audout.fc;
    
end % if do_MATLAB

%% Python version
if flags.do_PYTHON
      % should be the call mechanism..:
    in.keyvals = keyvals;
    in.flags = flags;
    audout = [];  % empty for now
%     audout=amt_extern('Python','bramslow2004','pyaudmod.py',in,audout); % to be implemented
end

amt_disp('     bramslow2004: Done',flags.disp);


