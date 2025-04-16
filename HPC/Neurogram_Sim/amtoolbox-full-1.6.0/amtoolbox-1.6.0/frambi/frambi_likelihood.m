function loglik = frambi_likelihood(data, par, agent, environment, options)
%frambi_likelihood Log-likelihood of observed responses given the model parameters
%
%   Usage: loglik = frambi_likelihood(data, par, agent, environment, options)
%
%   Input parameters:
%     data       : Structure describing model variables and behavioral data:
% 
%                  - variables*: Matrix with independent variables (in columns) for each trial (in rows).
% 
%                  - variablenames*: Cell array with names of the variables.
% 
%                  - responses*: Matrix with behavioral responses (in columns) for each trial (in rows).
%                    The responses in each row must have been obtained in the experiment condition
%                    described by the same row in variables.
%
%     par        : Matrix with parameter values to be used by the agent. 
%                  This matrix is usually created by the optimizer.
%                  The values might be transformed according to agent.state.parameters.
%
%     agent      : Structure representing the FrAMBI agent. See the general description of 
%                  FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     environment: Structure representing the FrAMBI environment. See the general description 
%                  of FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     options    : Structure representing the FrAMBI options. It needs to contain
%                  the structure sample with the following fields:
%
%                  - iterations*: Number of simulations of the same trial 
%                    used to estimate the response distribution;
% 
%                  - bandwidth*: Bandwidth (in the same units as data.responses*) 
%                    of the distribution smoothing. If zero, smoothing is disabled. 
% 
%
%   Output parameters:
%     loglik  : Log-likelihood of the model given the data and parameters.
%
%
%   FRAMBI_LIKELIHOOD(..) calculates the log-likelihood of data given the parameter 
%   values par of the agent. It handles parameter transformations, assigns 
%   parameter values to the agent, and uses unique conditions to optimize computation. 
%   
%   If options.sample.bandwidth is larger than 0, a kernel-based method 
%   is used for the simulation, i.e., FRAMBI_SIMULATE is called 
%   options.sample.iterations times. 
%   If options.sample.bandwidth is not larger than 0, a direct sampling 
%   is done by performing simulations with FRAMBI_SAMPLE. 
%
%   FRAMBI_LIKELIHOOD(..) is usually called by the optimizer, which setup 
%   is done in FRAMBI_ESTIMATE. 
%
%   *Note:* In the current implementation, only scalar responses from FRAMBI_SIMULATE 
%   can be processed. 
%
%   See also: frambi_estimate frambi_simulate frambi_sample exp_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_likelihood.php


%   #Requirements: MATLAB M-Signal
%   #Author: Roberto Barumerli (2023): Original implementation. 
%   #Author: Roberto Barumerli (2024): Integration in the AMT.
%   #Author: Michael Mihocic (2024): Documentation fixed. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


% initialize some stuff
par = par(:);
iterations = options.sample.iterations;
sim_resp = zeros(iterations, 1);

% handle free parameters
parameter_names = fieldnames(agent.state.parameters);
free_params = structfun(@(p) p.fit, agent.state.parameters); 
parameter_names(~free_params) = [];
par = frambi_parameters('itransform', ...
                    agent.state.parameters, parameter_names, par);
agent.state.parameters = frambi_parameters('assign', ...
                    agent.state.parameters, parameter_names, par);

% initialize agent
agent.state = agent.model.initialize(agent.state);
options.initialization = false;
responses = data.responses;
assert(~isempty(responses), 'response column from data is empty')

% Optimize if a single variable: remove repetitions
if size(data.variables, 2) == 1
    % overwrite data.variables with only unique values 
    levels = data.variables;
    levels_u = unique(levels);
    data.variables = levels_u; 
end

N = size(data.variables, 1);
loglik_trial = zeros(N, 1);
for ii = 1:N
    % assign parameter values
    for jj = 1:length(data.variablenames)
        environment.state.parameters.(data.variablenames{jj}).value = data.variables(ii, jj); 
    end
    
    environment.state = environment.model.initialize(environment.state);
    
    if options.sample.bandwidth > 0 % Calculations with smoothing applied
        % simulate individual responses
        for m=1:iterations
            sim_resp(m,1) = frambi_simulate(agent, environment, options);
        end
        
        % select responses
        if size(data.variables, 2) == 1
            resps = responses(levels_u(ii, 1) == levels);
        else
            resps = responses(ii,1);
        end

        % compute likelihood with actual response 
        % (equivalent to filter the histogram with a gaussian kernel, but faster because not requiring histcounts)
        loglik_trial(ii, 1) = sum(log(mean(normpdf(resps', sim_resp, options.sample.bandwidth), 1)+eps));
        
        else % Calculations without smoothing
            % use sample to simulate response distribution
            [~, distribution, support] = frambi_sample(agent, environment, options);
            % select responses
            if size(data.variables, 2) == 1
                resps = responses(levels_u(ii, 1) == levels);
            else
                resps = responses(ii,1);
            end
            
            for r = 1:length(resps)
                [~, m] = min(abs(support-resps(r)));
                loglik_trial(ii, 1) = loglik_trial(ii, 1) + log(distribution(m)+eps);
            end
    end
end

loglik = sum(loglik_trial);
assert(~isnan(loglik));
