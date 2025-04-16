function [] = exp_felsheim2024(varargin)
%exp_felsheim2024 Reproduce figures from Felsheim and Dietz (2024)
%
%   Usage: exp_felsheim2024(flag)
%
%   EXP_FELSHEIM2024(flag) reproduces the figures from Felsheim and Dietz (2024). 
%
%   The following flags can be specified:
%
%     'fig5a'     The I_{50} (current amplitude at 50% firing probability) for biphasic pulses with
%                 different phase durations is shown, normalized on the I_{60} of the pulse with 
%                 a 100-mu s phase duration. The figure shows both the predictions by the aLIFP model
%                 and the data recorded by Shepherd and Javel (1999) from a single cat auditory
%                 nerve fiber.
%
%     'fig5b'     The spike probability for different amplitdues for mono- and biphasic pulses
%                 with a phase duration 100 mu s and 0 mu s IPG are shown. The figure shows both the 
%                 predictions by the aLIFP model and the data recorded by Shepherd and Javel (1999) 
%                 from a single cat auditory nerve fiber.
% 
%     'fig5cd'    The spike latency (c) and the spike jitter (d) of monophasic pulses are shown. 
%                 The data is shown togehter with the predictions of the aLIPF model and was  
%                 collected by Miller et al. (1999), who used monophasic pulses with a duration 
%                 of 40 mu s and without IPG to stimulate a single cat auditory nerve fiber. 
% 
%     'fig6ab'    The mean I_50 (a) and relative spread (b) during the refractory period recorded 
%                 with monophasic pulses with a length of 40 mu s in 34 cat nerve fibers  
%                 (Miller et al., 2001) and a length of 100 mu s in 8 cat nerve fibers by 
%                 (Dynes, 1996), together with the predictions made by the aLIFP.
% 
%     'fig6cd'    In (c), the data by Dynes (1996) for facilitation by a single sub-threshold 
%                 pulse is shown, again, together with the predictions by both models and in (d), 
%                 the same is shown for four and 40 sub-threshold masker. Dynes (1996) used 
%                 monophasic pulses with a duration of 100 mu s.
%  
%     'fig6e'     The spike rate adaptation for different pulse rates and amplitudes, as measured 
%                 by Zhang et al. (2007). Our model was fitted at two amplitudes for each of the 
%                 pulse rates 250 pps, 1000 pps, and 5000 pps. The low amplitude was always 
%                 1.4 dB re I_{50}. For 250 pps and 1000 pps the high amplitude was 3.1 dB re I_{50} 
%                 and for 5000 pps the high amplitude was 4.0 dB re I_{50}. Note the slightly higher
%                 second amplitude for 5000 pps, which was used according to the data. .
%
%     'fig7'      The decrease in threshold due to facilitation is measured by Cartee et al. (2000) 
%                 by dividing the I_{50} of two pseudo-monophasic pulses by the I_{50} of a single of 
%                 these pulses. The data was collected by Cartee et al. (2000) using 38 cat nerve 
%                 fibers and is compared to predictions of the aLIFP model.
%
%     'fig8'      Facilitation and accommodation as calculated from spike trains by 
%                 Heffer et al. (2010). Negative values indicate accommodation, while positive 
%                 ones denote facilitation. The predictions from the aLIFP model fit the data 
%                 nicely, except for 2000 pps at low levels, where the aLIFP model overestimates 
%                 the facilitation.
%
%     'fig9'      Mean firing probability over level for four 100 mu s pulse trains with different 
%                 pulse rates. The x-axes give the amplitude in dB re I_{50} at 100 pps. 
%                 The data were collected on a single cat nerve fiber by Javel (1990) and 
%                 simulated using the aLIFP model.
%
%     'fig10'     Data collected by Miller et al. (2011), who measured the impact of a low 
%                 amplitude stimulus on a subsequent probe in 48 cat nerve fibers. The amplitudes 
%                 were placed around the spike threshold for the masker, defined as the level 
%                 where firing just started. 
%
%     'fig11'     The vector strength from Miller et al. (2008), Hartmann and Klinke (1990) and 
%                 Dynes and Delgutte (1992) for different pulse rates measured in cats. As the
%                 were made both for duration of the IPG was not clear, the predictions an IPG 
%                 of 0 mu s and 30 mu s. The predictions of the aLIFP model are not affected 
%                 by the IPG and it fits the data for both pulse shapes up to 1600 pps.
%
%     'fig12'     The spike rate and the vector strength of 100 Hz sinusoidally amplitude 
%                 modulated and unmodulated pulse trains with a rate of 5000 pps were calculated. 
%                 The predictions the aLIFP model were compared to data of 72 cat nerve fibers 
%                 from Hu et al. (2010). 
%
%     'figA1'     The vector strength obtained from the predictions of the aLIFP model for different 
%                 IPG durations and two amplitudes: 1 dB and 2 dB relative to single pulse I_{50}. 
%                 The left plot shows the predictions for a 2500 pps stimulus and the right one 
%                 for a 5000 pps stimulus, both with a duration of 0.3 s. For the 5000 pps 
%                 stimulus the calculations could only reasonably be performed up to 50 mu s IPG, 
%                 because for higher IPG values the gap between the pulses would have been
%                 shorter than the IPG.
%
%     'redo'      Force recalculation of the data. Cached data are shown per default. 
%
%
%   Examples:
%   ---------
%
%   To display Fig. 5a use :
%
%     exp_felsheim2024('fig5a'); 
%
%   To display Fig. 5b use :
%
%     exp_felsheim2024('fig5b'); 
%
%   To display Fig. 5cd use :
%
%     exp_felsheim2024('fig5cd'); 
%
%   To display Fig. 6ab use :
%
%     exp_felsheim2024('fig6ab'); 
%
%   To display Fig. 6cd use :
%
%     exp_felsheim2024('fig6cd'); 
%
%   To display Fig. 6e use :
%
%     exp_felsheim2024('fig6e'); 
%
%   To display Fig. 7 use :
%
%     exp_felsheim2024('fig7'); 
%
%   To display Fig. 8 use :
%
%     exp_felsheim2024('fig8'); 
%
%   To display Fig. 9 use :
%
%     exp_felsheim2024('fig9'); 
%
%   To display Fig. 10 use :
%
%     exp_felsheim2024('fig10'); 
%
%   To display Fig. 11 use :
%
%     exp_felsheim2024('fig11'); 
%
%   To display Fig. 12 use :
%
%     exp_felsheim2024('fig12'); 
%
%
%   See also:  felsheim2024 demo_felsheim2024 plot_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_felsheim2024.php


%   #Author: Rebecca C. Felsheim (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.
%   #Requirements: M-Stats

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


definput.import={'amt_cache'};

definput.flags.type = {'missingflag','fig5a','fig5b','fig5cd', 'fig6ab', 'fig6cd', 'fig6e', ...
                       'fig7', 'fig8', 'fig9', 'fig10', 'fig11', 'fig12', 'figA1'}; % to check: fig11, fig12

definput.keyvals.FontSize = 9;
definput.keyvals.MarkerSize = 3;

flags  = ltfatarghelper({'FontSize','MarkerSize'},definput,varargin);


if flags.do_missingflag
    flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
        sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
    error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end

colors = [0 0.4470 0.7410; ... %"#0072BD"
          0.8500 0.3250 0.0980; ... %[0.8500 0.3250 0.0980]
          0.9290 0.6940 0.1250; ... %"#EDB120"
          0.4940 0.1840 0.5560; ... %"#7E2F8E"
          0.4660 0.6740 0.1880; ... %"#77AC30"
          0.3010 0.7450 0.9330; ... %"#4DBEEE"
          0.6350 0.0780 0.1840; ... %"#A2142F"
          0 0 0; ... %"#000000"
          0 0 1; ... %"#0000FF"
          1 0 1]; %"#FF00FF"

%% Figure 5a: Shepherd and Javel (1999), stimulation threshold (I_50) over phase length

if flags.do_fig5a
    measured_data = amt_load('felsheim2024', 'Shepherd_Javel_1999_fig5.mat');
    measured_data = measured_data.data;

    amplitudes = (0.05:0.01:1.5) * 1e-3;
    phase_lengths = 50:10:200; % in microseconds

    data_I50 = nan(5,1);

    aLIFP_I50 = nan(size(phase_lengths));

    for ind = 1:7
        curr_x = measured_data(:, (ind * 2 - 1));
        curr_data = measured_data(:, (ind * 2));
        curr_x = 10 .^ (curr_x / 20) * 1e-3;
        curr_data = curr_data(~isnan(curr_x));
        curr_x = curr_x(~isnan(curr_x));

        [m, ~] = local_fitgaussian(curr_x, curr_data);

        data_I50(ind) = m;
    end


    for ind = 1:length(phase_lengths)
        pulse = [zeros(10,1); -1 * ones(phase_lengths(ind), 1);0; ones(phase_lengths(ind),1); zeros(100,1)];
        aLIFP_I50(ind) = local_getthreshold(pulse, amplitudes, 0.5);

    end

    figure("Name", "Figure 5a", "DefaultAxesFontsize", 13);

    plot([60, 80, 100, 120, 140, 160, 180], data_I50 / data_I50(3), 'x', 'MarkerSize', 10, 'LineWidth',2)
    hold on
    [~,m] = min(abs(phase_lengths - 100)); % I_50 is shown relative to the I_50 at 100 microseonds phase length
    plot(phase_lengths, aLIFP_I50 / aLIFP_I50(m), 'LineWidth', 2, 'color', [0 0.4470 0.7410]);

    grid on;
    ylabel("I_{50} / I_{50} at 100 \mus");
    xlabel("Phase length (\mus)");
    legend("data", "aLIFP")
end


%% Figure 5b: Shepherd and Javel (1999), spike probability for monophasic and biphasic pulses
if flags.do_fig5b
    measured_data = amt_load('felsheim2024', 'Shepherd_Javel_1999_fig4.mat');
    measured_data = measured_data.data;

    pulse_monophasic = [zeros(10,1); -1 * ones(100, 1); zeros(100,1)];
    pulse_biphasic = [zeros(10,1);  -1* ones(100, 1); ones(100,1); zeros(100,1)];

    x_monophasic = 10 .^ (measured_data(:,5) / 20) * 1e-3;
    x_biphasic = 10 .^ (measured_data(:,7) / 20) * 1e-3;


    data_monophasic = measured_data(~isnan(x_monophasic),6);
    x_monophasic(isnan(x_monophasic)) = [];

    data_biphasic = measured_data(~isnan(x_biphasic), 8);
    x_biphasic(isnan(x_biphasic)) = [];

    [monophasic_I50, ~] = local_fitgaussian(x_monophasic, data_monophasic);
    x_monophasic = 20 * log10(x_monophasic / monophasic_I50);
    x_biphasic = 20 * log10(x_biphasic / monophasic_I50);


    % compute the spike probabilities for the bi- and monophasic pulse
    amplitudes = 0.5:0.01:.8;

    aLIFP_probabilities_monophasic = zeros(size(amplitudes));
    aLIFP_probabilities_biphasic = zeros(size(amplitudes));


    for a_ind = 1:length(amplitudes)
        out_struct = felsheim2024(pulse_monophasic * amplitudes(a_ind) * 1e-3);
        aLIFP_probabilities_monophasic(a_ind) = out_struct(1).total_probability;

        out_struct = felsheim2024(pulse_biphasic * amplitudes(a_ind) * 1e-3);
        aLIFP_probabilities_biphasic(a_ind) = out_struct(1).total_probability;
    end

    [monophasic_I50, ~] = local_fitgaussian(amplitudes, aLIFP_probabilities_monophasic);

    amplitudes = 20 * log10(amplitudes / monophasic_I50);

    % plot the results
    figure("Name", "Figure 5b","DefaultAxesFontsize", 13);

    plot(x_monophasic, data_monophasic, 'x', 'LineWidth',2, 'markersize', 10);
    hold on;
    plot(amplitudes, aLIFP_probabilities_monophasic, 'color', [0 0.4470 0.7410], 'LineWidth',2);

    plot(x_biphasic, data_biphasic, 'x', 'color', [0.8500 0.3250 0.0980], 'LineWidth',2, 'markersize', 10)
    plot(amplitudes, aLIFP_probabilities_biphasic, 'color', [0.8500 0.3250 0.0980], 'LineWidth',2);
    xlim([-2,3])
    ylim([0,1.01])
    grid on

    legend( "data monophasic", "aLIFP monophasic", "data biphasic", "aLIFP biphasic",  'location', 'southeast');
    xlabel("Amplitude (dB re mono-phasic threshold)")
    ylabel("Spiking probability P_s")


end

%% Figure 5c and d: Miller et al. (1999), Latency and Jitter in the response to a monophasic pulse
if flags.do_fig5cd
    measured_data = amt_load('felsheim2024', 'Miller_1999_fig2.mat');
    data = measured_data.data;
    data_spiking_probability = measured_data.data_spiking_probability;
    spiking_probability = data_spiking_probability(:,2) / 100;
    data_amplitude = data(:,1);


    [data_I50,~] = local_fitgaussian(data_amplitude, spiking_probability);


    latency = data(:,2);
    jitter = (data(:,3) -latency) * 2;

    pulse = [zeros(100,1); -1 * ones(40,1);  zeros(100,1)];

    amplitudes = (1:0.01:1.4) * 1e-3;

    modelled_latency = zeros(size(amplitudes));
    modelled_jitter = zeros(size(amplitudes));

    % run the aLIPF model
    pulse_start = 101 / 1e6;
    aLIFP_probabilties = zeros(size(amplitudes));

    for a = 1:length(amplitudes)
        out_struct = felsheim2024(pulse * amplitudes(a));
        aLIFP_probabilties(a) = out_struct.total_probability;
        modelled_latency(a) = out_struct(1).mu - pulse_start;
        modelled_jitter(a) = out_struct(1).sigma;
    end

    [aLIFP_I50, ~] = local_fitgaussian(amplitudes, aLIFP_probabilties);

    modelled_latency = modelled_latency * 1e3;
    modelled_jitter = modelled_jitter * 1e6;

    % plot the results
    fig = figure("Name", "Figure 5c","DefaultAxesFontsize", 13);
    fig.InnerPosition = [0 0 550, 450];

    plot(data_amplitude / data_I50, latency,  'x',  'LineWidth',2, 'markersize', 10);
    hold on
    plot(amplitudes / aLIFP_I50, modelled_latency, 'LineWidth', 2, 'color', [0 0.4470 0.7410]);

    legend("data", "aLIFP");
    ylabel("Spike latency, \mu_{st}-t_{start} (ms)");
    xlabel("Amplitude re I_{50}")
    grid on;
    xlim([0.89, 1.21])
    ylim([0.5, 0.81])


    fig2 = figure("Name", "Figure 5d","DefaultAxesFontsize", 13);
    fig2.InnerPosition = [0 0 550, 450];
    plot(data_amplitude / data_I50, jitter * 1e3,  'x',  'LineWidth',2, 'markersize', 10);
    hold on
    plot(amplitudes / aLIFP_I50, modelled_jitter, 'LineWidth', 2, 'color', [0 0.4470 0.7410]);

    ylabel("Spike jitter, \sigma_{st} (\mus)");
    legend("data", "aLIFP", 'location', 'southwest');
    xlim([0.89, 1.21])
    ylim([10, 135])

    xlabel("Amplitude re I_{50}")
    grid on;

end


%% Figure 6a and b: Miller et al. (2001) and Dynes (1996), change in stimulation threshold (I_50) 
% and relative spread during the refractory period
if flags.do_fig6ab
    measured_data = amt_load('felsheim2024', 'Miller_2001_fig7.mat');
    measured_data = measured_data.data;
    x = amt_load('felsheim2024', 'Dynes1996_refraction.mat');

    dynes_threshold_change = 10.^(x.data_Dynes1996.thrDynes / 20);
    dynes_ipi = x.data_Dynes1996.ipiDynes;

    measured_ipi = measured_data(:,1);
    measured_threshold_change = measured_data(:,2);
    measured_relative_spread_change = measured_data(:,5);

    unmasked_I50 = nan;
    unmasked_relative_spread = nan;

    masked_I50s = nan(size(measured_ipi));
    masked_relative_spread = nan(size(measured_ipi));


    amplitudes = [0, 0.05:0.05:20] * 1e-3;

    masker_probe_intervals = [0, 300:100:2000, 2200:200:4000, 4500, 5000:1000:12000]';


    phase_length = 100;

    data =  amt_cache('get', 'data_fig6ab', flags.cachemode);

    if isempty(data)

        % compute aLIPF predictions
        for ind = 1:length(masker_probe_intervals)

            lower_rs = nan;
            upper_rs = nan;

            curr_I50 = nan;

            last_probability = 0;
            all_probabilities = zeros(1,length(amplitudes));
            for a_ind = 2:length(amplitudes)
                if ind == 1
                    signal = [zeros(100, 1); -1 * ones(phase_length,1) * amplitudes(a_ind); zeros(100,1)];
                else
                    signal = [zeros(100,1); -1 * ones(phase_length,1) * 3 * unmasked_I50; ...
                              zeros(masker_probe_intervals(ind) - 40, 1); -1 * ones(phase_length,1) * amplitudes(a_ind); ...
                              zeros(100,1)];
                end
                out_struct = felsheim2024(signal);

                if out_struct(end).total_probability >= 0.16 && isnan(lower_rs)
                    m = (amplitudes(a_ind) - amplitudes(a_ind - 1)) / (out_struct(end).total_probability - last_probability);
                    lower_rs = m * (0.16 - last_probability) + amplitudes(a_ind - 1);
                end
                if out_struct(end).total_probability >= 0.5 && isnan(curr_I50)
                    m = (amplitudes(a_ind) - amplitudes(a_ind - 1)) / (out_struct(end).total_probability - last_probability);
                    curr_I50 = m * (0.5 - last_probability) + amplitudes(a_ind - 1);
                end

                if out_struct(end).total_probability >= 0.84 && isnan(upper_rs)
                    m = (amplitudes(a_ind) - amplitudes(a_ind - 1)) / (out_struct(end).total_probability - last_probability);
                    upper_rs = m * (0.84 - last_probability) + amplitudes(a_ind - 1);
                    break;
                end

                last_probability = out_struct(end).total_probability;
                all_probabilities(a_ind) = last_probability;

            end

            curr_relative_spread = (upper_rs - lower_rs) /( 2 * curr_I50);


           if ind == 1
                unmasked_I50 = curr_I50;
                unmasked_relative_spread = curr_relative_spread;

            else
                masked_I50s(ind - 1) = curr_I50 / unmasked_I50;
                masked_relative_spread(ind - 1) = curr_relative_spread / unmasked_relative_spread;

            end


        end

        data.masked_I50s = masked_I50s;
        data.masked_relative_spread = masked_relative_spread;

        amt_cache('set', 'data_fig6ab', data);

    else
        masked_I50s = data.masked_I50s;
        masked_relative_spread = data.masked_relative_spread;
    end

    measured_ipi = measured_ipi / 1e3;
    masker_probe_intervals = masker_probe_intervals / 1e3;
    dynes_ipi = dynes_ipi / 1e3;

    % plot the results
    figure("Name", "Figure 6a","DefaultAxesFontsize", 13);

    plot(measured_ipi, measured_threshold_change, 'x', 'MarkerSize',10, 'LineWidth',2);
    hold on;
    plot(dynes_ipi, dynes_threshold_change, 'o', 'color', [0 0.4470 0.7410], 'MarkerSize',10, 'LineWidth',2);
    plot(masker_probe_intervals(2:end), masked_I50s, '-', 'LineWidth',2, 'color', [0 0.4470 0.7410]);
    legend("Miller et al. (2001)", "Dynes (1996)", "aLIFP");
    ylabel("I_{50} re Unmasked I_{50}");
    xlabel("Masker-Pulse Interval (ms)")
    grid on;
    ylim([0.8,3])
    xlim([0,12])

    figure("Name", "Figure 6b","DefaultAxesFontsize", 13);
    plot(measured_ipi, measured_relative_spread_change, 'x', 'MarkerSize',10, 'LineWidth',2);
    hold on;
    plot(masker_probe_intervals(2:end), masked_relative_spread, '-','LineWidth',2, 'Color', [0 0.4470 0.7410]);
    legend("Miller et al. (2001)", "aLIFP");
    ylabel("Relative spread re Unmasked relative spread");
    xlabel("Masker-Pulse Interval (ms)")
    grid on;
    ylim([0.6,5])
    xlim([0,12])

end


%% Figure 6c and d: Dynes (1996), Change in stimulation threshold (I_50) after stimulation with 
% 1, 4, or 40 sub-threhsold masker (Facilitation)
if flags.do_fig6cd
    measured_data = amt_load('felsheim2024', 'Dynes_1996_fig4-1.mat');
    measured_data = measured_data.data;

    phaseL = 100; % in microseconds

    amplitudes = [0, 0.05:0.01:2] * 1e-3;

    pulse = -1 * ones(phaseL,1);
    single_pulse_I50 = local_getthreshold(pulse, amplitudes, 0.5);

    masker_amplitudes = single_pulse_I50 * 0.89; % taken from the paper

    masker = [1, 4, 40];


    all_I50s = amt_cache('get', 'data_fig6cd', flags.cachemode);


    if isempty(all_I50s)
        all_I50s = cell(length(masker), 1);

        for m_ind = 1:length(masker) 

            ipis = round(measured_data(:, (m_ind * 2) - 1) * 1e3);
            ipis = ipis(~isnan(ipis));

            curr_I50s = nan(size(ipis));

            curr_maskers = [];

            for tmp_ind = 1:masker(m_ind)
                curr_maskers = [curr_maskers; zeros(1000 - phaseL,1); pulse * masker_amplitudes];
            end

            for ind = 1:length(ipis)

                for a_ind = 2:length(amplitudes)
                    curr_signal = [curr_maskers; zeros(ipis(ind) - phaseL,1); pulse * amplitudes(a_ind) ;zeros(100,1)];

                    out_struct = felsheim2024(curr_signal);

                    if sum([out_struct(end).total_probability]) >= 0.5

                        m = (amplitudes(a_ind) - amplitudes(a_ind - 1)) / ...
                            (sum([out_struct(end).total_probability]) - last_probability);
                        curr_I50s(ind) = m * (0.5 - last_probability) + amplitudes(a_ind - 1);

                        curr_I50s(ind) = curr_I50s(ind) / single_pulse_I50;
                        break;
                    end
                    last_probability = [out_struct(end).total_probability];

                    curr_I50s(ind) = curr_I50s(ind) / single_pulse_I50;

                end

            end

            all_I50s{m_ind} = curr_I50s;

        end

        amt_cache('set', 'data_fig6cd', all_I50s);

    end

    for m_ind = 1:length(masker) 

        ipis = round(measured_data(:, (m_ind * 2) - 1) * 1e3);
        data = measured_data(:, m_ind * 2);

        data = data(~isnan(ipis));
        data = 10.^(data / 20);
        ipis = ipis(~isnan(ipis));

        curr_I50s = all_I50s{m_ind};

        if masker(m_ind) == 1
            fig = figure("Name", "Figure6c","DefaultAxesFontsize", 13);
        elseif masker(m_ind) == 4
            fig = figure("Name", "Figure6e","DefaultAxesFontsize", 13);
        end

        fig.OuterPosition = [0 0 600, 600];

        hold on;

        plot(ipis * 1e-3, data, 'x', 'MarkerSize',10, 'LineWidth',2, 'color', colors(m_ind,:));
        plot(ipis * 1e-3, curr_I50s, '-', 'LineWidth', 2, 'color', colors(m_ind,:));

        if masker(m_ind) == 1
            legend("data, 1 masker", "aLIFP, 1 masker", "location", "southeast");
        elseif masker(m_ind) == 40
            legend("data, 4 masker", "aLIFP, 4 masker", "data, 40 masker", "aLIFP, 40 masker", "location", "southeast");
        end

        ylabel("I_{50} re Single Pulse I_{50}")
        xlabel("Masker-Pulse Interval (ms)")
        ylim([0.2, 1.3])
        grid on

    end

end

if flags.do_fig6e

    data = amt_load('felsheim2024', 'Zhang_2007_fig2.mat');
    data = data.data;

    aLIFP_base_amplitude = 2.2e-3;

    % these values have been fitted together with the data
    lower_offset_dB = -1.7;
    upper_offset_dB = 0.9;


    pulse = [-1 * ones(40,1); ones(40,1)];

    % calculate the stimulating amplitudes realtive to the fitted one
    test_amplitudes = 1:0.05:2;
    aLIFP_I50 = local_getthreshold(pulse, test_amplitudes * 1e-3, 0.5);

    aLIFP_base_amplitude_dB = 20 * log10(aLIFP_base_amplitude / aLIFP_I50);

    aLIFP_lower_amplitude = aLIFP_base_amplitude * 10.^(lower_offset_dB/20);
    aLIFP_upper_amplitude = aLIFP_base_amplitude * 10.^(upper_offset_dB/20);

    amplitudes = [aLIFP_lower_amplitude, aLIFP_lower_amplitude, aLIFP_lower_amplitude;...
                            aLIFP_base_amplitude, aLIFP_base_amplitude, aLIFP_upper_amplitude];
    amplitudes_dB = [aLIFP_base_amplitude_dB + lower_offset_dB, aLIFP_base_amplitude_dB + lower_offset_dB, aLIFP_base_amplitude_dB + lower_offset_dB; ...
                     aLIFP_base_amplitude_dB, aLIFP_base_amplitude_dB, aLIFP_base_amplitude_dB + upper_offset_dB];

    % indices to access the correct parts of the dataset, as not all data was used (do not change!)
    data_inds = [4, 7, 9; 2, 5, 8];


    x_bins = [0;4;12;24;36;48;100; 200; 300] * 1e-3;
    length_x_bins = length(x_bins) - 1; % needed to allow for the parallel loop
    pulse_rates = [250, 1000, 5000];

    x_values = x_bins(2:end) - diff(x_bins)/2;

    mean_spiking_probability = amt_cache('get', 'data_fig6e', flags.cachemode);

    if isempty(mean_spiking_probability)

        mean_spiking_probability = nan(length(pulse_rates), 2, length(x_bins)- 1);

        % calculate the mean spiking probability
        for p_ind = 1:length(pulse_rates)
            stimulus = sig_pulsetrain(0.3, pulse_rates(p_ind), pulse);

            for amp_ind = 1:2

                [out_struct] = felsheim2024(stimulus * amplitudes(amp_ind,p_ind));    

                dist = felsheim2024_spikeprobability(out_struct, max(x_bins), 1e6, 'fast');
                for ind = 1:length_x_bins
                    curr_dist = dist(round(x_bins(ind) * 1e6)+1:round(x_bins(ind + 1) * 1e6));
                    mean_spiking_probability(p_ind, amp_ind, ind) = sum(curr_dist)  / (x_bins(ind + 1) - x_bins(ind));
                end

            end

        end

        amt_cache('set', 'data_fig6e', mean_spiking_probability);

    end

    %% plot the results
    fig = figure("Name", "Figure6e", "DefaultAxesFontsize", 13);
    fig.OuterPosition = [0 0 1200, 700];
    ax=subplot(2,3,1); %t = tiledlayout(2,3, "padding", "none"); % use this when on Matlab 2019b or later
    %t.TileIndexing = 'columnmajor'; % use this when on Matlab 2019b or later

    for p_ind = 1:length(pulse_rates)
        for amp_ind = 1:2
            subplot(2,3,(p_ind-1)*2+amp_ind);%ax = nexttile;
            hold on

            plot(x_values, squeeze(mean_spiking_probability(p_ind, amp_ind, :)), 'o-', 'Linewidth', 2, 'Markersize', 8, "color", [0 0.4470 0.7410]);
            plot(x_values, data(:, data_inds(amp_ind, p_ind)), 'xk', 'Linewidth', 2, 'markersize', 8);
            xlabel("Time (s)")
            ylabel("Spike rate (spike/s)");
            title(sprintf("%d pps, %.1f dB re I_{50}", pulse_rates(p_ind), amplitudes_dB(amp_ind, p_ind)))
            grid on

            m = max([squeeze(mean_spiking_probability(p_ind, amp_ind, :));...
                    data(:, data_inds(amp_ind, p_ind))], [], 'all');

            ylim([0, ceil(m / 100) * 100]);

        end
    end


    leg = legend(ax, "aLIFP", "data", "orientation", "horizontal");
    %leg.Layout.Tile = 'north'; % use this when on Matlab 2019b or later


end

%% Figure 7: Cartee et al. (2000), Facilitation with pseudo-monophasic pulses
if flags.do_fig7
    x = amt_load('felsheim2024', 'Cartee2000.mat');
    facilitation_Cartee2000 = x.facilitation_Cartee2000;

    data_ipis = [100, 200, 300]; % in microseconds
    ipis = 100:5:300;
    phaseL = 50;
    amplitudes = (0.01:0.01:2) * 1e-3;

    I50s = nan(size(ipis));

    for ind = 1:length(ipis)
        pulse = [-1 * ones(phaseL,1);ones(ipis(ind)-phaseL,1)./((ipis(ind)-phaseL)/phaseL)];
        double_pulse = [zeros(100,1);pulse;pulse;zeros(100,1)];

        single_pulse_I50 = local_getthreshold(pulse, amplitudes, 0.5);
        double_pulse_I50 = local_getthreshold(double_pulse, amplitudes, 0.5);

        I50s(ind) = double_pulse_I50 / single_pulse_I50;

    end

    means(1) = mean(facilitation_Cartee2000.raw(1:15,2));
    means(2) = mean(facilitation_Cartee2000.raw(16:30,2));
    means(3) = mean(facilitation_Cartee2000.raw(31:43,2));

    stds(1) = std(facilitation_Cartee2000.raw(1:15,2));
    stds(2) = std(facilitation_Cartee2000.raw(16:30,2));
    stds(3) = std(facilitation_Cartee2000.raw(31:43,2));


    fig = figure("Name", "Figure7", "DefaultAxesFontsize", 13);
    fig.OuterPosition = [0 0 600, 600];
    errorbar(data_ipis, means, stds, 'xk', 'MarkerSize',10, 'LineWidth',2);
    hold on;
    plot(ipis, I50s, 'LineWidth', 2, "color", [0 0.4470 0.7410]);

    legend("data", "aLIFP");
    ylabel("I_{50} re Single pulse I_{50}")
    xlabel("Masker-Pulse Interval (\mus)")
    xlim([100, 300])
    grid on

end

%% Figure 8, Heffer et al. (2010), Facilitation and accommodation with pulse trains
if flags.do_fig8
    x = amt_load('felsheim2024', 'Heffer2010.mat');
    data_Heffer2010 = x.data_Heffer2010;


    signal_length = 2e-3;
    stim_rates = [200, 1000, 2000, 5000]; 

    % target probabilities to test
    low_level_probabilities = (0.02:0.02:0.18);
    medium_level_probabilities = (0.3:0.05:0.7);
    high_level_probabilities = (0.75:0.025:0.95);

    pulse = [-1 * ones(25,1); zeros(8,1); ones(25,1)];
    amplitudes = (0.8:0.1:4) * 1e-3;

    % get the corresponding amplitude values
    low_levels = zeros(size(low_level_probabilities));
    for ind = 1:length(low_level_probabilities)
        low_levels(ind) = local_getthreshold(pulse, amplitudes, low_level_probabilities(ind));
    end

    medium_levels = zeros(size(medium_level_probabilities));
    for ind = 1:length(medium_level_probabilities)
        medium_levels(ind) = local_getthreshold(pulse, amplitudes, medium_level_probabilities(ind));
    end

    high_levels = zeros(size(high_level_probabilities));
    for ind = 1:length(high_level_probabilities)
        high_levels(ind) = local_getthreshold(pulse, amplitudes, high_level_probabilities(ind));
    end


    % calculate the model predictions
    onset_probabilities_low = nan(length(stim_rates), length(low_levels));
    predicted_probabilities_low = nan(length(stim_rates),length(low_levels));

    onset_probabilities_medium = nan(length(stim_rates), length(medium_levels));
    predicted_probabilities_medium = nan(length(stim_rates),length(medium_levels));

    onset_probabilities_high = nan(length(stim_rates), length(high_levels));
    predicted_probabilities_high = nan(length(stim_rates),length(high_levels));

    for s_ind = 1:length(stim_rates)

        [stimulus, num_pulses] = sig_pulsetrain(signal_length, stim_rates(s_ind), pulse);

        for l_ind = 1:length(low_levels)
            [out_struct] = felsheim2024(stimulus * low_levels(l_ind));
            onset_probabilities_low(s_ind, l_ind) = min(1,sum([out_struct.total_probability]));
            predicted_probabilities_low(s_ind, l_ind) = min(1,onset_probabilities_low(1, l_ind) * num_pulses);
        end

        for l_ind = 1:length(medium_levels)
            [out_struct] = felsheim2024(stimulus * medium_levels(l_ind));
            onset_probabilities_medium(s_ind, l_ind) = min(1,sum([out_struct.total_probability]));
            predicted_probabilities_medium(s_ind, l_ind) = min(1,onset_probabilities_medium(1, l_ind) * num_pulses);
        end

        for l_ind = 1:length(high_levels)
            [out_struct] = felsheim2024(stimulus * high_levels(l_ind));
            onset_probabilities_high(s_ind, l_ind) = min(1,sum([out_struct.total_probability]));
            predicted_probabilities_high(s_ind, l_ind) = min(1,onset_probabilities_high(1, l_ind) * num_pulses);
        end
    end

    probability_change_low = onset_probabilities_low - predicted_probabilities_low;
    probability_change_medium = onset_probabilities_medium - predicted_probabilities_medium;
    probability_change_high = onset_probabilities_high - predicted_probabilities_high;

    % plot the results
    visual_off = 0.07;

    fig = figure("Name", "Figure 8","DefaultAxesFontsize", 13);
    fig.OuterPosition = [0 0 1500, 600];
    subplot(1,3,1); %tiledlayout(1,3); % use this when on Matlab 2019b or later

    %nexttile % use this when on Matlab 2019b or later
    lower_error = data_Heffer2010(3).change(1:4,2) - data_Heffer2010(3).change(5:2:end,2);
    upper_error = data_Heffer2010(3).change(6:2:end,2) -  data_Heffer2010(3).change(1:4,2);
    errorbar((1:4) - visual_off, data_Heffer2010(3).change(1:4,2), lower_error, upper_error , 'square', 'linewidth', 2, "color", "black");
    hold on;

    curr_lower = prctile(probability_change_high, 25, 2);
    curr_upper = prctile(probability_change_high, 75, 2);
    curr_mean = median(probability_change_high, 2);
    errorbar((1:4) + visual_off, curr_mean, curr_mean - curr_lower, curr_upper - curr_mean, 'square', 'linewidth', 2, "color", [0 0.4470 0.7410]);

    ylabel("Spike probability change");
    xticks(1:4);
    xticklabels(["200", "1000", "2000", "5000"]);
    xlabel("Pulse rate (pps)");
    title("High level");
    ylim([-0.4,1]);
    xlim([0.5, 4.5]);
    yline(0);

    subplot(1,3,2); % nexttile % use this when on Matlab 2019b or later
    lower_error = data_Heffer2010(2).change(1:4,2) - data_Heffer2010(2).change(5:2:end,2);
    upper_error = data_Heffer2010(2).change(6:2:end,2) -  data_Heffer2010(2).change(1:4,2);
    errorbar((1:4) - visual_off, data_Heffer2010(2).change(1:4,2), lower_error, upper_error , 'square', 'linewidth', 2, "color", "black");
    hold on;

    curr_lower = prctile(probability_change_medium, 25, 2);
    curr_upper = prctile(probability_change_medium, 75, 2);
    curr_mean = median(probability_change_medium, 2);
    errorbar((1:4) + visual_off, curr_mean, curr_mean - curr_lower, curr_upper - curr_mean, 'square', 'linewidth', 2, "color", [0 0.4470 0.7410]);

    ylabel("Spike probability change");
    xticks(1:4);
    xticklabels(["200", "1000", "2000", "5000"]);
    xlabel("Pulse rate (pps)");
    title("Medium level");
    ylim([-0.4,1]);
    xlim([0.5, 4.5]);
    yline(0);

    ax=subplot(1,3,3); %ax = nexttile; % use this when on Matlab 2019b or later
    lower_error = data_Heffer2010(1).change(1:4,2) - data_Heffer2010(1).change(5:2:end,2);
    upper_error = data_Heffer2010(1).change(6:2:end,2) -  data_Heffer2010(1).change(1:4,2);
    errorbar((1:4) - visual_off, data_Heffer2010(1).change(1:4,2), lower_error, upper_error , 'square', 'linewidth', 2, "color", "black");
    hold on;

    curr_lower = prctile(probability_change_low, 25, 2);
    curr_upper = prctile(probability_change_low, 75, 2);
    curr_mean = median(probability_change_low, 2);
    errorbar((1:4) + visual_off, curr_mean, curr_mean - curr_lower, curr_upper - curr_mean, 'square', 'linewidth', 2, "color", [0 0.4470 0.7410]);

    ylabel("Spike probability change");
    xticks(1:4);
    xticklabels(["200", "1000", "2000", "5000"]);
    xlabel("Pulse rate (pps)");
    title("Low level");
    ylim([-0.4,1]);
    xlim([0.5, 4.5]);
    yline(0);

    lg = legend(ax, "data", "aLIFP", 'numcolumns', 3);
    %lg.Layout.Tile = "North"; % use this when on Matlab 2019b or later
end

%% Figure 9: Javel (1999), mean spike probability of pulse trains
if flags.do_fig9
    x = amt_load('felsheim2024', 'Javel1990.mat');
    data_Javel1990 = x.data_Javel1990;


    pulse_rates = [100, 200, 400, 800];
    pulse = [-1 * ones(50,1); zeros(0,1); ones(50,1)];
    amplitudes = (1:0.1:3.2) * 1e-3;

    a_length = length(amplitudes); % needed because of the parfor loop

    mean_spiking_probability = amt_cache('get', 'data_fig9', flags.cachemode);

    if isempty(mean_spiking_probability)

        mean_spiking_probability = zeros(length(pulse_rates), length(amplitudes));

        for p_ind = [1, 2, 3, 4]

            stimulus = sig_pulsetrain(0.1, pulse_rates(p_ind), pulse);

            for a_ind = 1:a_length
                [out_struct] = felsheim2024(stimulus * amplitudes(a_ind));

                mean_spiking_probability(p_ind, a_ind) = mean([out_struct.total_probability]);
            end

        end

        amt_cache('set', 'data_fig9', mean_spiking_probability);

    end

    [I50_phaseL100, ~] = local_fitgaussian(amplitudes, mean_spiking_probability(1, :));

    fig = figure("Name", "Figure 9","defaultaxesfontsize", 13);
    fig.InnerPosition = [0 0 600, 550];
    hold on;

    for p_ind =[1,2,3,4]

        if p_ind == 1
            curr_data_amplitude = data_Javel1990.hundred(:,1);
            curr_data = data_Javel1990.hundred(:,2);
        elseif p_ind == 2
            curr_data_amplitude = data_Javel1990.twoH(:,1);
            curr_data = data_Javel1990.twoH(:,2);
        elseif p_ind == 3
            curr_data_amplitude = data_Javel1990.fourH(:,1);
            curr_data = data_Javel1990.fourH(:,2);
        else
            curr_data_amplitude = data_Javel1990.eightH(:,1);
            curr_data = data_Javel1990.eightH(:,2);
        end

        curr_data_amplitude = 10.^(curr_data_amplitude/20);
        if p_ind == 1
            [data_threshold,~] = local_fitgaussian(curr_data_amplitude, data_Javel1990.hundred(:,2));
        end

        plot(20 * log10(curr_data_amplitude / data_threshold), curr_data, 'x','color', colors(p_ind,:), 'MarkerSize',10, "LineWidth",2)
        plot(20 * log10(amplitudes/I50_phaseL100), mean_spiking_probability(p_ind,:),'color', colors(p_ind,:), 'LineWidth', 1.5);
        ylabel("Mean firing probability");
        xlabel("Stimulus level (dB re 100 pps)")
        xlim([-2,8])
        grid on
    end

    legend("data 100 pps", "aLIFP 100 pps", ...
                    "data 200 pps", "aLIFP 200 pps", ...
                    "data 400 pps", "aLIFP 400 pps", ...
                    "data 800 pps", "aLIFP 800 pps", 'location', 'northoutside', ...
                    "orientation", "horizontal", 'NumColumns', 2, "fontsize", 13);



end

%% Figure 10: Miller et al (2011), accommodation with a 250 pps and 5000 pps masker
if flags.do_fig10
    x = amt_load('felsheim2024', 'Miller_2011_fig2.mat');
    accommodation_Miller2011 = x.accommodation_Miller2011;

    masker_level = 0.9e-3;
    probe_level = 1.1e-3; %1.05e-3;

    test_levels_dB = -3:1:4; % in dB
    test_levels =  masker_level * 10 .^(test_levels_dB/20);

    pulse = [-1 * ones(40,1); zeros(30,1); ones(40,1)];

    data = amt_cache('get', 'data_fig10', flags.cachemode);

    if isempty(data)
        % probe definition
        pps =100;
        len = 0.250; % in seconds
        probe = sig_pulsetrain(len, pps, pulse);

        % 250 pps masker definition
        pps = 250;
        len = 0.2; % in seconds

        [masker250, num_pulses250] =  sig_pulsetrain(len, pps, pulse);

        % 5000 pps masker definition
        pps = 5000;
        len = 0.2; % in seconds
        [masker5000, num_pulses5000] =  sig_pulsetrain(len, pps, pulse);


        % no masker
        [out_dist_probe] = felsheim2024(probe * probe_level);
        unmasked_spike_probability = mean([out_dist_probe(:).total_probability]);


        % compute response to 250pps masker

        masker250_spike_probability = zeros(size(test_levels));

        amt_disp(''); % start of volatile display
        for l_ind = 1:length(test_levels)
		    amt_disp(['250-pps masker: Calculating for level ' num2str(test_levels(l_ind) * 1e3) ...
			          ' (condition #' num2str(l_ind) ' of ' num2str(length(test_levels)) ')...'], 'volatile'); 
            curr_stimulus = [masker250 * test_levels(l_ind); probe * probe_level];
            out_dist = felsheim2024(curr_stimulus);
            masker250_spike_probability(l_ind) = mean([out_dist(num_pulses250 + 1:end).total_probability]);            
        end

        % compute response to 5000pps masker
        masker5000_spike_probability = zeros(size(test_levels));
        for l_ind = 1:length(test_levels)
		    amt_disp(['5000-pps masker: Calculating for level ' num2str(test_levels(l_ind) * 1e3) ...
			          ' (condition #' num2str(l_ind) ' of ' num2str(length(test_levels)) ')...'], 'volatile'); 
            curr_stimulus = [masker5000 * test_levels(l_ind); probe * probe_level];
            out_dist = felsheim2024(curr_stimulus);
            masker5000_spike_probability(l_ind) = mean([out_dist(num_pulses5000 + 1:end).total_probability]);
        end
		amt_disp(); %end of volatile display

        masker5000_spike_probability = masker5000_spike_probability/unmasked_spike_probability;
        masker250_spike_probability = masker250_spike_probability/unmasked_spike_probability;

        data.masker5000_spike_probability = masker5000_spike_probability;
        data.masker250_spike_probability = masker250_spike_probability;

        amt_cache('set', 'data_fig10', data);

    else
        masker5000_spike_probability = data.masker5000_spike_probability;
        masker250_spike_probability = data.masker250_spike_probability;

    end

    % plot the results
    fig = figure("Name", "Figure10");
    fig.Position = [0 0 1000, 400];
    subplot(1,2,1); %tiledlayout(1,2, "Padding", "compact"); % use this when on Matlab 2019b or later
    %nexttile % use this when on Matlab 2019b or later
    scatter(accommodation_Miller2011.Masker250.Raw.MaskerLevel, accommodation_Miller2011.Masker250.Raw.Recovery, 'o', ...
                'MarkerEdgeColor', [0.3555    0.5000    0.1797],  'MarkerEdgeAlpha', 0.5)
    hold on
    plot(accommodation_Miller2011.Masker250.Medians.MaskerLevel, accommodation_Miller2011.Masker250.Medians.Recovery, ...
                "kx-", "MarkerSize", 8, "LineWidth",2);
    plot(test_levels_dB, masker250_spike_probability, "o-", "color", [0 0.4470 0.7410], ...
                "LineWidth", 2, "MarkerSize", 8 );

    xlabel("Masker level (dB re thr)")
    ylabel("Probe recorvery ratio");
    title(sprintf("250 pps"))
    grid on

    ax=subplot(1,2,2); %ax = nexttile; % use this when on Matlab 2019b or later
    scatter(accommodation_Miller2011.Masker5000.Raw.MaskerLevel, accommodation_Miller2011.Masker5000.Raw.Recovery, 'o', ...
        'MarkerEdgeColor', [0.3555    0.5000    0.1797], 'MarkerEdgeAlpha', 0.5)
    hold on;

    plot(accommodation_Miller2011.Masker5000.Medians.MaskerLevel, accommodation_Miller2011.Masker5000.Medians.Recovery, ...
        "kx-", "MarkerSize", 8, "LineWidth",2);
    plot(test_levels_dB, masker5000_spike_probability, "o-", "color", [0 0.4470 0.7410], ...
        "Linewidth", 2, "MarkerSize", 8 );

    xlabel("Masker level (dB re thr)")
    ylabel("Probe recorvery ratio");
    title("5000 pps")
    grid on
    leg = legend(ax, "raw data", "median data", "aLIFP", "orientation", "horizontal");
    %leg.Layout.Tile = 'north'; % use this when on Matlab 2019b or later


end

%% Figure 11: Miller et al. (2008), Hartmann and Klinke (1990), Dynes and Delgutte (1992), vector strength
if flags.do_fig11
    x = amt_load('felsheim2024', 'vector_strength_data.mat');
    temporal_coding_data = x.temporal_coding_data;

    ipgs = [0, 30]; 

    pulse_rates = [50, 100, 200, 400, 800, 1000, 1250, 1600, 2500, 5000];


    vector_strength = amt_cache('get', 'data_fig11', flags.cachemode);

    if isempty(vector_strength)
        vector_strength = nan(length(ipgs), length(pulse_rates));

        % obtain the aLIFP predictions
     	amt_disp(''); % start of volatile display
        for i_ind = 1:length(ipgs)
            pulse = [-1 * ones(40,1); zeros(ipgs(i_ind),1); ones(40,1)];
            pulse_amplitude = local_getthreshold(pulse, (0.4:0.05:3)*1e-3, 0.9); 
			
            for p_ind = 1:length(pulse_rates)
                amt_disp(['Calculating for IPG #' num2str(i_ind) ' of ' num2str(length(ipgs)) ...
				          ' and pulse rate #' num2str(p_ind) ' of ' num2str(length(pulse_rates)) '...'], 'volatile');
                pulse_train = sig_pulsetrain(0.3, pulse_rates(p_ind), pulse);

                out_struct = felsheim2024(pulse_train * pulse_amplitude);

                dist = felsheim2024_spikeprobability(out_struct, 0.3);
                vector_strength(i_ind, p_ind) = local_vectorstrength(dist, pulse_rates(p_ind));
            end
        end		
		amt_disp(); %end of volatile display
        amt_cache('set', 'data_fig11', vector_strength);
    end

    % plot the results
    figure("Name", "Figure11");

    legend_entries = "";

    for i_ind = 1:length(ipgs)
        semilogx(pulse_rates, vector_strength(i_ind,:),"o-", "Markersize", 8, 'LineWidth',2)
        hold on;
        legend_entries(i_ind) = sprintf("aLIFP %d \\mus", ipgs(i_ind));
    end

    legend_entries(end + 1:end + 3) = ["Miller et al. 2008", "Hartmann and Klinke (1990)", "Dynes and Delgutte (1992)"];

    errorbar([250, 1000, 5000], temporal_coding_data.Miller.avg, temporal_coding_data.Miller.std, 'xk', 'Markersize', 8, 'Linewidth', 1);

    p = temporal_coding_data.HartmannKlinke.cis(:,1) - temporal_coding_data.HartmannKlinke.averages;
    n = temporal_coding_data.HartmannKlinke.averages - temporal_coding_data.HartmannKlinke.cis(:,2);
    errorbar(temporal_coding_data.HartmannKlinke.frqs, temporal_coding_data.HartmannKlinke.averages, ...
                    p, n, 'o', 'color', [0.1758    0.4922    0.1797], 'Markersize', 8, 'Linewidth', 1);

    p = temporal_coding_data.DynesDelgutte.cis(:,1) - temporal_coding_data.DynesDelgutte.averages;
    n = temporal_coding_data.DynesDelgutte.averages - temporal_coding_data.DynesDelgutte.cis(:,2);
    errorbar(temporal_coding_data.DynesDelgutte.frq, temporal_coding_data.DynesDelgutte.averages, ...
                    p, n, 'd', 'color', [0.4922 0.1758 0.4883], 'Markersize', 8, 'Linewidth',1);

    xticks([50, 100, 500, 1000, 5000]);
    xlabel("Pulse rate (pps)");
    ylabel("Vector Strength");
    legend(legend_entries, "location", "southwest");
    grid on;
    ylim([0, 1.1]);


end


%% Figure 12: Hu et al. (2010), spike rate and vector strength for amplitude modulated stimuli
if flags.do_fig12
    data = amt_load('felsheim2024', 'Hu_etal_2010_fig56.mat');
    spike_rate_data = data.spike_rate_data;
    vector_strength_data = data.vector_strength_data;

    pulse = [0;-1 * ones(40,1); ones(40,1);0];

    t = (1:ceil(0.4 * 1e6))' / 1e6;
    modulation = (1 + 0.1 * sin(2 * pi * 100 * t ));

    % amplitudes were found to match the mean spike rates in the rate groups:
    % R1-80, R2-200, R3-350, R4-500];
    amplitudes_modulated = [1.35, 1.6, 1.88 , 2.24] * 1e-3; 
    amplitudes_unmodulated = [1.43, 1.54, 1.72 , 1.95] * 1e-3;

    fig = figure("Name", "Figure12","DefaultAxesFontSize", 13);
    fig.Position = [0 0 800, 900];
    ax=subplot(4,2,1); %ax = tiledlayout(4,2, "tilespacing", "tight", "padding", "tight"); % use this when on Matlab 2019b or later

    time_steps = 0:0.05:0.4;
    num_time_steps = length(time_steps) - 1;
    x_values = time_steps(1:end - 1) + diff(time_steps)/2;

    vector_strength = zeros([2, num_time_steps,length(amplitudes_modulated)]) ;
    spike_rate = vector_strength;


    data = amt_cache('get', 'data_fig12', flags.cachemode);

    if isempty(data)
        for modulated = [true, false]

            if modulated
                stimulus = [sig_pulsetrain(0.4, 5000, pulse, 1e6, modulation); zeros(100,1)];
                amplitudes = amplitudes_modulated;
                text = "Modulated";
                m_ind = 1;
            else
                stimulus = [sig_pulsetrain(0.4, 5000, pulse); zeros(100, 1)];
                amplitudes = amplitudes_unmodulated;
                text = "Unmodulated";
                m_ind = 2;
            end

            % compute the model response and obtain the vector strength and mean spike rate
            amt_disp(''); % start of volatile display
            parfor a_ind = 1:length(amplitudes)
                amt_disp(['Calculating for ' text ' amplitude #' num2str(a_ind) ...
                          ' of ' num2str(length(amplitudes)) '...'],'volatile');

                [out_struct] = felsheim2024(stimulus * amplitudes(a_ind));

                dist = felsheim2024_spikeprobability(out_struct, 0.41);

                for t_ind = 1:(num_time_steps)
                    curr_dist = dist(round(time_steps(t_ind) * 1e6) + 1:round(time_steps(t_ind + 1) * 1e6));
                    spike_rate(m_ind, t_ind, a_ind) = sum(curr_dist) / 0.05;

                    if modulated
                        vs = local_vectorstrength(curr_dist, 100);
                    else
                        vs = local_vectorstrength(curr_dist, 5000);
                    end
                    vector_strength(m_ind, t_ind, a_ind) = vs;

                end
            end
			amt_disp(); %end of volatile display
        end
        data.vector_strength = vector_strength;
        data.spike_rate = spike_rate;
        amt_cache('set', 'data_fig12', data);

    else
        vector_strength = data.vector_strength;
        spike_rate = data.spike_rate;
    end


    for modulated = [true, false]
        if modulated
            off = 0;
            color = [0 0.4470 0.7410];
            m_ind = 1;
        else
            off = 1;
            color = [0.8500 0.3250 0.0980];
            m_ind = 2;
        end


        for a_ind = 1:length(amplitudes_unmodulated)
            subplot(4,2,a_ind*2-1); %nexttile(a_ind * 2 - 1) % use this when on Matlab 2019b or later
            plot(spike_rate_data(:,1), spike_rate_data(:,a_ind * 2 + off), "x", "MarkerSize", 8, "LineWidth", 2, "color", color);
            hold on
            plot(x_values * 1e3, spike_rate(m_ind,:,a_ind), "-o", "LineWidth", 2, "color", color);
            ylabel("Spike rate (spike/s)")
            xlabel("Time (ms)")
            title(sprintf("Spike rate, R%d", a_ind))
            m = max([spike_rate(:, a_ind); spike_rate_data(:,a_ind * 2 + off)], [],'all');
            ylim([0,ceil(m/100)*100]);
            grid on;

            ax=subplot(4,2,a_ind*2); %ax = nexttile(a_ind * 2); % use this when on Matlab 2019b or later
            plot(vector_strength_data(:,1), vector_strength_data(:, a_ind * 2 + off), "x", "MarkerSize", 8, "LineWidth", 2, "color", color);
            hold on
            plot(x_values * 1e3, vector_strength(m_ind,:, a_ind), "-o", "LineWidth", 2, "color", color)
            ylabel("Vector Strength")
            xlabel("Time (ms)")
            title(sprintf("Vector Strength, R%d", a_ind))
            ylim([0,1]);
            grid on;

        end
    end


    leg = legend(ax, "Data modulated", "aLIFP modulated", "Data unmodulated", "aLIFP unmodulated", "orientation", "horizontal");
    %leg.Layout.Tile = 'north'; % use this when on Matlab 2019b or later

end

%% Figure A.1: vector strength for different inter-phase gap (IPG) values
if flags.do_figA1


    pulse_rates = [2500, 5000];
    amplitudes_dB = [1, 2];

    duration = 0.3; % in seconds


    num_amplitudes = length(amplitudes_dB); % needed for the parfor loop

    vector_strength = amt_cache('get', 'data_figA1', flags.cachemode);

    if isempty(vector_strength)
        vector_strength = nan(2, length(amplitudes_dB), 7, 1);   

        for p_ind = 1:length(pulse_rates)
            if pulse_rates(p_ind) == 5000
                ipg = [0, 10, 20, 30, 40, 50];
            else
                ipg = [0, 10, 20, 30, 40, 50, 100];
            end
            parfor ipg_ind = 1:length(ipg)
                pulse = [-1 * ones(40,1); zeros(ipg(ipg_ind),1); ones(40,1)];
                aLIFP_I50 = local_getthreshold(pulse, (0.4:0.05:3)*1e-3, 0.5); 
                pulse_train = sig_pulsetrain(duration, pulse_rates(p_ind), pulse);

                for a_ind = 1:num_amplitudes
                    curr_amplitude = aLIFP_I50 * 10.^(amplitudes_dB(a_ind)/20);
                    out_struct = felsheim2024(pulse_train * curr_amplitude);

                    dist = felsheim2024_spikeprobability(out_struct, duration);
                    vector_strength(p_ind, a_ind, ipg_ind) = local_vectorstrength(dist, pulse_rates(p_ind));
                end
            end
        end

        amt_cache('set', 'data_figA1', vector_strength);

    end

    fig = figure("Name", "Figure A.1", "DefaultAxesFontSize", 13);
    fig.Position = [0 0 1100, 550];
    subplot(1,2,1); %tiledlayout(1,2); % use this when on Matlab 2019b or later

    %nexttile % use this when on Matlab 2019b or later
    hold on;

    alpha = [1, 0.6, 0.4, 0.2];
    markers = ["o-", "--d", "-.x", ":s"];

    ipg = [0, 10, 20, 30, 40, 50, 100];

    labels = strings(length(amplitudes_dB),1);

    for a_ind = 1:length(amplitudes_dB)
        plot(ipg, squeeze(vector_strength(1, a_ind,:)), [markers(a_ind)], "LineWidth", 2, "color", [0, 0.4471, 0.7412, alpha(a_ind)])
        labels(a_ind) = sprintf("aLIFP %g dB re I_{50}", amplitudes_dB(a_ind));
    end
    title("2500 pps")
    ylabel("Vector Strength")
    xlabel("IPG (\mus)")
    ylim([0,1])
    grid on

    ax=subplot(1,2,2); %ax = nexttile; % use this when on Matlab 2019b or later
    hold on;

    for a_ind = 1:length(amplitudes_dB)
        plot(ipg, squeeze(vector_strength(2, a_ind,:)), [markers(a_ind)], "LineWidth", 2, "color", [0, 0.4471, 0.7412, alpha(a_ind)])
    end
    title("5000 pps")


    leg = legend(ax, labels, 'orientation', 'horizontal', "Location", "northoutside");
    leg.Layout.Tile = 'north';
    ylabel("Vector Strength")
    xlabel("IPG (\mus)")
    ylim([0,1])
    grid on

end



function [vs] = local_vectorstrength(distribution, pulse_rate)

    
    T = 1/pulse_rate * 1e6;

    sample_step = 1;

    time_points = 1:sample_step:length(distribution);
    probabilities = distribution(time_points);
    theta = 2 * pi * mod(time_points, T) / T;

    x = cos(theta) .* probabilities;
    y = sin(theta) .* probabilities;

    vs = sqrt( sum(x).^2 + sum(y).^2) / sum(probabilities);


function [threshold] = local_getthreshold(signal, amplitudes, target_probability)

    last_probability = nan;
    probabilities = nan(size(amplitudes));
    threshold = nan;
    for a_ind = 1:length(amplitudes)
        [out_dist] = felsheim2024(signal * amplitudes(a_ind));
        curr_probability = sum([out_dist.total_probability]); % changed from mean
        if  curr_probability >= target_probability 
            if a_ind == 1
                error("Too low amplitudes were given. Please start with a lower values.")
            end
            m = (amplitudes(a_ind) - amplitudes(a_ind - 1)) / (curr_probability - last_probability);
            threshold = m * (target_probability - last_probability) + amplitudes(a_ind - 1);
            break;
        end
        
        last_probability = curr_probability;
        probabilities(a_ind) = curr_probability;
        if curr_probability >= 1
            break;
        end
    end


    
function [mean_out, std_out] = local_fitgaussian(amplitude, probabilities)

    fit_function= @(params, data) normcdf(data, params(1), params(2));

    probabilities = probabilities(~isnan(amplitude));
    amplitude = amplitude(~isnan(amplitude));
    options = optimset("Display", "off");
    [out] = lsqcurvefit(fit_function, [median(amplitude), std(amplitude)], amplitude, probabilities, [], [], options);
    mean_out = out(1);
    std_out = out(2);


     

