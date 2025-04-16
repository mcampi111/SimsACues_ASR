%demo_hohmann2002 Demonstration of the invertible Gammatone filterbank HOHMANN2002
%
%   This demonstration shows how to use the invertible Gammatone filterbank 
%   from Hohmann (2002).
%
%   The code consists of three parts: 
%
%   - Part I shows how to create a filter using hohmann2002_filter and 
%     process a sound using hohmann2002_process. 
%
%   - Part II shows how to create a filterbank using hohmann2002 and 
%     analyze the frequency responses using hohmann2002_freqz. 
%
%   - Part III shows how to use the invertible filterbank by applying
%     hohmann2002_synth.
%
%   Figure 1: Part I: Impulse response of a 4-th-order Gammatone filter with a center frequency of 1000 Hz and a 3-dB-bandwidth of 100 Hz.
%
%   Figure 2: Part I: Frequency response of the above filter.
%
%   Figure 3: Part II: Frequency responses of the individual filters of a Gammatone filterbank.
%
%   Figure 4: Part III: Impulse response of the full inverted system, i.e., analysis filterbank followed by the synthesis filterbank.
%
%   Figure 5: Part III: Frequency response of the above system.
%
%   See also: exp_hohmann2002 hohmann2002 hohmann2002_process
%
%   References:
%     V. Hohmann. Frequency analysis and synthesis using a gammatone
%     filterbank. Acta Acustica united with Acoustica, 88(3):433--442, 2002.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_hohmann2002.php


%   #Author: tp (2002): original implementation.
%   #Author: tp (2006): original implementation.
%   #Author: Piotr Majdak (2014): integration for AMT 0.9.7.
%   #Author: Robert Baumgartner (2016): major rework and integration of plots (Example_Filter.m and Example_Synthesis.m).
%   #Author: Piotr Majdak (2024): major documentation rework for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%% Part I: Filter example

%%% create the example filter: %%%

center_frequency_hz   =  1000;
bandwidth_hz          =   100;
attenuation_db        =     3;
fs                    = 44100;
filt_order          =     4;

filt = hohmann2002_filter(fs, center_frequency_hz, bandwidth_hz, attenuation_db, filt_order);

%%% print the filter's parameters to the screen %%%

amt_disp(['The filter coefficient of this filter is: ', num2str(real(filt.coefficient)),' + ', num2str(imag(filt.coefficient))]);
amt_disp(['Its normalization factor is             : ', num2str(filt.normalization_factor)]);


%%% plot the impulse response and the frequency response of this filter: %%%
impulse_samples            = 8192;
impulse_response_samples   =  800;
impulse                    = [1; zeros(impulse_samples - 1,1)];

[impulse_response, filt] = hohmann2002_process(filt, impulse);

figure(1);
plot(0:impulse_response_samples-1, [real(impulse_response(1:impulse_response_samples)) imag(impulse_response(1:impulse_response_samples)) abs(impulse_response(1:impulse_response_samples))]);
axis([0,impulse_response_samples, -0.035,0.035]);
title('impulse response of example gammatone filter');
xlabel('sample number');
ylabel('filter output');

amt_disp();
amt_disp(['Figure 1 shows the first ',num2str(impulse_response_samples),' samples of']);
amt_disp('the impulse response of a 4th order gammatone filter with a center'); 
amt_disp(['frequency of ',num2str(center_frequency_hz),'Hz and a 3dB-bandwidth of ',bandwidth_hz,'Hz.']);
amt_disp('Real part, imaginary part, and absolute value of the impulse ');
amt_disp('response are plotted as lines 1, 2, and 3, respectively.     ');

%% plot the frequency response of this filter: %%%

frequency_response = abs(fft(real(impulse_response)));
figure(2);
plot((0:(impulse_samples - 1)) * (fs / impulse_samples), 20 * log10(frequency_response));
axis([0,1500, -40,0]);
title('frequency response of example gammatone filter');
xlabel('frequency / Hz');
ylabel('filter response / dB');

amt_disp();
amt_disp('Figure 2 shows the frequency response function of this filter');
amt_disp('in dB over frequency in Hz.');

%% Part II: Filterbank example

flow = 70;
fhigh = 6700;
base_frequency_hz = 1000;
fs = 16276;
filters_per_ERB = 1.0;

amt_disp(['Building a filterbank for ', num2str(fs), 'Hz sampling frequency.']);
amt_disp(['Lower cutoff frequency: ', num2str(flow), 'Hz']);
amt_disp(['Upper cutoff frequency: ', num2str(fhigh), 'Hz']);
amt_disp(['Base frequency        : ', num2str(base_frequency_hz), 'Hz']);
amt_disp(['filters per ERB       : ', num2str(filters_per_ERB)]);
amt_disp();
analyzer = hohmann2002(fs, flow, base_frequency_hz, fhigh, filters_per_ERB);
bands = length(analyzer.center_frequencies_hz);
amt_disp(['filterbank contains ', num2str(bands), ' filters:']);

amt_disp(sprintf('%3s|%12s |%15s |%16s', '# ', 'f / Hz ', 'normalization', 'coefficient'));

%% display filter parameters of the individual filters
for band = 1:bands
  filt = analyzer.filters(band);
  amt_disp(sprintf('%3d|%12f |%15e | %f + %fi', band, analyzer.center_frequencies_hz(band), filt.normalization_factor, real(filt.coefficient), imag(filt.coefficient)),'volatile');
end
amt_disp();

%% plot the frequency response of the individual filters     

frequency = 0:2:fs/2;
h=hohmann2002_freqz(analyzer,exp(2*1i*pi*frequency/fs));

figure(3);
plot(frequency, 20 * log10(abs(h)));
axis([0, fs/2, -40, 7]);
title('frequency response of the individual filters in this filterbank');
xlabel('frequency / Hz');
ylabel('filter response / dB');

amt_disp('Figure 3 shows the frequency response of the individual filters.');


%% Part III: Example for combined analysis-synthesis filterbank system

%% First, create a filterbank analyzer as in Part I %%%

flow =    70;
fhigh =  6700;
base_frequency_hz         =  1000;
sampling_rate_hz          = 16276;
filters_per_ERB           =     1.0;
desired_delay_in_seconds  =     0.004;
filt_order              =     4;
bandwidth_factor          =     1.0;

amt_disp('Building analysis filterbank');
analyzer = hohmann2002(sampling_rate_hz, flow, base_frequency_hz, fhigh, filters_per_ERB, filt_order, bandwidth_factor);


%% Now create a synthesizer that can resynthesize the analyzer's output %%%

amt_disp(['Building synthesizer for an analysis-synthesis delay of ', num2str(desired_delay_in_seconds), ' seconds']);
synthesizer = hohmann2002_synth(analyzer, desired_delay_in_seconds);

%% Extract the synthesizer's parameters %%%
amt_disp(['The synthesizers parameters:','----------------------------']);
delay = synthesizer.delay;
mixer = synthesizer.mixer;

bands = length(mixer.gains);

amt_disp(sprintf('%3s|%7s | %22s | %5s', '# ', 'delay ', 'phase factor    ', 'gain / dB'));

for band = 1:bands
  amt_disp(fprintf('%3d|%7d | %9f + %9fi | %5.2f', band,delay.delays_samples(band),real(delay.phase_factors(band)), imag(delay.phase_factors(band)), 20*log10(mixer.gains(band))));
end

%%  plot the resynthesized impulse and the frequency response of the  %%%
%%  analysis-synthesis system                                         %%%

impulse = [1; zeros(8191,1)];
[analyzed_impulse, analyzer] = hohmann2002_process(analyzer, impulse);
[resynthesized_impulse, synthesizer] = hohmann2002_process(synthesizer, analyzed_impulse);

figure(4);
plot((0:8191)/sampling_rate_hz*1e3, resynthesized_impulse);
axis([40/sampling_rate_hz*1e3, 120/sampling_rate_hz*1e3, -1, 1]);
title('impulse response of the analysis-synthesis system');
xlabel('time / ms');
ylabel('system output');

amt_disp();
amt_disp('Figure 4 shows the impulse response of the analysis-synthesis');
amt_disp('system in the time domain.');
amt_disp();
amt_disp('Figure 5 shows its frequency response.');

frequency = (0:8191) * sampling_rate_hz / 8192;
figure(5)
plot(frequency, 20 * log10(abs(fft(resynthesized_impulse'))));
axis([0, sampling_rate_hz/2, -40, 5]);
title('frequency response of the analysis-synthesis-system');
xlabel('frequency / Hz');
ylabel('system response level / dB'); 

