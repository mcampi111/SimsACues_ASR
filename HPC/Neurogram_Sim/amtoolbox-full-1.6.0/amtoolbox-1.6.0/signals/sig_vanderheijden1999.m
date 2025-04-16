function stimulus = sig_vanderheijden1999(n_itd,s_sign,n_type,s_spl,fs,dur,rise_time,bw,fc,n_sspl)
%sig_vanderheijden1999   Tone masked by delayed noise(s) with varying ITD
%   Usage: stimulus = sig_vanderheijden1999(n_itd,s_sign,n_type,s_spl,fs,dur,rise_time,bw,fc,n_sspl)
%
%   Input parameters:
%
%     n_itd: ITD (in s) of the masking noise component(s).
%
%     s_sign: Polarity of the amplitude of the tone's right channel:
%
%             - Use s_sign of 1 to create an S_0 target. 
%
%             - Use s_sign of -1 to create an S_pi target. 
%
%     n_type: Type of the noise: 
%
%             - 1 for a single-delayed noise.
%
%             - 2 for two opposingly delayed noises (known as double-delayed noise).
%
%     s_spl: SPL (in dB) of the tone.
%
%     fs: Sampling rate (in Hz).
%
%     dur: Duration of stimulus (in s).
%
%     rise_time: Duration of the cosine ramp at start and end of signal (in s).
%                Use rise_time of 0 to disable the windowing.
%
%     bw: Overall bandwidth of stimulus (in Hz).
%
%     fc: center frequency of inner band noise and the target tone (in Hz)
%
%     n_sspl: Spectral SPL (in dB) of the noise.
%
%   SIG_VANDERHEIJDEN1999 creates a tone masked by either a single delayed noise or 
%   two opposingly delayed noises (known as double-delayed noise) with varying ITD. 
%   It is used for the experiment from van der Heijden and Trahiotis (1999)
%   and for simulations of the Figure 3 from Eurich et al., (2022) done by EURICH2022.
%
%   See also: eurich2022 exp_eurich2022
%
%   References:
%     M. van der Heijden and C. Trahiotis. Masking with interaurally delayed
%     stimuli: The use of “internal” delays in binaural detection. The
%     Journal of the Acoustical Society of America, 105(1):388--399, 01 1999.
%     
%     B. Eurich, J. Encke, S. D. Ewert, and M. Dietz. Lower interaural
%     coherence in off-signal bands impairs binaural detection. The Journal
%     of the Acoustical Society of America, 151(6):3927--3936, 06 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_vanderheijden1999.php


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

n_lowcut = 50; % lower freq limit of masker (in Hz)
n_highcut = 950; % upper freq limit of masker (in Hz)

  % generate the tone
tone_mono = sig_tone(fc,dur,fs,0); 
tone      = [tone_mono s_sign*tone_mono];
tone_spl = scaletodbspl(tone,s_spl);
  % generate the noise
if n_type == 1
    noise = local_sig_delayednoise(dur*fs, n_lowcut, n_highcut, n_itd, fs);
elseif n_type == 2
    [~, noise] = local_sig_delayednoise(dur*fs, n_lowcut, n_highcut, n_itd, fs);
else
  error('n_type must be 1 or 2'); 
end
  % scale noise to n_sspl
noise_spl = scaletodbspl(noise,n_sspl + 10*log10(bw));
  % add tone to noise
stimulus = tone_spl + noise_spl;
  % apply fade if requested
if rise_time>0, stimulus = fade(stimulus, rise_time, fs); end


function [SDnoise, DDnoise] = local_sig_delayednoise(len, flcut, fhcut, itd, fs)
% generate one or two independent noises

  % nyquist freq bin, depending on even or odd number of samples
fftpts = fs; % fft points for 1s length;
spacing = 1; % Hz per bin
nyBin = floor(fs/2) + 1;
  % vector of freq per bin up to Nyquist freq
freqVec = (0:nyBin-1)' * spacing;
  % lowest and highest bins
lbin = max( round(flcut/spacing) + 1, 2);
hbin = min( round(fhcut/spacing) + 1, nyBin );
  % ITD as phase shift in frequency
itd_shift = 2*pi*freqVec(lbin:hbin)*itd;

%% Single delayed noise
  % noise with real and imag part
a1 = zeros(fftpts,1);
b1 = a1;
a1(lbin:hbin) = randn(hbin-lbin+1,1);
b1(lbin:hbin) = randn(hbin-lbin+1,1);
  % complex noise spectrum
fspec1 = a1+ 1i*b1;
fspec1_shift = fspec1;
fspec1_shift(lbin:hbin) = fspec1(lbin:hbin) .* exp(1i*itd_shift);
  % left channel: unshifted
SDN1_l = (2*real(fftpts*ifft(fspec1))) / std(2*real( fftpts * ifft(fspec1) ));
  % right channel: shifted
SDN1_r = (2*real(fftpts*ifft(fspec1_shift)))/std(2*real(fftpts*ifft(fspec1_shift)));
  % Single delayed noise
SDnoise = [SDN1_l(1:len) SDN1_r(1:len)];

%% Double delayed noise
if nargout==2
    % second independent noise with each real and imag part
  a2 = zeros(fftpts,1);
  b2 = a2;
  a2(lbin:hbin) = randn(hbin-lbin+1,1);
  b2(lbin:hbin) = randn(hbin-lbin+1,1);
  fspec2 = a2+ 1i*b2;
    % complex noise spectra
  fspec2_shift = fspec2;
    % ITD shift in the opposite direction
  fspec2_shift(lbin:hbin) = fspec2(lbin:hbin) .* exp(1i*-itd_shift);  
    % left channel: first noise left and second noise left, both unshifted
  spec_DDN_l = fspec1 + fspec2;
  DDN_l = (2*real(fftpts*ifft(spec_DDN_l)))/std(2*real(fftpts*ifft(spec_DDN_l)));
    % right channel: first noise right shifted and second noise left shifted in the opposite direction
  spec_DDN_r = fspec1_shift + fspec2_shift;
  DDN_r = (2*real(fftpts*ifft(spec_DDN_r)))/std(2*real(fftpts*ifft(spec_DDN_r)));    
    % double delayed noise
  DDnoise = [DDN_l(1:len) DDN_r(1:len)];
end


