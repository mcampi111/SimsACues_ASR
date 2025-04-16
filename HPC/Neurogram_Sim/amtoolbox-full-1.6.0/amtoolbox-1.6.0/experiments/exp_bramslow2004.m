function s_out = exp_bramslow2004(varargin)
%exp_bramslow2004 Figures testing the loudness model considering hearing loss BRAMSLOW2004
%   Usage: s_out = exp_bramslow2004(flags);
%
%   EXP_BRAMSLOW2004(..); reproduces figures using the BRAMSLOW2004 model.
%   
%   EXP_BRAMSLOW2004(..,'debug'); displays debugging information while running
%   the model. 
%
%   out = EXP_BRAMSLOW2004(..); returns the output of the model. 
%
%   The following flags can be specified:
%
%     'fig2_bramslow2024'  Reproduce Fig. 2 from Bramslow (2024) about the 
%                          excitation for 500 Hz and 4 kHz tone:
%
%     'fig3_bramslow2024'  Reproduce Fig. 3 from Bramslow (2024) about the 
%                          masking pattern for 60-dB SPL/Hz noise and flat 
%                          hearing loss.
%
%     'fig4_bramslow2024'  Reproduce Fig. 4 from Bramslow (2024) about the 
%                          loudness growth for 1060 Hz tone and a monaural
%                          hearing loss.
%
%     'fig5_bramslow2024'  Reproduce Fig. 5 from Bramslow (2024) showing a
%                          speech sample processed by the model configured to
%                          normal hearing, hearing impaired, and hearing 
%                          impaired with applied gain.
%
%
%   Examples:
%   ---------
%
%   To display Fig.2 (left panel only) use :
%
%     exp_bramslow2004('fig2_bramslow2024');
%
%   To display Fig.3 (left panel only) use :
%
%     exp_bramslow2004('fig3_bramslow2024');
%
%   To display Fig.4 (left panel only) use :
%
%     exp_bramslow2004('fig4_bramslow2024');
%
%   To display Fig.5 use :
%
%     exp_bramslow2004('fig5_bramslow2024');
%
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
%
%   See also: bramslow2004
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_bramslow2004.php


%   #Author: Lars Bramslow (2024): original author
%   #Author: Pitor Majdak (2024): integration for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%   Note that the following *flags* can also be specified for internal debugging:
%
%     'test2'              Excitation for 1 kHz tone
%
%     'test3'              Excitation for white noise
%
%     'test4'              Excitation for white noise, uniform exciting noise and modified uniform exciting noise.
%
%     'test5'              Masking pattern for 40 dB SPL/Hz noise - sloping loss
%
%     'test6'              Masking pattern for 60 dB SPL/Hz noise - sloping loss
%
%     'test8'              Loudness growth for frequencies - Binaural
%
%     'test10'             Loudness growth for uniform exciting noise - Monaural, hearing loss
%


  % Parse input options
definput.flags.type = {'missingflag',...
    'fig2_bramslow2024','fig3_bramslow2024','fig4_bramslow2024', 'fig5_bramslow2024', ...
    'test2', 'test3', 'test4', 'test5', 'test6', 'test8', 'test10'};
definput.flags.plot = {'plot','no_plot'};
definput.flags.disp = {'no_debug','debug'};

[flags,~]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
    flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
        sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
    error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end

s_out = [];      % structure for output

%%  Fig 2 Simple NH excitation patterns
if flags.do_fig2_bramslow2024
   
    freqs = [500 4000];    
    figure();
      % level sweep
    levels  = 20:40:100;
    legstr  = cell(length(levels)*length(freqs),1);
    ileg    = 1;    
      % frequency sweep
    for ftone = freqs
        [x, fs] = sig_bramslow2004('sin', 9.8304, 9.8304, 0, ftone);      % 9.83s 1000Hz sine (24 frames), 0dB FS        
          % level sweep
        for level = levels            
            x = scaletodbspl(x, level);     % scale to level            
              % run model and get output
            [s_out] = bramslow2004(x, fs, 'Binaural', true, flags.disp);            
              % plot
            semilogx(s_out.fc, s_out.Roex_SPL);
            title (['AUDMOD: Binaural excitation patterns for ' num2str(freqs) ' Hz']);
            xlabel('Frequency [Hz]')
            ylabel('Excitation level [dB SPL]')
            grid on
            axis([100 10000 0 120])
              % SPL and total loudness in the legend
            legstr{ileg} = sprintf('%d dB SPL, %2.1f sones', level, s_out.Loudness);
            ileg = ileg + 1;
            hold on
        end % levels
        
    end % freqs
    legend(legstr,'Location','NorthWest')
    
end     % do_fig2_bramslow2024

%% Figure Excitation with hearing loss
if flags.do_fig3_bramslow2024
    
    [x,fs] = sig_bramslow2004('sin', 9.8304, 9.8304, 0, 1200);   % 9.83s 1200Hz sine (24 frames), 0dB FS    
    levels = [20 60 100];
    HLtypes = {'N0' 'N2' 'N3' 'N4'};    % according to bisgaard et al 2010    
      % audiogram frequencies (standard 11, AUDMOD uses 13)
    definput = arg_bramslow2004;
    HL_f = definput.keyvals.AG_f;       % audmod constants are stored here    
      % plot it
    legstr  = cell(1,1);
    ileg    = 1;    
    figure();    
      % level sweep
    for level = levels        
          % HL sweep
        for HLtype = HLtypes
            [AC, fout] = standardaudiogram(HLtype, HL_f);
            assert(all(fout == HL_f));            
            x = scaletodbspl(x, level);     % scale to level            
              % run model and get output
            [s_out] = bramslow2004(x, fs, 'AGLoss', AC);            
              % plot
            if ~isempty(s_out.Roex_SPL)
                semilogx(s_out.fc, s_out.Roex_SPL);
                title ('AUDMOD: Monaural excitation, 1200 Hz pure tone.');
                xlabel('Frequency [Hz]')
                ylabel('Excitation level [dB SPL]')
                grid on
                axis([100 10000 0 120])
                  % SPL and total loudness in the legend
                legstr{ileg} = sprintf('%d dB SPL, %s', level, HLtype{1});
                ileg = ileg+1;
                hold on
            end
        end % HLs
    end % levels    
    legend(legstr,'Location','NorthWest')
    
end     % do_fig3_bramslow2024

%% Fig 4 Loudness growth with hearing loss
if flags.do_fig4_bramslow2024
      % Note: model sweep: only AUDMOD can do the stepped sine level now (avg 1 frame per time)
    flatHTL = [0 20 40 60 80 100];
    ftone = 1060;
      % plot it
    figure();
    legstr  = cell(length(flatHTL),1);
    ileg    = 1;
    cols = char('blue','green','red','cyan','magenta','yellow');    
      % make stepped sine for quick loudness growth
    [x, fs] = sig_bramslow2004('sin', 2, 0.0128, 1, ftone);       % 2s sine, 1 dB step per frame, 256 samples per step    
      % HL sweep
    for HTL = flatHTL        
        AC = repmat(HTL, 1, 13);    % flat HL to 12.5 kHz (AUDMOD definition)
        x = scaletodbspl(x, 120);     % scale to level app 120 dB SPL - not critical here
          % run model and get output
        [s_out] = bramslow2004(x, fs, 'In_FrmSize', 256, 'Process', 1, 'Binaural', true, 'AGLoss', AC);
          % Find start and end points - but skip last frame
        p1 = find(s_out.Loudness(1:end-1) < 0.0001, 1, 'last' )+1;
        p2 = find(s_out.FFT_Power > 120, 1 );
          % plot
        semilogy(s_out.FFT_Power(p1:p2), s_out.Loudness(p1:p2), cols(ileg));
          % frequency in the legend
        legstr{ileg} = sprintf('%d dB HL', HTL);
        ileg = ileg + 1;
        hold on
        
    end % freqs
    title ('AUDMOD: Loudness growth (1060 Hz binaural)');
    xlabel('Level [dB SPL FF]')
    ylabel('Loudness [sones]')
    
    axis([0 125 1e-3 1e3])
    legend(legstr,'Location','NorthWest')
    hold off
    grid on
    
end     % do_fig4_bramslow2024

%% Fig 5 Speech sample with NH and HI
if flags.do_fig5_bramslow2024
      % DAST sentence 0005 F1: 'Det var enestående at initiativet førte til handling'.
    [x,fs_in] = amt_load('bramslow2004', 'dast_0005.wav');    
      % resample
    fs_out = 20000;
    G = gcd(fs_in,fs_out); % Compute the up and downsampling factors
    n_up = fs_out/G;
    n_down = fs_in/G;
    x = resample(x, n_up, n_down);
      % parameters
    HLs = {'N0' 'N3' 'N3'};  % according to bisgaard et al 2010
    levels = [70 70 70];       % corresponding levels 95 after NAL-RP
      % audiogram frequencies (standard 11, AUDMOD uses 13)
    definput = arg_bramslow2004;
    HL_f = definput.keyvals.AG_f;       % audmod constants are stored here
      % plot it
    figure();
      % HL sweep
    for ix = 1:3  
          % scale signal
        x = scaletodbspl(x, levels(ix));
          % plot it in separate subplots
        subplot(1,3,ix);        
          % get audiogram
        [AC, fout] = standardaudiogram(HLs{ix}, HL_f);
        assert(all(fout == HL_f));        
        if ix == 3
              % prescribe linear gain
            ig = nalrp(AC(2:10), fout(2:10), fout(2:10)); % skip 125 and above 6000
              % ig is a column vector, so transpose
            fircofs = local_design_IG_filter(ig', fout(2:10), fs_out, flags);
            x = filter(fircofs,1,x);
        end        
          % run model and get output
        [s_out] = bramslow2004(x, fs_out, 'In_FrmSize', 256, 'Process', 1, 'Binaural', false, 'AGLoss', AC);
          % plot surface
        surf(s_out.ERB_Loudness', 'EdgeColor', 'none');
        axis xy;
        axis tight;        
        colormap(jet); view(0,90);
        c = colorbar;
        c.Label.String = 'Specific loudness [sones/ERB]';
        c.Label.FontSize = 12;
        titstr = [HLs{ix}];
        switch ix
            case {1 2}
                titstr = [titstr '@ SPL =' num2str(levels(ix)) ,' dB'];
            case 3
                titstr = [titstr ' with NAL-RP gain'];
        end
        title (titstr);
        xlabel('Time [s]')
        ylabel('ERB Rate [Cams]')        
          % ytick labels
        ytls = compose('%g', s_out.EC(1:5:30)+3);
        yticklabels(ytls);
          % xtick labels
        t = 0:1:length(s_out.ERB_Loudness)-1;
        t = t*length(x)/(fs_out*length(t));
        tls = compose('%2.1f', t(50:50:300));
        xticks(50:50:300);
        xticklabels(tls);
          % vertical sones limit
        zlim([0 2]);
        caxis([0 2]);
    end % HL
end     % do_fig5_bramslow2024


%% %%%%% Here begin the internal test functions for debugging

%% Original testbench 2 for AUDMOD (not published)
if flags.do_test2
    amt_disp('Test 2: Binaural excitation patterns 1 kHz')
    
    [x, fs] = sig_bramslow2004('sin', 9.8304, 9.8304, 0, 1000);       % 9.8304s (24 frames) 1000Hz sine, 0dB FS
    
    % plot it
    figure();
    
    % level sweep
    levels  = 10:10:120;
    legstr  = cell(length(levels),1);
    ileg    = 1;
    
    for level = levels
        % set level
        xscaled = scaletodbspl(x, level);
        
        % run model and get output
        [s_out] = bramslow2004(xscaled, fs, 'Binaural', true);
        
        % plot
        semilogx(s_out.fc, s_out.Roex_SPL);
        title ('AUDMOD: Binaural excitation patterns for 1 kHz');
        xlabel('Frequency [Hz]')
        ylabel('Excitation level [dB SPL]')
        grid on
        axis([100 10000 0 120])
        % SPL and total loudness in the legend
        legstr{ileg} = sprintf('%d dB SPL, %2.1f sones', level, s_out.Loudness);
        ileg = ileg + 1;
        hold on
    end
    
    legend(legstr,'Location','NorthEastOutside')
end     % flags.do_test2

%% Original testbench 3 for AUDMOD (not published)
if flags.do_test3
    amt_disp('Test 3: Excitation patterns for white noise')
    
    [x, fs] = sig_bramslow2004('wn', 10, 10, 0, NaN);           % 10s white noise, 0dB FS
    
    % plot it
    figure();
    
    % level sweep
    levels  = 20:10:80;
    legstr  = cell(length(levels),1);
    ileg    = 1;
    
    for level = levels
        
        xs = scaletodbspl(x, level);
        
        % run model and get output
        s_out = bramslow2004(xs, fs, 'Binaural', true);
        
        % plot
        semilogx(s_out.fc, s_out.Roex_SPL);
        title ('AUDMOD: Binaural excitation patterns for white noise');
        xlabel('Frequency [Hz]')
        ylabel('Excitation level [dB SPL]')
        grid on
        axis([100 10000 0 80])
        % SPL and total loudness in the legend
        legstr{ileg} = sprintf('%d dB SPL, %2.1f sones', level, s_out.Loudness);
        ileg = ileg + 1;
        hold on
    end
    
    legend(legstr,'Location','NorthEastOutside')
    
end     % flags.do_test3

%% Original testbench 4 for AUDMOD (not published)
if flags.do_test4
    amt_disp('Test 4: Excitation patterns for 80 dB SPL white noise, UEN and modified UEN')
    
    % Generate signals
    sigs  = 1:3;
    ssigs  = {'wn' 'uen' 'uen2'};
    
    for isig = sigs
        [x{isig}, fs(isig)] = sig_bramslow2004(ssigs{isig}, 10, 10, 0, NaN);       % 0 dB FS
    end
    
    % plot it
    figure();
    
    % signal sweep
    legstr  = cell(length(sigs),1);
    ileg    = 1;
    
    for isig = sigs
        
        % scale
        x{isig} = scaletodbspl(x{isig}, 80);
        
        % run model and get output
        s_out = bramslow2004(x{isig}, fs(isig), 'Binaural', true);
        
        % plot
        semilogx(s_out.fc, s_out.Roex_SPL);
        title ('AUDMOD: Binaural excitation patterns for noises, 80 dB SPL');
        xlabel('Frequency [Hz]')
        ylabel('Excitation level [dB SPL]')
        grid on
        axis([100 10000 0 80])
        % SPL and total loudness in the legend
        legstr{ileg} = sprintf('%s, %2.1f sones', ssigs{isig}, s_out.Loudness);
        ileg = ileg + 1;
        hold on
    end
    
    legend(legstr,'Location','NorthEastOutside')
    
end     % flags.do_test4

%% Original testbench 5 for AUDMOD (not published)
if flags.do_test5
    % 'Pure tone monaural excitation patterns. 63 dB SPL = 200 Hz NB noise at 40 dB SPL/Hz. Average loss from subjects'
    amt_disp('Test 5: Frequency selectivity masking 40 dB SPL / Hz - Average sloping loss')
    % load 'test52' % old paramter file for reference
    % Coupler: 'IEC303'
    % TransFact: 'ZWICKA0'
    % Binaural: 0
    % In_FrmSize: 256
    
    [x, fs] = sig_bramslow2004('sin', 10, 10, 0, 1200);       % 10s 1000Hz sine, 0dB FS
    % scale to 63 dB SPL
    x = scaletodbspl(x, 63);
    
    AC = [0 0 0 8 7 20 36 40 52 60 70 70 70];   % extrapolated above 8k to 10k and 12.5k
    % original AC was: [0 0 0 8 7 20 36 40 52 60 70 0 0]
    
    % plot it
    figure();
    
    % run model and get output
    s_out = bramslow2004(x, fs, 'Binaural', false, 'In_FrmSize', 256, 'AGLoss', AC, 'IEC303');
    
    % plot
    semilogx(s_out.fc, s_out.Roex_SPL);
    title ('AUDMOD: Monaural average sloping loss, narrow-band 40 dB SPL/Hz.');
    xlabel('Frequency [Hz]')
    ylabel('Excitation level [dB SPL]')
    grid on
    axis([100 10000 0 120])
    % SPL and total loudness in the legend
    legstr = sprintf('63 dB SPL, %2.1f sones', s_out.Loudness);
    hold on
    
    legend(legstr,'Location','NorthEastOutside')
end     % flags.do_test5

%% Original testbench 6 for AUDMOD (not published)
if flags.do_test6
    % 'Pure tone monaural excitation patterns. 83 dB SPL = 200 Hz NB noise at 60 dB SPL/Hz. Average loss from subjects'
    amt_disp('Test 6: Frequency selectivity masking 60 dB SPL / Hz - Average sloping loss')
    % load 'test50' % old paramter file for reference
    % Coupler: 'IEC303'
    % TransFact: 'ZWICKA0'
    % Binaural: 0
    % In_FrmSize: 256
    
    [x, fs] = sig_bramslow2004('sin', 10, 10, 0, 1200);       % 10s 1000Hz sine, 0dB FS
    % scale to 83 dB SPL
    x = scaletodbspl(x, 83);
    
    AC = [0 0 0 8 7 20 36 40 52 60 70 70 70];   % extrapolated above 8k to 10k and 12.5k
    % original AC was: [0 0 0 8 7 20 36 40 52 60 70 0 0]
    
    % plot it
    figure();
    
    % run model and get output
    s_out = bramslow2004(x, fs, 'Binaural', false, 'In_FrmSize', 256, 'AGLoss', AC, 'IEC303');
    
    % plot
    semilogx(s_out.fc, s_out.Roex_SPL);
    title ('AUDMOD: Monaural average sloping loss, narrow-band 60 dB SPL/Hz.');
    xlabel('Frequency [Hz]')
    ylabel('Excitation level [dB SPL]')
    grid on
    axis([100 10000 0 120])
    % SPL and total loudness in the legend
    legstr = sprintf('83 dB SPL, %2.1f sones', s_out.Loudness);
    hold on
    
    legend(legstr,'Location','NorthEastOutside')
end     % flags.do_test6

%% Original testbench 8 for AUDMOD (not published)
if flags.do_test8
    
    amt_disp('Test 8: Loudness growth binaural vs frequency')
    freqs = [125 250 500 750 1000 1500 2000 3000 4000 6000];
    
    % model sweep: only AUDMOD can do the stepped sine level now
    %   (avg 1 frame per time)
    % plot it
    figure();
    legstr  = cell(length(freqs),1);
    ileg    = 1;
    cols = char('blue','green','red','cyan','magenta','yellow','blue','green','red','cyan');
    
    
    % frequency sweep
    for ftone = freqs
        [x, fs] = sig_bramslow2004('sin', 2, 0.0128, 1, ftone);       % 2s sine, 1 dB step per frame, 256 samples per step
        
        % level sweep
        x = scaletodbspl(x, 120);     % scale to level app 120 dB SPL - not critical here
        
        % run model and get output
        s_out = bramslow2004(x, fs, 'Binaural', true, 'Process', 1, 'In_FrmSize', 256);
        
        % Find start and end points - but skip last frame
        p1 = find(s_out.Loudness(1:end-1) < 0.001, 1, 'last' )+1;
        p2 = find(s_out.FFT_Power > 120, 1 );
        
        % plot
        semilogy(s_out.FFT_Power(p1:p2), s_out.Loudness(p1:p2), cols(ileg));
        % frequency in the legend
        legstr{ileg} = sprintf('%d Hz', ftone); % num2str(freqs) ' Hz'
        ileg = ileg + 1;
        hold on
        
    end % freqs
    title ('AUDMOD: Loudness growth binaural');
    xlabel('Level [dB SPL FF]')
    ylabel('Loudness [sones]')
    
    axis([0 125 1e-3 1e3])
    legend(legstr,'Location','NorthEastOutside')
    hold off
    grid on
    
end     % flags.do_test8

%% Test 10 Loudness growth UEN2 - Monaural
if flags.do_test10
    disp('Test 10: Loudness growth UEN2 - Monaural')
    
    flatHTL = [0 15 35 55 75];
    
    % model sweep: only AUDMOD can do the stepped level now
    %   (avg 1 frame per time)
    % plot it
    figure();
    legstr  = cell(length(flatHTL),1);
    ileg    = 1;
    cols = char('blue','green','red','cyan','magenta','yellow');
    
    [x, fs] = sig_bramslow2004('uen2', 4, 4*0.0128, 2,[]);       % 4s noise, 2 dB step per frame, 1024 samples per step
    
    % HL sweep
    for HTL = flatHTL
%         opt = s_him_in;                                         % empty
%         opt.fs          = fs;
%         opt.binaural    = false;
%         opt.frames_avg  = 4;
%         opt.framesize   = 256;
        AC = repmat(HTL, 1, 13);    % flat HL
        
        % level sweep
        x = scaletodbspl(x, 120);     % scale to level app 120 dB SPL - not critical here
        
        % run model and get output
        s_out = bramslow2004(x, fs, 'Binaural', false, 'Process', 4, 'In_FrmSize', 256, 'AGLoss', AC);
        
        % Find start and end points - but skip last frame
        p1 = find(s_out.Loudness(1:end-1) < 0.001, 1, 'last' )+1;
        p2 = find(s_out.FFT_Power > 120, 1 );
        
        % plot
        semilogy(s_out.FFT_Power(p1:p2), s_out.Loudness(p1:p2), cols(ileg));
        % frequency in the legend
        legstr{ileg} = sprintf('%d dB HL', HTL);
        ileg = ileg + 1;
        hold on
        
    end % freqs
    title ('AUDMOD: Loudness growth UEN2 - monaural');
    xlabel('Level [dB SPL FF]')
    ylabel('Loudness [sones]')
    
    axis([0 125 1e-3 1e3])
    legend(legstr,'Location','NorthWest')
    hold off
    grid on
end %flags.do_test10

%% LOCAL FUNCTION
function b = local_design_IG_filter(ig, aud_fc, fs, flags)
% function b = local_design_IG_filter(ig, aud_fc, l_transd, f_transd, fs)
%   ig: insertion gain in dB
%   aud_fc: corresponding frequencies (typically audiogram frequencies)

%   fs: samplerate in Hz
%
%   The ig and transducer responses are interpolated to 1/3 octave, summed
%   and then created as filter

amt_disp(['local_design_IG_filter: ig specs: ' num2str(ig) ' dB'],flags.disp);

f1third = [100 125 160 200 250 315 400 500 630 800 ...
    1000 1250 1600 2000 2500 3150 4000 5000 6300];  % 8000 removed for fs = 16 kHz
ntaps = 1024;

% gain in third octaves
% gain_dB = loginterp(aud_fc,ig,f1third); replaced by interp1:
% extend below 100 Hz, same gain
aud_fc = [62 125 aud_fc];
ig = [ig(1) ig(1) ig];
gain_dB = interp1(log(aud_fc), ig, log(f1third), 'linear','extrap');

fc = [0 f1third fs/2];                      % add 0 and fs/2
fc = fc./(fs/2);                            % Normalize

amt_disp(['local_design_IG_filter: filter specs: ' num2str(gain_dB) ' dB'],flags.disp);

gain_dB = [gain_dB(1) gain_dB gain_dB(end)];        % add 0 and fs/2
gain = 10.^((gain_dB)/20);                          % dB to power


% Design and filter
b = fir2(ntaps,fc,gain);

% plot it - both spec and actual
if false
    figure();
    [h,f] = freqz(b,1,512,fs);
    semilogx(f, 20*log10(abs(h)), 'k', 'DisplayName', 'Actual');
    hold on
    plot(aud_fc, ig, 'ro', 'DisplayName', 'IG');
    plot(fc*fs/2, gain_dB, 'b.');
    legend('Actual', 'IG', 'Headph', 'Total', 'Location','NorthWest');
    title('FIR design')
end

