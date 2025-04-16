function dists = felsheim2024(stim, fs, varargin)
%felsheim2024 Adaptive leaky-integrate and firing probability (aLIFP) model of an electrically stimulated nerve fiber
%
%   Usage: dists = felsheim2024(stim);
%          dists = felsheim2024(stim, fs);
%          dists = felsheim2024(stim, fs, varargin);
%
%   Input parameters:
%
%     stim:   Time signal describing the pulsatile electric stimulation of a nerve fiber. 
%             The pulses must be biphasic. The two phases may have varying durations and 
%             and they may be separated by an interphase gap (IPG). The pulse may have 
%             varying amplitudes (in mA). In the current
%             implementation only cathodic (negative) pulses are causing excitation in the model.
%
%     fs:     Optional sampling frequency of the time signal (in Hz). Default: 1 MHz.
%
%     vargin: Optional parameters as key-value pairs, see below.
%
%
%   Output parameters:
%
%     dists: Structure array containing the spike distribution in response to each
%            biphasic pulse in stim. Per negative phase in stim, spike_distributions 
%            containes  a separate entry describing the probabilitiy following a Gaussian 
%            mixture  distribution and containing the following fields:
%
%            - total_probability*: Total probability of spiking in response to
%              the pulse.
%
%            - mu*: Mean values of the Gaussian mixture. 
%
%            - sigma*: Standard deviations of the Gaussian mixture.
%
%            - weights*: Weights of each component of the Gaussian mixture. 
%
%
%   FELSHEIM2024(..) implements the adaptive leaky-integrate and fire (aLIFP) model, which 
%   simulates the electrical stimulation of a nerve fiber. Instead of predicting (stochastic) time
%   points of spikes, the aLIFP model calculates the spike distribution in respone
%   to each biphasic pulse in stim. The model incorporates latency and jitter of the nerve response
%   and accounts for the facilitation, the refactory period and adaptation. The development of this model 
%   was inspired by the spiking model of Takanen and Seeber (2022).
%
%   The model parameters can be changed using the following key-value pairs:
% 
%     'leaky_integrator_tau',tau         Time constant (in s) of the leaky integrator. 
%                                        Default: 1.2 µs.          
% 
%     'membrane_resistance',mr           Membrane resistance (in Ohm). Default: 28.986 Ohm.
% 
%     'threshold_mu',mu                  Mean threshold (in V) at the model start. Default: 10 mV.
% 
%     'threshold_sigma',sigma            Standard deviation threshold (in V) at the model start.
%                                        Default: 431.9 µV.
% 
%     'varphi',phi                       Action potential initiation period (in s). It 
%                                        determines the duration during which a spike can be 
%                                        inhibited by further stimulation. Default: 20.5 µs.
% 
%     'jitter_coeffs',jitter             Vector of three parameters describing the  
%                                        dependency of the jitter on the membrane potential. 
%                                        Default: [5.449e-4, 3.159e-4, 1.30e-04].
% 
%     'latency_coeffs',latency           Vector of four parameters describing the  
%                                        dependency of the spike latency on the membrane potential. 
%                                        Default: [1.096e-4, 5.478e-04, 3.93e-04, 4.23e-04].
% 
%     'refractoriness_p',p               Parameter of the function describing the increase of the
%                                        threshold due to the refractory period. Default: 0.377.
% 
%     'refractoriness_q',q               Parameter of the function describing the increase of the
%                                        threshold due to the refractory period. Default: 0.102.
%  
%     'refractoriness_trrp',trrp         Time constant (in s) of the relative refractory period.
%                                        Default: 2.56 ms.
% 
%     'refractoriness_tarp',tarp         Duration (in s) of the absolute refractory period. 
%                                        Default: 0.37 ms.
% 
%     'adaptation_tau',a_tau             Time constant (in s) of the adaptation function. 
%                                        Default: 0.27 s.
% 
%     'adaptation_c',c                   Multiplicative increase of the threshold due to   
%                                        adaptation after a spike. Default: 0.102. 
%
%     'max_adapt',max_adapt              Maximum overall adapation. Default: 1.7.
% 
%     'facilitation_coeffs',f_coeffs     Vector of five coefficients describing the facilitation curve. 
%                                        Default: [0.1e-3, -1.4e-3, 0.45 , 900, 0.5].
%  
%     'max_threshold_components',max_c   Maximum number of components in the Gaussian mixtures.
%                                        Default: 20.
% 
%     'path_deletion_mean_eps',mean_eps  Factor applied to threshold_mu defining the numeric border 
%                                        for the test of equality of the threshold 
%                                        mean of two components. Default: 0.001.
% 
%     'path_deletion_std_eps',std_eps    Factor applied to threshold_sigma defining the numeric border 
%                                        for the test of equality of the threshold
%                                        standard deviation of two components. Default: 0.001.
% 
%     'min_spike_probability',min_prob   Minimum spike probability required to add a new
%                                        component in the threshold mixture. Default: 0.001.
% 
%     'lower_limit_std_b',std_limit      Limit of the standard deviation (relative to the
%                                        threshold) required to avoid high spike probabilities without
%                                        stimulation. Default: 1/3.
% 
% 
%   See also: exp_felsheim2024 demo_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%     M. Takanen and B. U. Seeber. A phenomenological model reproducing
%     temporal response characteristics of an electrically stimulated
%     auditory nerve fiber. Trends in Hearing, 26:23312165221117079, 2022.
%     PMID: 36071660.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/felsheim2024.php


%   #Requirements: M-Stats
%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Verified
%   #Author: Rebecca C. Felsheim (2024): Original implementation. 
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.
%   #Author: Michael Mihocic (2024): Adaptations for Octave.


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


if nargin < 2
    fs = 1e6;
end

definput.import = {'felsheim2024'};
[~, parameters] = ltfatarghelper({}, definput, varargin);

if any(strcmp(varargin, 'threshold_mu')) && ~any(strcmp(varargin, 'path_deletion_mean_eps'))
    parameters.path_deletion_mean_eps = parameters.threshold_mu * 1e-3;
end

if any(strcmp(varargin, 'threshold_sigma')) && ~any(strcmp(varargin, 'path_deletion_std_eps'))
    parameters.path_deletion_std_eps = parameters.threshold_sigma * 1e-3;
end

parameters.fs = fs;


%% leaky integrator the same as in Takanen and Seeber (2022), but for extracellular current
leaky_integrator_b = [(exp(-1/(parameters.leaky_integrator_tau*parameters.fs)) - 1)/2 ...
                      (exp(-1/(parameters.leaky_integrator_tau*parameters.fs)) - 1)/2];
leaky_integrator_a = [1 -exp(-1/(parameters.leaky_integrator_tau*parameters.fs))];
start_potential = parameters.membrane_resistance * filter(leaky_integrator_b, leaky_integrator_a, stim);


%% find the onsets and offsets of the first positive phase of all pulses 
  % t_start, t_stop in the formulas
  % these will be used to process the pulses one after another
  % model can currently only be exited by a cathodic (negative) phase

  % onsetsOLD = strfind(stim' < 0,[0 1]); % not working in Octave
onsets = find(diff(stim' < 0) == 1);

if stim(1) < 0
    onsets = [1, onsets];
end

 % offsets_first_phaseOLD = strfind(stim' < 0, [1, 0]);  % not working in Octave
offsets_first_phase = find(diff(stim' < 0) == -1);

if length(offsets_first_phase) ~= length(onsets)
    offsets_first_phase = [offsets_first_phase; length(start_potential)];
end

  % if no pulse is given nothing can be done
if isempty(onsets)
    dists.total_probability = 0;
    dists.weigthts = nan;
    dists.mu = nan;
    dists.sigma = nan;
    return;
end

%% set the default values for our working variables and preallocate space to reduce runtime
threshold_mean = nan(length(stim), 2 * parameters.max_threshold_components);
threshold_std = nan(length(stim), 2 * parameters.max_threshold_components);
threshold_probabilities = nan(1, 2 * parameters.max_threshold_components);
adaptation_increments = nan(length(stim), 2 * parameters.max_threshold_components);
membrane_potential = nan(length(stim), 2 * parameters.max_threshold_components);


threshold_mean(:,1) = ones(size(stim)) * parameters.threshold_mu;
threshold_std(:,1) = ones(size(stim)) * parameters.threshold_sigma;
threshold_probabilities(1) = 1;
adaptation_increments(:,1) = zeros(size(stim));
membrane_potential(:,1) = start_potential;

unused_threshold_indices = 2:(2*parameters.max_threshold_components);
used_threshold_indicies = 1;

dists(length(onsets)) = struct;

%% compute the interaction values
  % the changes due to facilitation, accommodation, refractory period and adaptation always remain
  % the same and are therefore only computed once
max_length = length(stim);

t_in_s = (1:max_length)'./parameters.fs;

  % adaptation, Eq. 34, originally from Takanen & Seeber (2022)
max_incr = parameters.adaptation_c; % maximum of exponential decay
pulse_interaction.adaptation_increment = max_incr*exp(-t_in_s./parameters.adaptation_tau) + 1; 

  % refractory time, Eq. 31, originally from Takanen & Seeber (2022)
tARP = parameters.refractoriness_tarp;
tRRP = parameters.refractoriness_trrp;
pulse_interaction.refractoriness_coeffs = ((1-exp(-(t_in_s-tARP)./(parameters.refractoriness_q*tRRP))).*(1-parameters.refractoriness_p*...
   exp(-(t_in_s-tARP)./tRRP))).^-1;
pulse_interaction.refractoriness_coeffs(t_in_s<= tARP) = Inf;

  % facilitation, Eq. 28
off1 = parameters.facilitation_coeffs(1);
off2 = parameters.facilitation_coeffs(2);
a1 = parameters.facilitation_coeffs(3);
a2 = parameters.facilitation_coeffs(4);
f1 = 1 -  exp(- a2 * (t_in_s + off1));
f2 = a1* exp(-a2 * (t_in_s + off2)) + 1;
pulse_interaction.facilitation_values = f1 .* f2;

%% main loop - iterate over all pulses and obtain the spike probabilities
for ind = 1:length(onsets) 
    curr_onset = onsets(ind);
    curr_offset = offsets_first_phase(ind);
    if ind < length(onsets)
        next_onset = onsets(ind + 1);
    else
        next_onset = length(stim);
    end

      % Membrane potential for the next pulse, if a spike was evoked. Computed here as it only
      % needs to be done once per pulse, not for each component separately
    new_potential = parameters.membrane_resistance * filter(leaky_integrator_b, leaky_integrator_a, stim(next_onset:end));

    %% check if the threshold components have converged to the same mean and std and merge them if possible
      % remove components if we have too many
    if length(used_threshold_indicies) > 1

        remove_inds = [];
        used_threshold_indicies = sort(used_threshold_indicies);

          % check if any two threshold distributions are the same
        for d1 = used_threshold_indicies
            for d2 = used_threshold_indicies(used_threshold_indicies > d1)
                if mean(abs(threshold_mean(curr_onset:curr_offset, d1) - threshold_mean(curr_onset:curr_offset, d2))) ...
                                    < parameters.path_deletion_mean_eps && ...
                        mean(abs(threshold_std(curr_onset:curr_offset, d1) - threshold_std(curr_onset:curr_offset, d2))) ...
                                    < parameters.path_deletion_std_eps && ...
                        mean(abs(membrane_potential(curr_onset:curr_offset, d1) - membrane_potential(curr_onset:curr_offset, d2))) ...
                                    < parameters.path_deletion_mean_eps
                    remove_inds(end + 1) = d1;
                    threshold_probabilities(d2) = threshold_probabilities(d1) + ...
                                                             threshold_probabilities(d2);
                    used_threshold_indicies(used_threshold_indicies == d1) = [];
                    threshold_mean(:,d2) = mean([threshold_mean(:,d1), threshold_mean(:,d2)],2);
                    threshold_std(:,d2) = mean([threshold_std(:,d1), threshold_std(:,d2)],2);
                    membrane_potential(:, d2) = mean([membrane_potential(:,d1), membrane_potential(:,d2)],2);
                    adaptation_increments(:,d2) = mean([adaptation_increments(:,d1), adaptation_increments(:,d2)],2);
                    break;
                end
            end
        end

        threshold_probabilities(remove_inds) = nan;
        unused_threshold_indices = [unused_threshold_indices, remove_inds];



          % remove components with the lowest probability, if we have too many
        if length(used_threshold_indicies) > parameters.max_threshold_components
            [~, remove_inds] = sort(threshold_probabilities);
            remove_inds = remove_inds(1: length(used_threshold_indicies) - parameters.max_threshold_components);
            threshold_probabilities(:, remove_inds) = nan;
            unused_threshold_indices(end + 1: end + length(remove_inds)) = remove_inds;
            for ri = remove_inds
                used_threshold_indicies(used_threshold_indicies == ri) = [];
            end
        end

        % threshold_probabilitiesOLD = threshold_probabilities / sum(threshold_probabilities, 'omitnan'); % not working in Octave
        threshold_probabilities = threshold_probabilities / sum(threshold_probabilities(~isnan(threshold_probabilities)));

    end


    %% initialize the current distribution
    dists(ind).total_probability = 0;
    dists(ind).mu = zeros(length(used_threshold_indicies),1);
    dists(ind).sigma = zeros(length(used_threshold_indicies),1);
    dists(ind).weights = zeros(length(used_threshold_indicies),1);


    %% iterate over each threshold component to obtain the spike time distributions
    for path_ind = 1:length(used_threshold_indicies)
        dist_ind = used_threshold_indicies(path_ind);

          % calculate the threshold offset due to spike cancellation (Eq. 6, 8, 9)
        [max_voltage, max_voltage_point] = max(membrane_potential(curr_onset:curr_offset, dist_ind));


        ipg = find(stim(curr_offset:next_onset) > 0, 1);
        if ~isempty(ipg)
            amplitude_ratio = abs(stim(curr_onset + 1) / stim(curr_offset + ipg + 1));
            latest_threshold_crossing = max_voltage_point - max(0, (parameters.varphi * parameters.fs - ipg) / (1 + amplitude_ratio));
            latest_threshold_crossing = max(1, round(latest_threshold_crossing));
            cancelation_offset = max_voltage - membrane_potential(curr_onset + latest_threshold_crossing - 1, dist_ind);
        else
              % monophasic case
            cancelation_offset = 0;
        end


          % get the spiking probability (taking the cancelation offset into account) (Eq. 14)
        curr_probability = max(normcdf(membrane_potential(curr_onset:curr_offset, dist_ind), ...
                                  threshold_mean(curr_onset:curr_offset,dist_ind) + cancelation_offset, ...
                                  threshold_std(curr_onset:curr_offset,dist_ind)));

        if isnan(curr_probability)
            curr_probability = 0;
        end
        curr_not_probability = (1- curr_probability);


        dists(ind).total_probability = dists(ind).total_probability + ...
                                                            curr_probability * threshold_probabilities(dist_ind);
        dists(ind).weights(path_ind) = curr_probability * threshold_probabilities(dist_ind);

          % compute the spike time (no cancelation offset required) (Eq. 20)
        time_cdf = normcdf(membrane_potential(curr_onset:curr_offset, dist_ind), ...
                           threshold_mean(curr_onset:curr_offset,dist_ind), ...
                           threshold_std(curr_onset:curr_offset,dist_ind));
        max_time_cdf = max(time_cdf);
        [~, mean_thr_crossing] = min(abs(time_cdf - max_time_cdf * 0.5));
        [~, lower_std] = min(abs(time_cdf - 0.159 * max_time_cdf));
        [~, upper_std] = min(abs(time_cdf - 0.841 * max_time_cdf));
        crossing_std_in_s = 0.5 * (upper_std - lower_std) / parameters.fs;

        mean_thr_crossing = mean_thr_crossing + curr_onset - 1;

        above_threshold = max_voltage - (threshold_mean(mean_thr_crossing, dist_ind) + cancelation_offset);

        latency_in_s = parameters.latency_coeffs(3)./(1+exp(parameters.latency_coeffs(2)^-1*...
                        (above_threshold-parameters.latency_coeffs(1))))+parameters.latency_coeffs(4);

        jitter_in_s = parameters.jitter_coeffs(3)./(1+exp(parameters.jitter_coeffs(2)^-1* ...
                        (above_threshold-parameters.jitter_coeffs(1))));

          % Eq. 21
        dists(ind).mu(path_ind) = mean_thr_crossing/parameters.fs + latency_in_s;
        dists(ind).sigma(path_ind) = sqrt(crossing_std_in_s^2 + jitter_in_s.^2);


        %% get the new threshold values considering spike interaction phenomena
        max_time = length(threshold_mean(:, dist_ind)) - mean_thr_crossing + 1;
        refraction_coeffs = pulse_interaction.refractoriness_coeffs(1:max_time);

          % Eq. 32, 33
        refractoriness_mean = threshold_mean(mean_thr_crossing:end, dist_ind) .* refraction_coeffs;
        refractoriness_std = threshold_std(mean_thr_crossing:end, dist_ind) .* refraction_coeffs;

          % Calculate the adaptation on the threshold 
        max_length = length(refractoriness_mean);

        adaptation_increment = pulse_interaction.adaptation_increment(1:max_length);
        
        % calculate ratio between maximum of adaptation_increment and specified
        % maximum adaptation effect
        curr_increment = adaptation_increments(mean_thr_crossing:end,dist_ind);
        total_thr_increment = curr_increment .* adaptation_increment;
        inds_larger = total_thr_increment > parameters.max_adapt;
        
         
        % if adaptation_increment exceeds allowed maximum, adapt function to exactly
        % reach the specified maximum adaptation effect
        if any(inds_larger)
            adaptation_increment(inds_larger) = parameters.max_adapt ./ curr_increment(inds_larger);
            total_thr_increment = curr_increment .* adaptation_increment;
        end
        curr_increment = total_thr_increment;
       
        % increase threshold by increment, Eq. 35, 36
        adaptation_mean = refractoriness_mean .* adaptation_increment;
        adaptation_std = refractoriness_std .* adaptation_increment;

          % to reduce the probability of a spike being evoked without any stimulation 
        adaptation_std = min(adaptation_std, adaptation_mean * parameters.lower_limit_std_b ); 


        max_time = length(threshold_mean(:, dist_ind)) - curr_offset + 1;
        facilitation_values = pulse_interaction.facilitation_values(1:max_time);

          % Eq. 29
        facilitation_mean = threshold_mean(curr_offset:end, dist_ind) .* facilitation_values;
        facilitation_mean = max(facilitation_mean, parameters.facilitation_coeffs(5) * parameters.threshold_mu);

          % Eq. 30
        facilitation_std = threshold_std(curr_offset:end, dist_ind) .* facilitation_values;
        facilitation_std = max(facilitation_std, parameters.facilitation_coeffs(5) * parameters.threshold_sigma);


          % save the new threshold values for the next pulse
        if curr_probability < parameters.min_spike_probability 
              % no spike was evoked
            threshold_mean(curr_offset:end,dist_ind) = facilitation_mean;
            threshold_std(curr_offset:end, dist_ind) = facilitation_std;
        elseif curr_not_probability < parameters.min_spike_probability 
              % spike was evoked almost certainly 
            threshold_mean(mean_thr_crossing:end,dist_ind) = adaptation_mean;
            threshold_std(mean_thr_crossing:end,dist_ind) = adaptation_std;
            adaptation_increments(mean_thr_crossing:end, dist_ind) = curr_increment;
            membrane_potential(next_onset:end, dist_ind) = new_potential;
        else
            next_index = unused_threshold_indices(1);
            unused_threshold_indices = unused_threshold_indices(2:end);
            used_threshold_indicies(end + 1) = next_index;

            threshold_mean(mean_thr_crossing:end,next_index) = adaptation_mean;
            threshold_std(mean_thr_crossing:end,next_index) = adaptation_std;
            % Eq. 25
            threshold_probabilities(next_index) = curr_probability * threshold_probabilities(dist_ind);
            adaptation_increments(mean_thr_crossing:end, next_index) = curr_increment;
            membrane_potential(next_onset:end, next_index) = new_potential;

            threshold_mean(curr_offset:end,dist_ind) = facilitation_mean;
            threshold_std(curr_offset:end, dist_ind) = facilitation_std;
            % Eq. 26
            threshold_probabilities(dist_ind) = curr_not_probability * threshold_probabilities(dist_ind); 


        end

    end
      % make sure the distribition weights sum up to 1
    if dists(ind).total_probability ~= 0
        dists(ind).weights = dists(ind).weights ./ ...
                                                dists(ind).total_probability;
    else
        dists(ind).weights = zeros(size(dists(ind).weights));
        dists(ind).weights(1) = 1;
    end
      % should not be necessary, but to avoid any numerical inaccuracies
    threshold_probabilities = threshold_probabilities / sum(threshold_probabilities(used_threshold_indicies));

end




