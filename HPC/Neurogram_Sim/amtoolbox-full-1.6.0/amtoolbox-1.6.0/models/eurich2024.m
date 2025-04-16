function [feature, mpar] = eurich2024(mRef, mTest,fs,mpar)
%eurich2024  Efficient monaural and binaural model for audio quality assessment (eMoBi-Q) 
%   Usage: [features, mpar] = eurich2024(mRef, mTest, fs);
%          [features, mpar] = eurich2024(mRef, mTest, fs, mpar)
%
%   Input parameters:
%     mRef      : Binaural audio reference signal. Size: (*time x ear*).
%     mTest     : Binaural audio test signal. Size: (*time x ear*).
%     fs        : Sampling rate (in Hz) of mRef and mTest.
%     mpar      : Optional structure with the model parameters. Defaults: as in arg_eurich2024. 
%                 The following fields are supported:
%
%                 - fs*: Sampling frequency (in Hz) of model.
%
%                 - GT_Filters_per_ERB_aud*: Spacing (in ERB) of peripheral filter central frequencies.
%
%                 - GT_bandwidth_factor*: Factor of the Gammatone filter bandwidth (relative to the bandwidth of 79 Hz at center frequency of 500 Hz).
%
%                 - GT_lowest_center_frequency*: Center frequency (in Hz) of lowest filter in the Gammatone filterbank.
%
%                 - GT_highest_center_frequency*: Center frequency (in Hz) of highest filter in the Gammatone filterbank.
%
%                 - GT_fix_center_frequency*: Center frequency (in Hz) of the fixed filter in the Gammatone filterbank.
%
%                 - GT_filterorder*: Filter order of the Gammatone filterbank.
%
%                 - env_lowpass_fc*: Cutoff frequency (in Hz) of the envelope lowpass filter.
%
%                 - env_lowpass_n*: Order of the envelope lowpass filter.
%
%                 - mso_rolloff*: Frequency threshold (in Hz) below that Gammas are calculated based on fine structure
%                   and above that Gammas are calculated based on envelopes.
%
%                 - interference_sigma*: Standard deviation of the Gaussian window used for the across-frequency incoherence interference.
%
%                 - iKernelThresh*: Threshold above which a value of the Gaussian filter window is used.
%
%                 - rho_max*: Upper limit of encoded interaural coherence (represents existence of internal noise).
%
%                 - ild_lim*: Limit for the ILD (in dB).
%
%                 - FrameLen*: Length (in samples) of consecutive rectangular time frames.
%
%
%   Output parameters:
%     features  : Structure containing the features calculated by the model, containing: 
%
%                 - d_gamma*:   Gamma features. Size: (*m x n*), with m being the time frames and n the frequency bands.
%
%                 - d_ild*:     ILD features. Size: (*m x n*). 
%
%                 - d_snr*:     SNR features. Size: (*m x n*).
%
%     mpar     : Structure with the updated model parameters.
%
%
%   Note: if mpar is not provided, it is loaded from arg_EURICH2024. 
%
%   See also: exp_eurich2024 eurich2024_backend 
%
%   References:
%     B. Eurich, S. D. Ewert, M. Dietz, and T. Biberger. A computationally
%     efficient model for combined assessment of monaural and binaural audio
%     quality. Journal of the Audio Engineering Society, 100(4):2381--2396,
%     June 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/eurich2024.php


%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Qualified
%   #Author: Bernhard Eurich (2024): Original implementation and integration in the AMT.
%   #Author: Piotr Majdak (2024): Integration for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%% load model parameters from arg_eurich2024
if ~exist('mpar','var'), mpar = arg_eurich2024; end

%% Create the input parameters for the processing
mpar.fs = fs;
sRef.data = mRef;
sTest.data = mTest;
stim_ref = sRef; 
stim_test = sTest; 
framel = size(stim_test.data,1);
if ~isempty(mpar.FrameLen) & mpar.FrameLen*mpar.fs < framel
    framel = mpar.FrameLen*mpar.fs;
end

%% ==== GAMMATONE FILTERBANK ====
sFB = hohmann2002(mpar.fs,mpar.GT_lowest_center_frequency,mpar.GT_fix_center_frequency,...
      mpar.GT_highest_center_frequency, mpar.GT_filters_per_ERBaud,'bandwidth_factor',mpar.GT_bwfactor);
  % preallocation
mPeriphFiltSig_ref = zeros(size(stim_ref.data,1),length(sFB.center_frequencies_hz),size(stim_ref.data,2)); %
mPeriphFiltSig_test = zeros(size(stim_test.data,1),length(sFB.center_frequencies_hz),size(stim_test.data,2)); %
  % create the lowpass filter for the envelope
[b,a] = butter(mpar.env_lowpass_n,mpar.env_lowpass_fc/(mpar.fs/2));
  % apply the filterbank on stimulus
mPeriphFiltSig_ref(:,:,1)  = hohmann2002_process(sFB,stim_ref.data(:,1));
mPeriphFiltSig_test(:,:,1) = hohmann2002_process(sFB,stim_test.data(:,1));
if size(stim_ref.data,2) == 2
    mPeriphFiltSig_ref(:,:,2)  = hohmann2002_process(sFB,stim_ref.data(:,2));
    mPeriphFiltSig_test(:,:,2) = hohmann2002_process(sFB,stim_test.data(:,2));
end
  % extract envelope; Gamma feature for high frequencies (--> LSO) requires analytical representation
complex_envelope_ref =  hilbert(abs(mPeriphFiltSig_ref));
complex_envelope_test = hilbert(abs(mPeriphFiltSig_test));
  % low-pass filtering of envelope
filtered_complex_envelope_ref =  filter(b,a,complex_envelope_ref);
filtered_complex_envelope_test = filter(b,a,complex_envelope_test);
  % both Power and ILD features use this filtered envelope. Only Gamma uses the non-filtered envelope above 1300Hz.
he_ref  = real(filtered_complex_envelope_ref)./sqrt(2);
he_test = real(filtered_complex_envelope_test)./sqrt(2);


%% run for the reference and the test signal 
for test_or_ref = 1:2
    if isequal(test_or_ref,1)
        mPeriphFiltSig = mPeriphFiltSig_ref;
        filtered_complex_envelope = filtered_complex_envelope_ref;
        he = he_ref;
    elseif isequal(test_or_ref,2)
        mPeriphFiltSig = mPeriphFiltSig_test;
        filtered_complex_envelope = filtered_complex_envelope_test;
        % he_cat = he_test_cat;
        he = he_test;
    else
        error('test_or_ref must equal 1 or 2.')
    end

    % ==== THE BINAURAL PATHWAY ====

    numFrames   = floor(size(stim_ref.data,1)/framel)-1;
    numChannels = length(sFB.center_frequencies_hz);

    Power       = NaN(numFrames,numChannels,1);
    Power_ild   = NaN(numFrames, numChannels,2);

    mBP = NaN(size(Power));
    mild = mBP;
      % loop over the frames
    for f = 1:numFrames
        frame = (f-1)*framel+1:f*framel;
        if size(mPeriphFiltSig,3) == 2
            % Gamma feature (Eq. 4): 
            gamma_mso = mean(mPeriphFiltSig(frame,:,1) .* conj(mPeriphFiltSig(frame,:,2))) ...
                ./ sqrt(mean(abs(mPeriphFiltSig(frame,:,1)).^2) .* mean(abs(mPeriphFiltSig(frame,:,2)).^2));
            gamma_lso =  mean(filtered_complex_envelope(frame,:,1) .* conj(filtered_complex_envelope(frame,:,2))) ...
                ./ sqrt(mean(abs(filtered_complex_envelope(frame,:,1)).^2) .* mean(abs(filtered_complex_envelope(frame,:,2)).^2));
              % combined gamma feature: TFS for <1500 Hz, Envelope for >1500Hz (assuming infinitley steep roll-off)
            channels_below_rolloff = sFB.center_frequencies_hz < mpar.mso_rolloff;
            gamma(find(channels_below_rolloff))    = gamma_mso(find(channels_below_rolloff));
            gamma(find(channels_below_rolloff==0)) = gamma_lso(find(channels_below_rolloff==0));
              % across-channel interference -- not used in the eMoBi-Q but available
            channel_index = 1:length(sFB.center_frequencies_hz); % to consider all channels

            % for-loop represents convolution with a window:
            % * limit coherence with respect to one channel (index g)
            % * create weighting window
            % * apply window to coherence where channel g is center
            % * --> for every channel --> same effect as convolution but now with coherence limitation applied with respect to each channel
            % before_incinf = toc;
            % interference window is moving across the frequency bands
            for g = channel_index
                  % only lower off-frequency coherence is considered (compare with on-freq and take lower)
                coherence_lower = min(abs(gamma),abs(gamma(g)));
                  % need odd number for weighting window
                flS = length(sFB.center_frequencies_hz);
                flidx = mod(flS,2)<1;
                mpar.KernelLen = flS - flidx;
                if mpar.KernelLen == 1 | mpar.interference_sigma <= 0.11
                    windows = [1; 1];
                    vExpWin_ge = 1;
                else
                    windows = zeros(3,300);
                      % window for channel interaction
                    Window_range = [-floor(mpar.KernelLen/2):ceil(mpar.KernelLen/2)-1];
                    vExpWin0 = exp(-abs(Window_range)/(mpar.filters_per_ERBaud*mpar.AcrChannel_sigma));
                    vExpWin_ge   = vExpWin0(ge(vExpWin0,mpar.iKernelThresh));
                      % put the (3) available window functions in matrix
                    windows(2,1:length(vExpWin_ge)) = vExpWin_ge;
                end
                  % prepare placement of selected window: preallocate for all channels plus twice the half window length
                window = zeros(1,size(channel_index,2)+length(vExpWin_ge)-1);
                  % place the window according to g (= temporary center channel)
                one_sided_win_len = floor(length(vExpWin_ge)/2);
                center_idx = g+one_sided_win_len;
                window(center_idx-one_sided_win_len:center_idx+one_sided_win_len) = nonzeros(windows(mpar.window,:));
                  % chose right excerpt of window
                window_cut = window(one_sided_win_len+1:end-one_sided_win_len);
                  % normalization
                window_cut_areanorm = window_cut./sum(window_cut);
                  % interference happening here
                coherence_interfered(g) = sum(coherence_lower .* window_cut_areanorm);
                  % select current interfered channel, apply internal noise (define maximum coherence) and Fisher z-transform (atanh)
                coherence_interfered_rhomax_atanh(f,g) =  atanh(mpar.rho_max * coherence_interfered(g)); %
            end
              % binaural decision variable: numFrames coherence  
            mBP(f,:,1) = coherence_interfered .* exp(1i*angle(gamma));
            Power_ild(f,:,:) = squeeze( (mean(he(frame,:,:) ,1) .^2) / 2);
              % ILD feature (Eq. 5)
            mild = 20*log10(Power_ild(:,:,1) ./ Power_ild(:,:,2));
              % concatenate left and right envelopes for Power feature
            he_cat  = [squeeze(he(frame,:,1));  he(frame,:,2)];
        else
              % if mono: just take envelope of just that signal
            he_cat = he(frame,:);
        end
        % ==== MONAURAL PATHWAY ====
          % Power feature, Eq. 1
        Power(f,:) = squeeze( (mean(he_cat ,1) .^2) / 2);
          % hearing threshold
        hearing_threshold = absolutethreshold(sFB.center_frequencies_hz,'iso389_2019'); %was: local_iso389_7(sFB.center_frequencies_hz);
          % hearing threshold exceeded? --> Otherwise set to threshold (gamma: NaN, won't affect d')
        for n_filter = 1:length(sFB.center_frequencies_hz)
            if Power(f,n_filter,1) <= 1e-10 * 10^(hearing_threshold(n_filter)/10)
                Power(f,n_filter,1) = 1e-10 * 10^(hearing_threshold(n_filter)/10);
                Power_ild(f,n_filter,:) = 1e-10 * 10^(hearing_threshold(n_filter)/10);
                mBP(f,n_filter,:) = NaN;
            end
        end

    end

    if isequal(test_or_ref,1)
        ild_ref = mild;
        gamma_ref = mBP;
        Power_ref = Power;
    elseif isequal(test_or_ref,2)
        ild_test = mild;
        gamma_test = mBP;
        Power_test = Power;
    else
        error('Ka it sei.');
    end

end

%% Decision Stage: 
  % Discriminability of Gamma feature (Eq. 6)
D_gamma_frames_multich = abs(gamma_test - gamma_ref);

  % discriminability of ILD feature (Eq. 7)
D_ild_frames_multich = abs(ild_test - ild_ref);
  % Power (Eq. 2 and 3). In GPSMq, power increments are not weighted higher than decrements, so here neither.
SNR_incr = (Power_test - Power_ref)./Power_ref;
SNR_decr = (Power_ref - Power_test)./Power_test;
  % weighting, limiting
SNR_incr = min(max(SNR_incr,0),20);
SNR_decr = min(max(SNR_decr,0),20);
SNR_incr_decr = cat(3,SNR_incr, SNR_decr);
SNR = mean(SNR_incr_decr,3);

%% Routing to output
d_gamma = D_gamma_frames_multich;
d_ild = D_ild_frames_multich;
d_snr = SNR;

%% Create the output parameters
mpar.center_frequencies_hz = sFB.center_frequencies_hz;
feature.data_gamma = d_gamma;
feature.data_ild = d_ild;
feature.data_mon = d_snr;
feature.mpar = mpar;

