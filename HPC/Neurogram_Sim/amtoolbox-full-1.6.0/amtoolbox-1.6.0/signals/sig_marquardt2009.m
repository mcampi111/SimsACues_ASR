function stimulus = sig_marquardt2009(innerbw,f_phase,n_type,s_spl,n_itd,s_sign,fs,dur,rise_time,bw,fc,n_sspl)
%sig_marquardt2009   Tone masked by delayed inner-band noise(s) with constant ITD and two antiphasic flanking-band noises
%   Usage: stimulus = sig_marquardt2009(innerbw,f_phase,n_type,s_spl,n_itd,s_sign,fs,dur,rise_time,bw,fc,n_sspl)
%
%   Input parameters:
%   
%     innerbw: Bandwidth (in Hz) of diotic noise band centered at target frequency.
%
%     f_phase: IPD (in radiants) of flanking-band noises, e.g., pi /2 or -pi/2. 
%
%     n_type: Type of the noise: 
%
%             - 1 for a single-delayed noise.
%
%             - 2 for two opposingly delayed noises (known as double-delayed noise).
%
%     s_spl: SPL (in dB) of the tone.
%
%     n_itd: ITD (in s) of the inner-band noise component(s).
%
%     s_sign: Polarity of the amplitude of the tone's right channel:
%
%             - Use s_sign of 1 to create an S_0 target. 
%
%             - Use s_sign of -1 to create an S_pi target. 
%
%     fs: Sampling rate (in Hz).
%
%     dur: Duration of stimulus (in s).
%
%     rise_time: Duration of the cosine ramp at start and end of signal (in s).
%                Use rise_time of 0 to disable the windowing.
%
%     bw: Overall bandwidth (in Hz) of stimulus.
%
%     fc: Center frequency (in Hz) of the target tone and the inner band.
%
%     n_sspl: Spectral SPL (in dB) of the noise.
%
%   SIG_MARQUARDT2009 creates a tone masked by either a single delayed narrow-band
%   noise or two opposingly delayed noises (known as double-delayed noise) 
%   with a constand ITD. That narrowband noise is additionally superimposed
%   to two antiphasic flanking-band noises. It is the stimulus 
%   from the experiment from Marquardt & McAlpine (2009) simulated 
%   in Fig. 4 of Eurich et al. (2022). 
%
%   See also: eurich2022 exp_eurich2022
%
%   References:
%     T. Marquardt and D. McAlpine. Masking with interaurally
%     “double-delayed” stimuli: The range of internal delays in the human
%     brain. The Journal of the Acoustical Society of America,
%     126(6):EL177--EL182, 11 2009.
%     
%     B. Eurich, J. Encke, S. D. Ewert, and M. Dietz. Lower interaural
%     coherence in off-signal bands impairs binaural detection. The Journal
%     of the Acoustical Society of America, 151(6):3927--3936, 06 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_marquardt2009.php


%   #Author: Bernhard Eurich (2022): original implementation
%   #Author: Piotr Majdak (2023): Documentation updates
%   #Author: Piotr Majdak (2024): Major rework for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% nlcut = 50; % lower freq limit of masker, unused here because calculated from fc and bw
% nhcut = 950; % upper, unused here because calculated from fc and bw

%%  tone
tone_mono = sig_tone(fc,dur, fs,0);
tone = [tone_mono s_sign*tone_mono]; 
tone_spl = scaletodbspl(tone,s_spl);
len = length(tone_mono);

% [window] = cosine_fade_window([1:dur*fs]', rise_time, fs);

%% Innerband noises
  % Parameters
nlcut = floor(fc-bw/2); % noise
nhcut = ceil(fc+bw/2);
bw_flank =  (nhcut - nlcut- innerbw)/2;
  % freq spacing
fftpts = fs; % length 1ms for now, truncated later
spacing = fs/fftpts; % 1 Hz spacing
  % nyquist freq bin, depending on even or odd number of samples
nyBin = floor(fftpts/2) + 1;
  % vector of freq per bin up to Nyquist freq
freqVec = [0:nyBin-1]' * spacing;
 % lowest and highest bins: lower flanking noise
lbin1 = max( round(nlcut/spacing) + 1, 2);
hbin1 = min( round((nlcut+bw_flank)/spacing) + 1, nyBin );

  % lowest and highest bins: higher flanking noise
correction = innerbw==0; % so that in case of no inner band we don't double the middle bin
lbin2 = max( round((nhcut-bw_flank)/spacing) + 1+correction, 2); % + 1 so that the edge bin isn't contained twice
hbin2 = min( round(nhcut/spacing) + 1, nyBin );
  % inner noise
lbin3 = max( round((nlcut+bw_flank)/spacing) + 1, 2);
hbin3 = min( round(nhcut-bw_flank/spacing) + 1, nyBin );
  % Gaussian white noises
a1 = zeros(fftpts,1);
b1 = a1;
a2 = zeros(fftpts,1);
b2 = a2;
a3 = a2;
b3 = b2;
a4 = a2;
b4 = b2;
  % noises for each real and imag part: lower/upper flank, twice SDN
a1(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
a2(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
a3(lbin3:hbin3) = randn(hbin3-lbin3+1,1);
a4(lbin3:hbin3) = randn(hbin3-lbin3+1,1);

b1(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
b2(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
b3(lbin3:hbin3) = randn(hbin3-lbin3+1,1);
b4(lbin3:hbin3) = randn(hbin3-lbin3+1,1);
  % complex noise spectra
fspec1 = a1+ 1i*b1;
fspec2 = a2+ 1i*b2;
fspec3 = a3+ 1i*b3;
fspec4 = a4+ 1i*b4;
  % phase shifts
fspec1_shift = fspec1;
fspec2_shift = fspec2;
fspec3_shift = fspec3;
fspec4_shift = fspec4;
if (hbin1-lbin1 >= 1) && (hbin2-lbin2 >= 1)
    fspec1_shift(lbin1:hbin1) = fspec1(lbin1:hbin1) .* exp(1i*f_phase);
    fspec2_shift(lbin2:hbin2) = fspec2(lbin2:hbin2) .* exp(1i*-f_phase);
end
  % itd: one SDN with same freq bins but positive and one with negative itd
if (hbin3-lbin3 >= 1)
    itd_shift = 2*pi*freqVec(lbin3:hbin3)*n_itd;
    fspec3_shift(lbin3:hbin3) = fspec3(lbin3:hbin3) .* exp(1i*itd_shift);
    fspec4_shift(lbin3:hbin3) = fspec4(lbin3:hbin3) .* exp(1i*-itd_shift);
end

% mSDnoise     = [SDN1_l(1:len) SDN1_r(1:len)];
% mDDnoise     = [DDN_l(1:len) DDN_r(1:len)];
  % noise switch
if n_type == 1
%     noise = mSDnoise;
  SDN1_l = (2*real(fftpts*ifft(fspec3))) / std(2*real( fftpts * ifft(fspec3) ));
  SDN1_r = (2*real(fftpts*ifft(fspec3_shift)))/std(2*real(fftpts*ifft(fspec3_shift)));
  noise = [SDN1_l(1:len) SDN1_r(1:len)];
elseif n_type == 2
%     noise = mDDnoise;
  spec_DDN_l = fspec3 + fspec4;
  spec_DDN_r = fspec3_shift + fspec4_shift;
  DDN_l = (2*real(fftpts*ifft(spec_DDN_l)))/std(2*real(fftpts*ifft(spec_DDN_l)));
  DDN_r = (2*real(fftpts*ifft(spec_DDN_r)))/std(2*real(fftpts*ifft(spec_DDN_r)));
  noise = [DDN_l(1:len) DDN_r(1:len)];
else
  error('n_type must be 1 or 2'); 
end
%% flanking noises
flank1_l = (2*real(fftpts*ifft(fspec1)))/std(2*real(fftpts*ifft(fspec1)));
flank1_r =  (2*real(fftpts*ifft(fspec1_shift)))/std(2*real(fftpts*ifft(fspec1_shift)));
flank2_l = (2*real(fftpts*ifft(fspec2)))/std(2*real(fftpts*ifft(fspec2)));
flank2_r = (2*real(fftpts*ifft(fspec2_shift)))/std(2*real(fftpts*ifft(fspec2_shift)));
flank_band_1 = [flank1_l(1:len) flank1_r(1:len)];
flank_band_2 = [flank2_l(1:len) flank2_r(1:len)];
%% Combine to a stimulus
  % level scaling
noise_spl = scaletodbspl(noise,n_sspl + 10*log10(innerbw));
flank_band_1_spl = scaletodbspl(flank_band_1,n_sspl + 10*log10(bw_flank));
flank_band_2_spl = scaletodbspl(flank_band_2,n_sspl + 10*log10(bw_flank));
  % mix noises
noise_flanked_spl = noise_spl + flank_band_1_spl + flank_band_2_spl;
  % add tone to noises
stimulus = tone_spl + noise_flanked_spl;
  % apply fade if requested
if rise_time>0, stimulus = fade(stimulus, rise_time, fs); end
% stimulus = [noise_spl_t.* window];



% function [DDnoise, SDnoise] = gen_DDNoise(len, flcut, fhcut, itd, fs)
% 
% % generate two independent noises
% 
% % bw =  (fhcut - flcut);
% 
% % ====  create shifted noises in f domain ====
% 
% % nyquist freq bin, depending on even or odd number of samples
% fftpts = fs; % fft points for 1s length;
% spacing = 1; % Hz per bin
% nyBin = floor(fs/2) + 1;
% 
% % vector of freq per bin up to Nyquist freq
% freqVec = [0:nyBin-1]' * spacing;
% 
% % lowest and highest bins
% % lower flanking noise
% lbin = max( round(flcut/spacing) + 1, 2);
% hbin = min( round(fhcut/spacing) + 1, nyBin );
% 
% a1 = zeros(fftpts,1);
% b1 = a1;
% a2 = zeros(fftpts,1);
% b2 = a2;
% 
% % two independent noises with each real and imag part
% a1(lbin:hbin) = randn(hbin-lbin+1,1);
% a2(lbin:hbin) = randn(hbin-lbin+1,1);
% b1(lbin:hbin) = randn(hbin-lbin+1,1);
% b2(lbin:hbin) = randn(hbin-lbin+1,1);
% 
% 
% % complex noise spectra
% fspec1 = a1+ i*b1;
% fspec2 = a2+ i*b2;
% 
% fspec1_shift = fspec1;
% fspec2_shift = fspec2;
% 
% 
% % introduce opposing ITDs
% itd_shift = 2*pi*freqVec(lbin:hbin)*itd;
% fspec1_shift(lbin:hbin) = fspec1(lbin:hbin) .* exp(1i*itd_shift);
% fspec2_shift(lbin:hbin) = fspec2(lbin:hbin) .* exp(1i*-itd_shift);
% 
% SDN1_l = (2*real(fftpts*ifft(fspec1))) / std(2*real( fftpts * ifft(fspec1) ));
% SDN1_r = (2*real(fftpts*ifft(fspec1_shift)))/std(2*real(fftpts*ifft(fspec1_shift)));
% 
% SDN2_l = (2*real(fftpts*ifft(fspec2))) / std(2*real( fftpts * ifft(fspec2) ));
% SDN2_r = (2*real(fftpts*ifft(fspec2_shift)))/std(2*real(fftpts*ifft(fspec2_shift)));
% 
% spec_DDN_l = fspec1 + fspec2;
% spec_DDN_r = fspec1_shift + fspec2_shift;
% 
% DDN_l = (2*real(fftpts*ifft(spec_DDN_l)))/std(2*real(fftpts*ifft(spec_DDN_l)));
% DDN_r = (2*real(fftpts*ifft(spec_DDN_r)))/std(2*real(fftpts*ifft(spec_DDN_r)));
%     
% SDnoise     = [SDN1_l(1:len) SDN1_r(1:len)];
% DDnoise     = [DDN_l(1:len) DDN_r(1:len)];


% function [signal_out] = set_dbspl(signal_in,dbspl_val)
% %set_dbspl set SPL for each signal channel
% % SIGNAL_OUT = set_dbspl(SIGNAL_IN, DBSPL_VAL)
% % SIGNAL_IN     preassure waveform, multi channels in colums
% % DBSPL_VAL     level in dB SPL (ref value is 20e-6 pa), per chanel 
% %
% % see also get_dbspl, add_dbgain, audio_signal_info
% 
% 
% p0 = 20e-6; %ref value
%     
% val = sqrt(mean(signal_in.^2));   
% 
% factor = (p0 * 10.^(dbspl_val / 20)) ./ val;
% 
% signal_out = signal_in .* factor;
% 
% end
% 
% function [window] = cosine_fade_window(signal, rise_time, fs)
% %cosine_fade_window returns a weighting vector for windowing (fade-in + fade-out) a signal
% %WINDOW = cosine_fade_window(SIGNAL, RISE_TIME, FS)
% % SIGNAL    preassure waveform, multi channels in colums
% % RISE_TIME time in seconds
% % FS        sampling frequency
% % WINDOW    vector with the length of SIGNAL
% %   
% %           ................
% %        .                    .
% %     .                          .
% %  .                                .
% % |rise_time|              |rise_time|
% % |          signal_time             | 
% %
% % EXAMPLE:
% %       fs = 48e3;
% %       sig = generate_tone(100,.5,fs);
% %       window = cosine_fade_window(sig,.1,fs);
% %       ramped_sig = sig .* window;
% 
% n_ramp = round(rise_time * fs);
% n_signal = size(signal,1);
% 
% window = ones(1, n_signal);
% flank = 0.5 * (1 + cos(pi / n_ramp * (-n_ramp:-1)));
% window(1:n_ramp) = flank;
% window(end-n_ramp+1:end) = fliplr(flank);
% window = window';
% 
% end
% 
% 
% function [sine,time] = gen_tone(frequency, duration, fs, start_phase)
% % gen_tone returns a cosine wave
% % [SINE, TIME ] = gen_tone(FREQUENCY, DURATION, FS, START_PHASE)
% % FREQUENCY     frequency in Hz
% % DURATION      duration in seconds
% % FS            sampling frequenc
% % START_PHASE   default is 0
% % SINE          sine wave
% % TIME          time vector for the cosine-wave
% %
% % see also getAMS gen_sam audio_signal_info
%     if nargin < 4
%         start_phase = 0;
%     end
% 
%     nsamp = round(duration * fs);
%     time = get_time(nsamp, fs);
% 
%     sine = cos(2 * pi * frequency * time + start_phase);
% 
% end
% 
% function [time] = get_time(signal, fs)
% %get_time returns time-vector for a given 
% % signal or number of samples
% %[TIME] = get_time(SIGNAL, FS)
% % SIGNAL    signal or number of samples
% % FS        sampling frequency
% % TIME      time vector (start with 0)
% %
% % see also nsamples
% 
% dt = 1. / fs;
% 
% if length(signal) > 1
%     nsamp = length(signal);
% else
%     nsamp = signal;
% end
%     
% max_time = nsamp * dt;
% 
% time = 0:dt:(max_time - dt);
%     
% time = time';
% end

