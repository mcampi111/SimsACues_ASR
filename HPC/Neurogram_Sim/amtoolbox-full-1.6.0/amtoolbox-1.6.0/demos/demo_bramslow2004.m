%demo_bramslow2004 Demonstration of the loudness model considering hearing loss BRAMSLOW2004
%
%   This demos generates a simple figure that shows the
%   excitation pattern calculated by the model AUDMOD. 
%
%   Figure 1: Excitation patterns
%
%
%   References:
%     L. Bramsløw. An objective estimate of the perceived quality of
%     reproduced sound in normal and impaired hearing. Acta Acustica united
%     with Acustica, 90(6):1007--1018, 2004.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_bramslow2004.php


%   #Author: Lars Bramslow (2024): original author

% 40 dB SPL tone 1000 Hz should give a binaural loduness of 1.0 sone
amt_disp('demo_bramslow2004: Creating tone 40 dB SPL tone 1000 Hz = 1 sone binaural');
fs = 20000;
ftone = 1000;
time_total = 1;                         % 1 s
level = 40;
t = 0:(1/fs):time_total-1/fs;           % time vector
sigin = sin(2*pi*ftone*t); 
sigin = scaletodbspl(sigin, level);     % test 40 dB SPL

%run the model
aud_out = bramslow2004(sigin, fs, 'In_FrmSize', 512, 'Binaural', 1);

% plot the results
figure;
semilogx(aud_out.fc, aud_out.Roex_SPL);
title ('AUDMOD: Binaural excitation pattern for 1000 Hz');
xlabel('Frequency [Hz]')
ylabel('Excitation level [dB SPL]')
grid on
axis([100 10000 0 60])
% SPL and total loudness in the legend
info = sprintf('%d dB SPL, %2.2f sones', level, aud_out.Loudness);
legend(info);
amt_disp(['demo_bramslow2004: ' info]);
amt_disp('');
amt_disp(aud_out);

