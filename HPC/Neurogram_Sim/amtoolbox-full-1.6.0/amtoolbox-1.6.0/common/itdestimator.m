function [toa_diff,toa,IACC] = itdestimator(Obj,varargin)
%ITDESTIMATOR Estimate ITD from a binaural signal
%   Usage: itd = itdestimator(sofa);
%          itd = itdestimator(sofa, method, ..);
%          [itd, toa, IACC] = itdestimator(..)
%          itd = itdestimator(signal, 'fs', fs, ..); 
%
%   Input parameters:
%     sofa   : Impulse responses (IRs) as a SOFA structure using the 
%              SingleFreeFieldHRIR convention. The ITDs will be estimated 
%              for each IR in sofa.Data.IR.
%
%     signal : *Deprecated*. Binaural signal. Size: (*emitter x receiver x time*). The ITDs between 
%              the two receivers will estimated, for each emitter separately.
%     
%     fs     : *Deprecated*. Sampling rate (in Hz). Required, if signal provided. 
%              Ignored, if sofa provided. 
%
%   Output parameters:
%       itd:        Interaural time difference (in s).
%       toa:        Detected time of arriving (in s). Size: (*emitter x receiver*).
%       IACC:       Interaural cross-correlation (IACC) coefficient
%                   Available only in methods 'MaxIACCr', 'MaxIACCe',
%                   'CenIACCr', 'CenIACCe', 'CenIACC2e'.
%
%   ITDESTIMATOR estimates the interaural time differences (ITDs)
%   from a binaural signal. The estimation is done between the first receiver 
%   (i.e., the left ear) and the second receiver (i.e., the right ear). 
%   Several estimaton methods can be used:
%   
%     'Threshold'  Differences between the time each IR crosses a threshold below its peak. 
%                  For more details, see Andreopoulou and Katz (2017). Default. 
%
%     'Cen_e2'     Time difference between the two centroids calculated on the envelopes.
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'MaxIACCr'   Delay of the peak of the IACC calculated on the raw IRs.
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'MaxIACCe'   Delay of the peak of the IACC calculated on the envelopes.
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'CenIACCr'   Delay of the centroid of the IACC calculated on the raw IRs.
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'CenIACCe'   Delay of the centroid of the IACC calculated on the envelopes.
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'CenIACC2e'  Delay of the centroid of the squared IACC calculated on the envelopes
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'PhminXcor'  Interaural difference between the TOAs each calculated as the 
%                  delay of the peak of the cross correlation between the raw and 
%                  minumum-phase version of the IR. 
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'IRGD'       Time difference between the average group delays
%                  For more details, see Andreopoulou and Katz (2017).
%
%     'pausch2022'   As 'MaxIACCr', but applied on badnpass-filtered and then 5-times upsampled IRs. 
%                    For more details, see Pausch et al. (2022). 
%
%
%   ITDESTIMATOR also accepts the following optional flags:
%
%     'debug' Output more information about the calculations.
%
%     'lp'    Use lowpass filtered IRs for the calculations. Default. 
%             Does not apply in 'pausch2022', which uses bandpass filtered IRs.
%
%     'bb'    Do not apply any filtering to the IRs. 
%             Does not apply in 'pausch2022', which uses bandpass filtered IRs.
%
%     'fp'    Applies to 'Threshold' only: Use findpeak() to find the peak in each IR. 
%
%     'hp'    Applies to 'Threshold' only: Use max() to find the peak in each IR. Default.
%
%
%   ITDESTIMATOR also takes the following optional key-value pairs:
%
%     'threshlvl',thr  Applies to 'Threshold' only: Threshold level (in dB). Default: -10 dB. 
%
%     'butterpoly',n   In 'pausch2022': The order of the band-pass Butterworth filter. 
%                      In other methods: The order of the low-pass Butterworth filter. 
%                      n must be between 2 and 10. Default is 10. 
%
%     'upper_cutfreq',fu  Applies to 'lp' only: Lowpass cutoff frequency (in Hz). 
%                         Default: 3000 Hz. 
%
%     'lower_cutfreq',fl  Applies to 'IRGD' and 'paush2022' only: Highpass cutoff frequency (in Hz).
%                         Default: 1000 Hz.   
%
%   
%   Requirements: 
%   -------------
%
%   SOFA Toolbox from http://sourceforge.net/projects/sofacoustics 
%   
%   
%   Example:
%   --------
%
%   This is an example of ITD calculation for an HRTF set:
%
%     Obj = amt_load('baumgartner2017','hrtf b_nh15.sofa');
%     toa_diff = itdestimator(Obj,'MaxIACCe','lp','upper_cutfreq',3000)
%   
%   With these settings, the estimator uses the MaxIAACe method and applies
%   a lowpass with a cutoff frequency of 3 kHz.
%   
%   The output Obj is structured as in Obj.Data.IR input. 
%   To select, for example, only data on the horizontal
%   plane data:
%
%     plane_idx = find( Obj.SourcePosition(:,2) == 0 );
%     plane_angle = Obj.SourcePosition(plane_idx,1);
%
%   References:
%     A. Andreopoulou and B. F. G. Katz. Identification of perceptually
%     relevant methods of inter-aural time difference estimation. The Journal
%     of the Acoustical Society of America, 142(2):588--598, 08 2017.
%     
%     F. Pausch, S. Doma, and J. Fels. Hybrid multi-harmonic model for the
%     prediction of interaural time differences in individual behind-the-ear
%     hearing-aid-related transfer functions. Acta Acust., 6:34, 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/itdestimator.php


%   #Author: Laurin Steidle
%   #Author: Robert Baumgartner (data matrix option)
%   #Author: Piotr Majdak (2022): enhanced the robustness in the threshold method
%   #Author: Florian Pausch (2023): pausch2022 and optional high-pass filtering added

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 



% ---------------------- ltfatarghelper -------------------------------
definput.import = {'itdestimator'}; % load defaults from arg_itdestimator
[flags,kv]=ltfatarghelper({},definput,varargin);


% ---------------------- Renaming input parameters ---------------------

if isstruct(Obj)
  pos = Obj.API.M;
  ear = Obj.API.R;
  Ns  = Obj.API.N;
  IR = Obj.Data.IR;
  fs  = Obj.Data.SamplingRate;
else
  pos = size(Obj,1);
  ear = size(Obj,2);
  Ns  = size(Obj,3);
  IR = Obj;
  if isempty(kv.fs)
    error('RB: No sampling rate (fs) provided.')
  end
  fs  = kv.fs;
end

% ---------------------- Initializing variables -----------------------

toa = zeros(pos,ear);
toa_diff = zeros(pos,1);
IACC = zeros(pos,1);

amt_disp('itdestimator:',flags.disp);

% ---------------------- Applying low-pass filter ----------------------

if flags.do_lp && ~strcmp(flags.mode,'pausch2022')
    amt_disp('  Applying Butterworth low pass',flags.disp)
    amt_disp(strcat('  Polynomial order of Butterworth filter: ',num2str(kv.butterpoly)),flags.disp)
    amt_disp(strcat('  Cut-off frequency is: ',num2str(kv.upper_cutfreq),' Hz'),flags.disp)
    cut_off_freq_norm = kv.upper_cutfreq/(fs/2);
    [lp_a,lp_b] = butter(kv.butterpoly,cut_off_freq_norm);
    f_ir = zeros(pos,ear,Ns);
    for ii=1:pos
        for jj=1:ear  
            sir = squeeze( IR(ii,jj,:) );
            f_sir = filter(lp_a,lp_b,sir);
            f_ir(ii,jj,:) = f_sir;
        end
    end

else
    amt_disp('  No low-pass filter is applied',flags.disp)
    f_ir = IR;
end

% ---------------------- Applying band-pass filter ----------------------

if strcmp(flags.mode,'pausch2022')
    amt_disp('  Applying Butterworth band pass',flags.disp)
    amt_disp(strcat('  Polynomial order of Butterworth filter: ',num2str(kv.butterpoly)),flags.disp)
    amt_disp(strcat('  Cut-off frequencies are: ',num2str(kv.lower_cutfreq),...
        ' and ', num2str(kv.upper_cutfreq), ' Hz'),flags.disp)

    h_bp = fdesign.bandpass('n,f3dB1,f3dB2',kv.butterpoly,kv.lower_cutfreq,kv.upper_cutfreq,fs);
    Filter.Hd = design(h_bp,'butter');

    f_ir_bp = zeros(pos,ear,Ns);
    for ii=1:pos
        for jj=1:ear  
            sir = squeeze( f_ir(ii,jj,:) );
            f_ir_bp(ii,jj,:) = filter(Filter.Hd,sir);
        end
    end
    f_ir = f_ir_bp;
end

% ---------------------- Estimating ITDs -------------------------------
% ---------------------------------------------------------------------

% ---------------------- Threshold ------------------------------------
switch(flags.mode)
    case 'Threshold'
        amt_disp('  Threshold mode',flags.disp)
        amt_disp(strcat('  Threshold level is: ',num2str(kv.threshlvl),'dB'),flags.disp)

        if flags.do_fp
            for ii=1:pos
                 for jj=1:ear
                    indB = 0.5*mag2db(squeeze(f_ir(ii,jj,:)).^2);
                    [~,B] = findpeaks(indB);
                    th_value = indB(B(1)) + kv.threshlvl;
                    toa(ii,jj) = find(indB>th_value,1);
                end
                toa_diff(ii) = toa(ii,1) - toa(ii,2);     
            end

        else
            for ii=1:pos
                for jj=1:ear
                    indB = 0.5*mag2db(squeeze(f_ir(ii,jj,:)).^2); 
                    th_value = max(indB) + kv.threshlvl;
                    idx=find(indB>th_value,1);
                    if isempty(idx), idx=NaN; end
                    toa(ii,jj) = idx; 
                end
                toa_diff(ii) = toa(ii,1) - toa(ii,2);     
            end
        end

% ---------------------- Centroid ----------------------------        
    case 'Cen_e2'
        amt_disp('  Cen-e2 mode',flags.disp)
        for ii=1:pos
            for jj = 1:ear
                e_sir_sq = abs(hilbert(squeeze(f_ir(ii,jj,:))).^2);
                toa(ii,jj) = centroid(transpose(1:Ns),e_sir_sq);
            end
            toa_diff(ii) = toa(ii,1) - toa(ii,2);     
        end        

% ---------------------- Cross-Correlation ----------------------------        
    case 'MaxIACCr'
        amt_disp('  MaxIACCr mode',flags.disp)
        for ii=1:pos                
            cc = xcorr(squeeze(f_ir(ii,1,:)),squeeze(f_ir(ii,2,:)));
            [IACC(ii),idx_lag] = max(abs(cc));
            toa_diff(ii) = idx_lag - Ns;                
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end

    case 'MaxIACCe'
        amt_disp('  MaxIACCe mode',flags.disp)
        for ii=1:pos
            e_sir1 = abs(hilbert(squeeze(f_ir(ii,1,:))));
            e_sir2 = abs(hilbert(squeeze(f_ir(ii,2,:))));
            cc = xcorr(e_sir1,e_sir2);
            [IACC(ii),idx_lag] = max(abs(cc));
            toa_diff(ii) = idx_lag - Ns;
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end

     case 'pausch2022'
        amt_disp('  pausch2022 mode',flags.disp)

        % upsample and interpolate data
        data_time_len = Ns/fs;
        data_time_vec = (1:Ns)/fs;
        fs_upsampled = 5*fs;

        time_interp = 0:1/fs_upsampled:data_time_len;

        data_time_interp = interp1(data_time_vec,permute(f_ir,[3,1,2]),time_interp,'spline');
        data_time_interp_e = data_time_interp.^2;
        
        for ii=1:pos
            e_sir1 = squeeze(data_time_interp_e(:,ii,1));
            e_sir2 = squeeze(data_time_interp_e(:,ii,2));

            corr_ir = xcorr(e_sir1, e_sir2);

            [IACC(ii), idx_lag] = max(corr_ir);    
            toa_diff(ii) = (idx_lag - numel(time_interp));  
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end

    case 'CenIACCr'
        amt_disp('  CenIACCr mode',flags.disp)
        x = transpose(1:(Ns*2-1));
        for ii=1:pos                
            cc = xcorr(squeeze(f_ir(ii,1,:)),squeeze(f_ir(ii,2,:)));
            pos_cc = abs(cc);
            IACC(ii) = max(pos_cc);
            toa_diff(ii) = centroid(x,pos_cc)-Ns;
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end


    case 'CenIACCe'
        amt_disp('  CenIACCe mode',flags.disp)
        x = transpose(1:(Ns*2-1));
        for ii=1:pos
            e_sir1 = abs(hilbert(squeeze(f_ir(ii,1,:))));
            e_sir2 = abs(hilbert(squeeze(f_ir(ii,2,:))));
            cc = xcorr(e_sir1,e_sir2);
            IACC(ii) = max(abs(cc));
            toa_diff(ii) = centroid(x,abs(cc))-Ns;
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end


    case 'CenIACC2e'
        amt_disp('  CenIACC2e mode',flags.disp)
        x = transpose(1:(Ns*2-1));
        for ii=1:pos              
            e_sir1 = abs(hilbert(squeeze(f_ir(ii,1,:))));
            e_sir2 = abs(hilbert(squeeze(f_ir(ii,2,:))));           
            cc = xcorr(e_sir1,e_sir2).^2;
            IACC(ii) = max(abs(cc));
            toa_diff(ii) = centroid(x,abs(cc))-Ns;    
        end
        if flags.do_guesstoa
            toa = guesstoa(toa_diff,toa, kv.avgtoa);
        end


    case 'PhminXcor'
        amt_disp('  PhminXcor mode',flags.disp)
        ir_min=ARI_MinimalPhase(Obj);
        for ii=1:pos
            for jj=1:ear                    
                cc = xcorr(squeeze(IR(ii,jj,:)),squeeze(ir_min(ii,jj,:)));
                [~,toa(ii,jj)] = max(abs(cc));
            end
            toa_diff(ii) = toa(ii,1) - toa(ii,2);
        end


% ---------------------- Groupdelay -----------------------------------
    case 'IRGD'
        amt_disp('  IRGD mode',flags.disp)
        for ii = 1:pos
            for jj = 1:ear
                f_sir = squeeze( f_ir(ii,jj,:) );
                [gd,w] = grpdelay(transpose(double(f_sir)),1,Ns,fs);
                toa(ii,jj)=mean(gd(find(w>kv.lower_cutfreq): ...
                                    find(w>kv.upper_cutfreq)));
            end
            toa_diff(ii) = toa(ii,1) - toa(ii,2);
        end
end

if ~strcmp(flags.mode,'pausch2022')
    toa_diff = toa_diff/fs;
    toa = toa/fs;
else
    toa_diff = toa_diff/fs_upsampled;
    toa = toa/fs_upsampled;
end




% -------------------------------------------------------------------------
% ---------------------- Functions ----------------------------------------
% -------------------------------------------------------------------------

% ---------------------- Centroid -----------------------------------------
function idx_cent = centroid(x,y)
idx_cent = sum(x.*y)/sum(y);

% ---------------------- guess toa ----------------------------------------
function toa = guesstoa(toa_diff,toa, avgtoa)
toa(:,1) = toa(:,1) + avgtoa + toa_diff/2;
toa(:,2) = toa(:,2) + avgtoa - toa_diff/2;
    
% ---------------------- Create minimal phase -----------------------------
% as used in ziegelwanger2014
function hMmin=ARI_MinimalPhase(Obj)
hM=Obj.Data.IR;
hMmin=hM;

for jj=1:Obj.API.R
    for ii=1:Obj.API.M
        h=squeeze(hM(ii,jj,:));

        amp1=abs(fft(h));
        amp2=amp1;

        an2u=-imag(hilbert(log(amp1)));
        an2u=an2u(1:floor(length(h)/2)+1);

        an3u=[an2u; -flipud(an2u(2:end+mod(length(h),2)-1))];
        an3=an3u-round(an3u/2/pi)*2*pi;

        amp2=amp2(1:floor(length(h)/2)+1);
        amp3=[amp2; flipud(amp2(2:end+mod(length(h),2)-1))];

        h2=real(ifft(amp3.*exp(1i*an3)));
        hMmin(ii,jj,:)=h2(1:Obj.API.N);
    end
end


