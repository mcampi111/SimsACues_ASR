function [parameters, metrics] = frambi_estimate(data, agent, environment, options)
%frambi_estimate Estimate parameters of an auditory model
%   Usage: [parameters, metrics] = frambi_estimate(data, agent, environment, options);
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
%     agent      : Structure representing the FrAMBI agent. See the general description of 
%                  FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     environment: Structure representing the FrAMBI environment. See the general description 
%                  of FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     options    : Structure representing the FrAMBI options. It needs to contain
%                  the structure estimate to control the estimation of parameters, 
%                  with the following fields:
%
%                  - optimizer*: Name of the optimizer. Currently, it must be 'bads'. 
%
%                  - parameters*: Structure containing the parameters of the optimizer. 
% 
%                  - disp*: Flag controlling the display of the estimated parameters. 
%                    If true, estimated parameters and the statistic metrics will be
%                    displayed. 
%
%   Output parameters:
%     parameters : Structure with the estimated parameters and their names:
% 
%                  - values*: Matrix with the estimated parameter values.
% 
%                  - names*: Cell array with the parameter names. The names are 
%                    those from agent.state.parameters with the field
%                    fit set to true. 
%
%     metrics    : Structure with the statistics of the estimation:
% 
%                  - loglik*: Log-likelihood of the estimation.
% 
%                  - BIC*: Bayesian information criterion of the estimation.
%
%
%   FRAMBI_ESTIMATE(..) estimates agent's parameters by running an optimizer which estimates
%   optimal agent's parameters for the provided experiment data by maximizing the likelihood 
%   of the experiment data given the model specified by the agent and environment 
%   under the constraints set by the options. The function validates input structures,
%   prepares the log-likelihood function, executes the optimization, and reports results along with
%   boundary checks if required.
%
%   The calculation of the likelihood is handled by FRAMBI_LIKELIHOOD.
%
%   The optimizer is defined in options.estimate.optimizer. Currently only the 
%   Bayesian Adaptive Direct Search (BADS, Acerbi et al., 2017) is implemented. 
%   BADS is used for optimization, handling the constraints and transformations as 
%   defined in the agent's parameters. 
%
%
%   See also: frambi_likelihood frambi_simulate frambi_parameters exp_barumerli2024
%
%   References:
%     L. Acerbi and W. J. Ma. Practical bayesian optimization for model
%     fitting with bayesian adaptive direct search. In I. Guyon, U. V.
%     Luxburg, S. Bengio, H. Wallach, R. Fergus, S. Vishwanathan, and
%     R. Garnett, editors, Advances in Neural Information Processing Systems,
%     volume 30, pages 1834--1844. Curran Associates, Inc., 2017.
%     
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_estimate.php


%   #Requirements: MATLAB M-Signal BADS
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

% 2022-12-23 first upload
% 2023-11-06 customized for AMT


    % validate input parameters
    assert(isfield(data, 'variables'))
    assert(isfield(data, 'variablenames'))
    assert(isfield(data, 'responses'))

    num_trials = size(data.variables, 1);

    assert(num_trials > 0)
    assert(num_trials == size(data.responses, 1), 'data.variables must the same rows of data.responses')
    assert(size(data.variables, 2) == length(data.variablenames))
    assert(~isempty(agent))
    assert(~isempty(environment))

    % validate the structures
    options = frambi_validate(options);
    agent = frambi_validate(agent);
    environment = frambi_validate(environment);

    % disable validation to speed up computation
    options.validation = false;

    % create log-likelihood function
    negloglikelihood_fun = @(parameters) -frambi_likelihood(data, parameters, agent, environment, options);

    % get free parameters
    parameter_names = fieldnames(agent.state.parameters);
    free_params = logical(structfun(@(p) p.fit, agent.state.parameters)); 
    num_free_params = sum(free_params);
    parameter_names(~free_params) = [];

    % transform bounds for optimization
    bounds_transformed = zeros(num_free_params, 4);
    for p = 1:num_free_params
        bounds = agent.state.parameters.(parameter_names{p}).bounds;
        assert(length(bounds) == 4); 
        bounds_transformed(p,:) = frambi_parameters('transform', agent.state.parameters, parameter_names(p), bounds);
    end

    LB = bounds_transformed(:,1)';
    PLB = bounds_transformed(:,2)';
    PUB = bounds_transformed(:,3)';
    UB = bounds_transformed(:,4)';

    pars_init = frambi_parameters('get', agent.state.parameters);
    pars_tr = frambi_parameters('transform', agent.state.parameters, parameter_names, pars_init(free_params));
    pars_tr = pars_tr(:)';
    
    % run optimizer
	switch options.estimate.optimizer
        case 'bads' % Default options for BADS
			[fitted_transformed_parameters, nll] = bads(negloglikelihood_fun,pars_tr,LB,UB,PLB,PUB,[], options.estimate.parameters);
		otherwise
		    error('Unknown optimizers'); 			
    end	

    % extract estimated parameters
    parameters_fitted = frambi_parameters('itransform', agent.state.parameters, parameter_names, fitted_transformed_parameters');
    
    % prepare output
    parameters.values = parameters_fitted;
    parameters.names = parameter_names;

    % statistics
    metrics.loglik = -nll;
    metrics.BIC = -2*(metrics.loglik)+log(num_trials).*num_free_params;

      % display estimated parameters?
    if options.estimate.disp
        frambi_parameters('isimplausible', agent.state.parameters, parameter_names, parameters_fitted);

        amt_disp('Estimated parameters:','documentation');
        for i = 1:size(parameter_names) 
               amt_disp(sprintf('  %s: %.3f', parameter_names{i},parameters_fitted(i)),'documentation');
        end
        amt_disp('Statistic metrics:','documentation');
        amt_disp(sprintf('  Log-likelihood: %.3f', metrics.loglik),'documentation');
        amt_disp(sprintf('  BIC: %.3f', metrics.BIC),'documentation');
    end
end


