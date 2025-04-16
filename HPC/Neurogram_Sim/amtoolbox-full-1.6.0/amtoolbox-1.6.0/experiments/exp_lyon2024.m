function exp_lyon2024(varargin)
%exp_lyon2024 Reproduction of results from Lyon et al. (2024)
%
%   EXP_LYON2024(flags) reproduces Figures from Lyon et al. (2024).
%
%   The following flags can be specified:
%
%     'fig1'    Reproduce Fig. 1.
%
%     'fig3'    Reproduce Fig. 3. 
%
%     'fig4'    Reproduce Fig. 4.
%
%   Examples:
%   ---------
%
%   To display Fig. 1 use :
%
%     exp_lyon2024('fig1');
%
%   To display Fig. 3 use :
%
%     exp_lyon2024('fig3');
%
%   To display Fig. 4 use :
%
%     exp_lyon2024('fig4');
%
%   License
%   -------
%
%   This model is licensed under the Apache License Version 2.0. Further usage details 
%   are provided in the in the AMT directory "licences".
%
%   See also: lyon2024
%
%   References:
%     R. F. Lyon, R. Schonberger, M. Slaney, M. Velimirović, and H. Yu. The
%     carfac v2 cochlear model in matlab, numpy, and jax. arXiv preprint
%     arXiv:2404.17490, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_lyon2024.php


%   #License: Apache2
%   #Author: Richard F. Lyon (2024): original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

%   This file is licensed unter the Apache License Version 2.0 which details can 
%   be found in the AMT directory "licences" and at 
%   <http://www.apache.org/licenses/LICENSE-2.0>. 
%   You must not use this file except in compliance with the Apache License 
%   Version 2.0. Unless required by applicable law or agreed to in writing, this 
%   file is distributed on an "as is" basis, without warranties or conditions 
%   of any kind, either express or implied.
  
definput.flags.type={'missingflag', 'fig1', 'fig3', 'fig4'}; 
flags  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end

%% Figure 1: (from CARFAC_two_cap_IHC_compression_fig.m ???)
if flags.do_fig1
    
    fs = 22050; 
    dB_SPL_list = 20:20:80;
      % create a harmonic complexs
    flist = 1400 + (1:4)*200;  % for QDT
    sine_signal = sig_tone(flist(1),0.5,fs);
    for fno = 2:length(flist)
        sine_signal = sine_signal + sig_tone(flist(fno),0.5,fs);
    end
      % create an SPL scaled repetition of the harmonic complex
    test_signal = [];
    for dB =  dB_SPL_list
        test_signal = [test_signal; scaletodbspl(sine_signal,dB)];
    end
      % call the model
    CF_struct = lyon2024_design(1, fs);  % mostly-default design, 1 ear
    CF_struct = lyon2024_init(CF_struct); 
    [~, ~, nap, BM] = lyon2024(test_signal, CF_struct);
      % define analysis ranges
    snip_dB = 60;
    snip_end = length(sine_signal) * find(snip_dB == dB_SPL_list);
    if isempty(snip_end), snip_end = size(nap, 1); end
    BM_snippet = BM(snip_end+(-440:0), :);
    fft_snippet = abs(fft(BM_snippet));  % look at fft of some channels only
      % plot
    figure;
    set(gca, 'Position', [.25, .25, .5, .5]);
    imagesc((fft_snippet(1:220, :)' + 0.002).^ 0.333); 
    colormap(1 - gray);
    axis([0, 89, 0, 71]);
    colormap(1-gray);
    set(gca, 'XTick', 1:20:81, 'XTickLabel',0:1:4);
    xlabel('Frequency (in kHz)');
    ylabel('Channel Number');
    title('Basilar membrane outputs for 4-tone harmonic complex');

end

%% Figure 3
if flags.do_fig3
  
    fs = 22050;
    dB_SPL = 60;
    f = 3000;
    ch = 23;  % Roughly 3 kHz place.
      % create the test signal and time vectors
    test_signal = scaletodbspl(sig_tone(f, 0.01, fs),dB_SPL);
    test_signal(end+1:end+round(0.005*fs)) = 0;  % add a 5-ms silence
    samps = 1:length(test_signal);
    times_ms = (0:(length(test_signal)-1))/fs*1000;

    figure;
      % one-cap model (for reference)
    CF_struct = lyon2011_design(1, fs);  % mostly-default design, 1 ear
    CF_struct = lyon2011_init(CF_struct);
    [~, ~, nap] = lyon2011(test_signal, CF_struct);  
    plot(times_ms, nap(:,ch), 'k:', 'linewidth', 1);
    hold on
      % two-cap model    
    CF_struct = lyon2024_design(1, fs);  % mostly-default design, 1 ear
    CF_struct = lyon2024_init(CF_struct);
    [CF_struct, ~, nap, BM] = lyon2024(test_signal, CF_struct); 
    plot(times_ms, nap(:,ch), 'k-', 'linewidth', 0.6);
        
      % two-cap model: plot more stuff
    bm_row = BM(:, ch);
      % Run an IHC open-loop on the BM response for the frequency channel
    coeffs = CF_struct.ears(1).IHC_coeffs;
    n_ch = coeffs.n_ch;
    state.ihc_accum = zeros(n_ch, 1); 
    state.cap1_voltage = coeffs.rest_cap1 * ones(n_ch, 1); 
    state.cap2_voltage = coeffs.rest_cap2 * ones(n_ch, 1);
    state.lpf1_state = coeffs.rest_output * ones(n_ch, 1);       
    receptor_potential_row = zeros(length(samps),1);
    for s = samps
      [~, state] = lyon2024_ihcstep(bm_row(s), coeffs, state);
      receptor_potential_row(s) = 1 - state.cap1_voltage(ch);
    end
      % plot
    plot(times_ms, 6 + 20*receptor_potential_row, 'k-');
    plot(times_ms, 12 + bm_row, 'k-');
    title('BM (top), receptor potential (middle), and NAP (bottom)');
    xlabel('Time (in ms)');
    ylabel('Amplitudes (arbitrary units, shifted by 6)');
    set(gca, 'Position', [.25, .25, .55, .55]);
    ylim([-2 16]);
    yticks(-2:2:16);
    text(12, 13, '12+BM');
    text(12, 8, '6+20 V_{recep}');
    text(12, 1, 'NAP');

end

if flags.do_fig4

    tau1 = 200e-6;
    tau2 = 80e-6;

    f = 30 * 10.^(0.25:(1/32):2.8)';
    s = 2*1i*pi*f;
    h1 = abs(1./(tau1*s + 1));
    h2 = abs(1./(tau2*s + 1));
    h_one_cap = h2.*h2;
    h_two_cap = h1.*h2;

    lw = 0.6;  % linewidth
    figure;
    semilogx(f, [h_one_cap, h_two_cap], 'k-', 'linewidth', lw);
    hold on
    semilogx(f, h_two_cap ./ h_one_cap, 'k--', 'linewidth', lw);

    i300 = find(f == 300);
    i3k = find(f == 3000);

    plot(f(i300)*[1;1], [h_one_cap(i300); h_two_cap(i300)], 'k-', 'linewidth', lw);
    plot(f(i3k)*[1;1], [h_one_cap(i3k); h_two_cap(i3k)], 'k-', 'linewidth', lw);
    set(gca, 'Position', [.25, .25, .5, .5]);
    xlabel('Frequency (in Hz)');
    ylabel('Smoothing filters gain = synchrony reduction');

    text(4000, 0.47, 'v2/v1 ratio');
    text(1500, 0.7, 'v1, one\_cap');
    text(210, 0.7, 'v2, two\_cap');
    text(2000, 0.1, '3 kHz');
    text(200, 0.86, '300 Hz');

end

