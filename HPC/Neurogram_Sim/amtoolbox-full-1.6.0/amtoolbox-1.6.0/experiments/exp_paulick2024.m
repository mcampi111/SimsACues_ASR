function exp_paulick2024(varargin)
%exp_paulick2024 Reproduce figures from Paulick et al. (2024)
%
%   Usage: exp_paulick2024(flags);
%
%   This script reproduces Figure 2 of Paulick et al. (2024). It compares the
%   internal representations calculated by two versions of the CASP model: 
%   'jepsen2008' and 'paulick2024', both in response to 
%   tones at the output of the IHC model in the on-frequency channels (Fig. 2A), 
%   and the response to a modulated tone at the output of the adaptation stage 
%   in frequency channels below, on and above the tone frequency (Fig. 2B). 
%
%   The following flags can be specified:
%
%     'fig2a'   Reproduce Fig. 2A: Internal representations at the output 
%               of the IHC stage in response to tones at various frequencies 
%               at the the on-frequency channel. The left column shows simulations 
%               from 'jepsen2008' with the linear IHC model (CASP). The right 
%               column shows outcomes from the revised CASP model 'paulick2024' 
%               that includes the non-linear IHC model. 
%
%     'fig2b'   Reproduce Fig. 2B: Internal representations at the output of the 
%               adaptation stage, generated in response to a 40-Hz modulated
%               2-kHz tone, for both CASP models. Top: 'jepsen2008' with the 
%               linear IHC stage. Bottom: 'paulick2024' with the non-linear IHC 
%               stage. The internal representations are depicted at peripheral 
%               channels below CF (0.7 kHz, left column), at CF (1 kHz, middle), 
%               and above CF (2 kHz, right column).
%
%   Examples:
%   ---------
%
%   To display Figure 2a use :
%
%     exp_paulick2024('fig2a');
%
%   To display Figure 2b use :
%
%     exp_paulick2024('fig2b');
%
%
%   See also: paulick2024 demo_paulick2024
%
%   References:
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_paulick2024.php


%   #Author: Lily Paulick (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptation for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

definput.import = {'amt_cache'};
definput.flags.type = {'missingflag', 'fig2', 'fig2a','fig2b'};

[flags,kv]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},...
             definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.', ...
      upper(mfilename),flagnames);
end

%% Figure 2A

if flags.do_fig2a || flags.do_fig2

    % Tone parameters
  fs = 44100; % Sampling rate (in Hz)
  dur_tone = 200e-3; % Signal duration (in s)
  dur_ramp = 20e-3; % ramp duration (in s)
  level = 70; % tone SPL (in dB) 
  f_probes = [300 600 2e3 4e3 5e3 ]; % Tone frequencies (in Hz)
    % Model parameters
  sbj = 'NH';
    % create variables and labels
  N = round(dur_tone*fs); % Samples
  t = (0:N-1)/fs;  % time axis
  nprobs = length(f_probes);
  for ff = 1:nprobs
    str_freq{ff} = sprintf('f = %.0f Hz',f_probes(ff));
  end
    % Run preprocessing
  for n =1:nprobs 
    f_probe = f_probes(n); % current frequency
      % create a probe
    x = sig_tone(f_probe,dur_tone,fs); 
    x = scaletodbspl(x, level); 
    x = fade(x,dur_ramp,fs); % add ramp
      % form internal representations     
    flags4model = {'model', 'jepsen2008', 'subject',sbj};
    [~, Y08] = paulick2024(x.', fs, flags4model{:});

    flags4model = {'model','paulick2024', 'subject',sbj};
    [~, Y24, fc_aud] = paulick2024(x.', fs, flags4model{:});

      % choose only on-frequency channels
    [~, idx] = min(abs(fc_aud-f_probe));
    IHCsig08(n,:) = Y08.IHC(:,idx);
    IHCsig24(n,:) = Y24.IHC(:,idx);

  end % end loop over frequencies

  % -------- PLOT ------- %
  col = [0.3 0.3 0.3]; linesize = 0.5; axisize = 10;       % Set size of axis numbers.
  yl = [12 7 0.15 0.07 0.07]; 
  ylims = [80 80 30 20 20]; 
  ylims2 = [-15 -12 -2.5 -2.5 -2.5]; 

  figure;
  sgtitle('A. On-frequency response to tones');
  for n = 1:5
    subplot(5,2,2*n-1);
    plot(t/1e-3, squeeze(IHCsig08(n,:)),'linewidth', linesize,'color',col);
    hold on
    str2= sprintf('f = %.0f Hz',f_probes(n));
    legend(str2,'box','off','location','northwest');
    grid off, box off
    ylim([0 yl(n)]);
    if n == 5, xlabel('Time (in ms)'); end
    if n == 3, ylabel('Amplitude (in model units, MU)'); end
    xlim([0 200]);
    set(gca, 'FontSize',axisize, 'linewidth', linesize);

    subplot(5,2,2*n);
    plot(t/1e-3, squeeze(IHCsig24(n,:))/1e-3,'linewidth', linesize,'color',col);
    hold on
    str2= sprintf('f = %.0f Hz',f_probes(n));
    legend(str2,'box','off','location','northwest');
    grid off, box off
    ylim([ylims2(n) ylims(n)]);
    if n == 5, xlabel('Time (in ms)'); end
    if n == 3, ylabel('IHC receptor potential (V, in mV)'); end
    xlim([0 200])
    set(gca, 'FontSize',axisize, 'linewidth', linesize);
  end

end

%% Fig 2b

if flags.do_fig2b || flags.do_fig2
      % Signal parameters
    fs = 44100;
    fc = 1000;
    dur_tone = 0.4; % tone duration (in s)
    dur_ramp = 0.01; % ramp duration (in s)
    level = 85; % SPL (in dB) %20e-6*10^((85)/20); %dB SPL
    mod_freq = 40; 
    mod_dep = -5; % modulation depth (in dB)
      % Create a modulated tone
    modsine = sig_tone(mod_freq,dur_tone,fs);
    sine = sig_tone(fc,dur_tone,fs);
    x =  sine.* (1 + (10^(mod_dep/20) * modsine));
    x = scaletodbspl(x, level); 
    x = fade(x, dur_ramp, fs); % fade in/out
      % Calculate variables
    N = round(dur_tone*fs);
    x = [x; zeros(round(0.5*fs) - N,1)]; % expand to 0.5-s duration
    t = (0:length(x)-1)/fs; % time_axis
    
      % Model parameters
    sbj = 'NH';
    
      % form internal representations
    flags4model = {'model','jepsen2008', 'subject',sbj};
    [~, Y08] = paulick2024(x, fs, flags4model{:});

    flags4model = {'model','paulick2024', 'subject',sbj};
    [~, Y24, fc_aud] = paulick2024(x, fs, flags4model{:});

    [~,fc_on] = min(abs(fc_aud - fc));
    [~,fc_bel] = min(abs(fc_aud - 700));
    [~,fc_abo] = min(abs(fc_aud - 2000));

      % -------- PLOT ------- %
    col = [0.3 0.3 0.3]; linesize = 0.5; axisize = 10;       % Set size of axis numbers.
    x_up = 0.45;
    ylow = -350; yup = 1500; 

    figure;
    sgtitle('B. Response to modulated 1kHz tone signal');
    subplot(231), plot(t,Y08.adaptation(:,fc_bel),'color',col, 'linewidth', linesize);
     legend('f_{bel} = 0.7 kHz','box','off','location','northeast');
     set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
     ylabel('Amplitude (in model units, MU)'); 
     ylim([ylow yup]);
     xlim([0 x_up]);
    subplot(232), plot(t,Y08.adaptation(:,fc_on),'color',col, 'linewidth', linesize);
     legend('f_{on} = 1 kHz','box','off','location','northeast');
     set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
     xlabel('Time (in s)'); 
     ylim([ylow yup]);
     xlim([0 x_up]);
    subplot(233), plot(t,Y08.adaptation(:,fc_abo),'color',col, 'linewidth', linesize);
     legend('f_{abo} = 2 kHz','box','off','location','northeast');
     set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
     ylim([ylow yup]);
     xlim([0 x_up]);
    
    subplot(234), plot(t,Y24.adaptation(:,fc_bel),'color',col, 'linewidth', linesize);
     legend('f_{bel} = 0.7 kHz','box','off','location','northeast');
     set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
     ylabel('Amplitude (in model units, MU)'); 
     ylim([ylow yup]);
     xlim([0 x_up]);
    subplot(235), plot(t,Y24.adaptation(:,fc_on),'color',col, 'linewidth', linesize);
     legend('f_{on} = 1 kHz','box','off','location','northeast');
     set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
     xlabel('Time (in s)'); 
     ylim([ylow yup]);
     xlim([0 x_up]);
    subplot(236), plot(t,Y24.adaptation(:,fc_abo),'color',col, 'linewidth', linesize);
      legend('f_{abo} = 2 kHz','box','off','location','northeast');
      set(gca, 'FontSize',axisize, 'linewidth', 1,'box','off');
      xlim([0 x_up]);
      ylim([ylow yup]);

end
    


