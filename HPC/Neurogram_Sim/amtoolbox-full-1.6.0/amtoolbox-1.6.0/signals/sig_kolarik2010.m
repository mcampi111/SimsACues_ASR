function stimulus = sig_kolarik2010(innerbw,f_phase,s_spl,s_sign,fs,dur,rise_time,bw,fc,n_sspl)
%sig_kolarik2010   Tone masked by a diotic inner-band and two antiphasic flanking-band noises
%   Usage: stimulus = sig_kolarik2010(innerbw,f_phase,s_spl,s_sign,fs,dur,rise_time,bw,fc,n_sspl)
%
%   Input parameters:
%
%     innerbw: Bandwidth (in Hz) of diotic noise band centered at target frequency.
%
%     f_phase: Code for the phase of the flankers:
%
%              - pi*: Create the N_{pi 0pi} condition, i.e., both lower 
%                and upper flankers shifted by pi.
% 
%              - 99*: Create the N_{u0u} condition, i.e., independent noise.
%
%              - pi/2*: Create the N_{{pi over 2} 0 0} condition, i.e., lower flanker 
%                shifted by pi/2 but the upper flanker not shifted.
%
%     s_spl: SPL (in dB) of the tone.
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
%   SIG_KOLARIK2010 creates a tone masked by a diotic inner-band 
%   and two antiphasic flanking-band noises. It generates the stimulus for 
%   the experiment from Kolarik & Culling (2010) and simulated in Fig. 5 of
%   Eurich et al. (2022).
%
%   If you experience the error "too many input parameters", remove the parameters
%   itd and noise_mode from your call of SIG_KOLARIK2010. These parameters
%   are not used here. 
%
%   See also: eurich2022 exp_eurich2022
%
%   References:
%     A. J. Kolarik and J. F. Culling. Measurement of the binaural auditory
%     filter using a detection task. The Journal of the Acoustical Society of
%     America, 127(5):3009--3017, 05 2010.
%     
%     B. Eurich, J. Encke, S. D. Ewert, and M. Dietz. Lower interaural
%     coherence in off-signal bands impairs binaural detection. The Journal
%     of the Acoustical Society of America, 151(6):3927--3936, 06 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_kolarik2010.php


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

% nlcut = 0; % lower freq limit of masker, unused
% nhcut = 2500; % upper, usused
bandshift = 0.5; % downshifted, centered, upshifted
innernotch_db = 0; 

%% tone
tone_mono = sig_tone(fc,dur, fs,0);
tone      = [tone_mono s_sign*tone_mono]; 
tone_spl  = scaletodbspl(tone,s_spl);
len = length(tone_mono);

%% noise
nlcut = fc - innerbw*bandshift; %floor(fc-bw/2); % noise
nhcut = fc + innerbw*(1-bandshift);
  % freq spacing
fftpts = fs; % length 1ms for now, truncated later
spacing = fs/fftpts; % 1 Hz spacing
  % nyquist freq bin, depending on even or odd number of samples
nyBin = floor(fftpts/2) + 1;
  % lowest and highest bins
lbin1 = 1; %
hbin1 = min( round(nlcut/spacing), nyBin );
  % higher flanking noise
lbin2 = max( round((nhcut)/spacing) +1, 2); % + 1 so that the edge bin isn't contained twice
hbin2 = min( round(bw/spacing), nyBin );

  % inner noise
lbin3 = max( round((nlcut)/spacing) + 1, 2);
hbin3 = min( round(nhcut/spacing), nyBin );

  % create Gaussian white noises
a1 = zeros(fftpts,1);
b1 = a1;
a2 = zeros(fftpts,1);
b2 = a2;
a3 = a2;
b3 = b2;
a4 = a2;
b4 = b2;

  % noises for each real and imag part: lower/upper flank, twice SDN
  % real parts
a1(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
a2(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
if hbin3 - lbin3 >0 % only if bins are different, noise is generated here --> scale bins if notch
    a3(lbin3:hbin3) = randn(hbin3-lbin3+1,1) * 10^(-innernotch_db/10);
end
  % noise in the spectral domain
a4(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
a5(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
  % imag parts
b1(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
b2(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
if hbin3 - lbin3 >0
    b3(lbin3:hbin3) = randn(hbin3-lbin3+1,1) * 10^(-innernotch_db/10);
end
  % noise in the spectral domain
b4(lbin1:hbin1) = randn(hbin1-lbin1+1,1);
b5(lbin2:hbin2) = randn(hbin2-lbin2+1,1);
  % define complex noise spectra
fspec1 = a1+ 1i*b1;
fspec2 = a2+ 1i*b2;
fspec3 = a3+ 1i*b3;
fspec4 = a4+ 1i*b4;
fspec5 = a5+ 1i*b5;

fspec1_shift = fspec1;
fspec2_shift = fspec2;
fspec3_shift = fspec3;
  % phase shifts flanking bands
if (hbin1-lbin1 >= 1) && (hbin2-lbin2 >= 1)
    if isequal(f_phase,pi) % pi0pi condition
        fspec1_shift(lbin1:hbin1) = fspec1(lbin1:hbin1) .* exp(1i*f_phase);
        fspec2_shift(lbin2:hbin2) = fspec2(lbin2:hbin2) .* exp(1i*f_phase);%        
    elseif isequal(f_phase,99) % u0u condition: independent noise
        fspec1_shift(lbin1:hbin1) = fspec4(lbin1:hbin1);
        fspec2_shift(lbin2:hbin2) = fspec5(lbin2:hbin2);
    elseif isequal(f_phase,pi/2) % pi00 condition        
        fspec1_shift(lbin1:hbin1) = fspec1(lbin1:hbin1) .* exp(1i*f_phase);
        fspec2_shift(lbin2:hbin2) = fspec2(lbin2:hbin2) .* exp(1i*0);%
    else
      error('f_phase must be pi, 99, or pi/2');
    end
end
  % phase shifts inner band: if flanking phase = pi, inner band phase = 0 and vice versa
inner_phase = 0; % for KolCul10 inner phase always 0
fspec3_shift(lbin3:hbin3) = fspec3(lbin3:hbin3) .* exp(1i*inner_phase);
fspec_l = fspec1 + fspec2 + fspec3;
fspec_r = fspec1_shift + fspec2_shift + fspec3_shift;
  % noise in time domain
noise_flanked_l = (2*real(fftpts*ifft(fspec_l)))/std(2*real(fftpts*ifft(fspec_l)));
noise_flanked_r =  (2*real(fftpts*ifft(fspec_r)))/std(2*real(fftpts*ifft(fspec_r)));
noise_flanked   = [noise_flanked_l noise_flanked_r];
  % scale 
noise_flanked_spl = scaletodbspl(noise_flanked,n_sspl + 10*log10(bw));

  % add tone to noise
stimulus = tone_spl + noise_flanked_spl(1:len,:);
  % apply fade if requested
if rise_time>0, stimulus = fade(stimulus, rise_time, fs); end


