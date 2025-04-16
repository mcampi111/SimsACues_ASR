function [samples, distribution, support] = frambi_sample(agent, environment, options)
%frambi_sample Calculate response distribution
%   Usage: [samples, distribution, support] = frambi_sample(agent, environment, options)
%
%   Input parameters:
%     agent      : Structure representing the FrAMBI agent. See the general description of 
%                  FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     environment: Structure representing the FrAMBI environment. See the general description 
%                  of FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     options    : Structure representing the FrAMBI options, must contain the 
%                  following fields: 
%                  
%                  - initialization*: Flag, if true the states of the agent 
%                    and environment will be initialized by calling 
%                    the functions defined in agent.model.initialize and
%                    environment.model.initialize.
%
%                  - validation*: Flag, if true the states of the agent 
%                    and environment will be validated by calling 
%                    FRAMBI_VALIDATE.
%
%                  - sample*: Structure controlling the sampling with the following fields:
%                   
%                     - iterations*: Number of simulations of the same trial 
%                       used to estimate the response distribution;
% 
%                     - support*: Column vector defining the support of the responses, 
%                       i.e., the range of responses with a non-zero probability.
%                       In the same units as samples (returned by FRAMBI_SIMULATE). 
%                   
%                     - bandwidth*: Bandwidth (in the same units as samples*) 
%                       of the distribution smoothing. If zero, smoothing is disabled. 
%                           
%   Output parameters:
%     samples      : Column vector with responses as obtained from 
%                    FRAMBI_SIMULATE. The size is options.sample.iterations. 
%     distribution : Column vector describing the probability distribution function 
%                    (PDF) of the responses as a relative histogram over 
%                    the options.sample.support. 
%     support      : Vector with the responses (in the same units as samples*) 
%                    for which the PDF in distribution is provided.
%
%   FRAMBI_SAMPLE(..) simulates agent's responses options.sample.iterations 
%   times for the given environment. From the responses, a relative histogram
%   over the support specified in options.sample.support is calculated. 
%
%   If options.sample.bandwidth is larger than 0, distribution is smoothed 
%   using a Gaussian filter emulating a kernel density estimation.
%
%   *Note:* In the current implementation, only scalar responses from FRAMBI_SIMULATE 
%   can be processed. 
%
%   See also: frambi_simulate frambi_likelihood exp_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_sample.php


%   #Author: Roberto Barumerli (2023): Original implementation. 
%   #Author: Roberto Barumerli (2024): Integration in the AMT.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
    
    % initilize agent and environment structs
    if options.initialization
        agent.state = agent.model.initialize(agent.state);
        environment.state = environment.model.initialize(environment.state);
    end

    % validate agent and environment structs
    if options.validation
        agent.state = frambi_validate(agent.state);
        environment.state = frambi_validate(environment.state);
    end

    % simulate multiple times agent responses
    iterations = options.sample.iterations;
    samples = zeros(iterations, 1);
    
    options.validation = false;
    options.initialization = false;

    for r=1:iterations
        samples(r,1) = frambi_simulate(agent, environment, options);
    end

      % compute histogram and make it a pdf
    support = sort(options.sample.support);
    dt = min(diff(support)); %was: dt = diff(support(1:2));
    edges = [support; support(end) + dt];
    distribution = histcounts(samples, edges)';  
      % normalize
    distribution = distribution./(sum(distribution)+eps); % eps to avoid divisions by zero (might happen when all the samples are outside the support)

      % apply smoothing by Gaussian window
    if options.sample.bandwidth > 0
      A = 1/(sqrt(2*pi)*options.sample.bandwidth);   % height of Gaussian		
      h = dt*A*exp(-0.5*((support - mean(support)).^2)/(options.sample.bandwidth^2)); % IR for convolution
      h(h < dt*A*1e-6) = []; % remove everything below 1e-6
      distribution = conv(distribution,h,'same');		 
        % normalize
	    distribution = distribution./sum(distribution); 
    end
end

