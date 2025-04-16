function [response, varargout] = frambi_simulate(agent, environment, options) 
%frambi_simulate Simulate a single trial of interactions between agent and environment
%   Usage: [response, logs] = frambi_simulate(agent, environment, options)
%
%   Input parameters:
%     agent      : Structure representing the FrAMBI agent. See the general description of 
%                  FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     environment: Structure representing the FrAMBI environment. See the general description 
%                  of FrAMBI for more details. See EXP_BARUMERLI2024 for an example. 
%
%     options    : Structure representing the FrAMBI options. It needs to contain
%                  the structure sample with the following fields:
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
%                  - simulate*: Structure controlling the simulation with the
%                    field cycles_max describing the maximum number of 
%                    perception-action cycles in order to obtain a response
%                    of the single trial. 
% 
%   Output parameters:
%     response    : Response simulated by the agent. Depending on the 
%                   function defined in agent.model.respond, it can be a 
%                   scalar, vector, or matrix. 
%                   
%     logs  : Cell array documenting the internal states and decisions
%             in each cycle, useful for debugging and detailed analysis.
%             Each row of logs contains information about a single 
%             perception-action cycle with the following
%             fields: 
%
%             - agent*: Structure containing the state of the agent.
%
%             - environment*: Structure containing the state of the environment. 
%
%             The last row of logs contains the field response, which 
%             stores the response as returned by the function
%             agent.model.respond. 
%
%
%   FRAMBI_SIMULATE(..) simulates a single behavioral trial in an experiment
%   described as perception-action cycles. To this end, the interaction between 
%   the agent and the environment is simulated by iterating over the 
%   following sequence:
%
%   - Execute: Defined in environment.model.execute, the environment 
%     creates signals to be obeserved by the agent. 
%
%   - Observe: Defined in agent.model.observe, the agent observes the 
%     environment and creates features for the inference of the environment's hidden states. 
%
%   - Infer: Defined in agent.model.infer, the agent creates beliefs by 
%     infering the environment's hidden states. 
%
%   - Act: Defined in agent.model.act, the agent acts on the environment
%     based on the infered beliefs.
%
%   - Conclude: Defined in environment.model.conclude, the environment 
%     concludes whether to end or continue the trial. 
%
%   This simulates the mechanisms present in a single behavioral trial. 
%
%   With the trial being finished, FRAMBI_SIMULATE(..) 
%   obtains a response from the agent as defined in agent.model.respond.
%   
% 
%   See also: frambi_plot frambi_disp frambi_estimate exp_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_simulate.php


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

% This is core of the framework.
%
% In this file, the scaffolding to run the experiment
% where agent and environment interact. 
% 
% The idea is based on two structures one for the agent and one for the
% environment. Each structure contains the state and the functions to update
% such state. The separation in two structures in important since the agent
% does not have access directly to the environment generative model.
% Instead the agent contains its internal model which is updated after the 
% interaction with the environment. 
% 
% 2022-12-06 first upload
% 2022-12-13 terminology updated

    % initalize agent and environment states
    if options.initialization
        agent.state = agent.model.initialize(agent.state);
        environment.state = environment.model.initialize(environment.state);
    end
    
    % validate agent and environemnt structures
    if options.validation
        agent.state = frambi_validate(agent.state);
        environment.state = frambi_validate(environment.state);
    end

    % check if logs are required; if not disable feature to increase speed 
    logging = nargout > 1; 

    if logging    
        logs = cell(options.simulate.cycles_max, 1);
%         logs{1, 1} = {environment.state, agent.state};
          logs{1}.agent = agent.state;
          logs{1}.environment = environment.state;          
    end

    % initalize stopping conditions
    stop = false;
    ii = 1;

    while ~stop && ~agent.state.terminate && (ii - 1 < options.simulate.cycles_max)
        % -1.a- execute - (e.g. generate binaural sound)
        %               - output is volatile (the agent uses a model to
        %               keep track of it)
        %               - the environment knows about the agent (e.g. position)
        environment.state = environment.model.execute(environment.state, agent.state.action, options);

        % -2- observation (e.g compute features and generate likelihood)
        agent.state.observation = agent.model.observe(environment.state.output, agent.state, options);
		
        % -3- perform inference with internal model (e.g. compute posterior)
        agent.state.beliefs = agent.model.infer(agent.state, options);

        % -4- decide the next action (e.g. rotate the head)
        agent.state.action = agent.model.act(agent.state, options);

        % -5- terminate loop checking the environment
        stop = environment.model.conclude(environment.state, options);

        % -6- log everything
        if logging
%             logs{ii, 1} = {agent.state, environment.state};
            logs{ii}.agent = agent.state;
            logs{ii}.environment = environment.state;
        end

        % move forward the counter
        ii = ii + 1;
    end

    % -6- additional response mechanisms (e.g. response noise)
    response = agent.model.respond(agent.state, options);

    if logging
        logs{ii-1}.response = response;
        logs = logs(1:max(1,ii-1),1); % remove empty logs
        varargout{1} = logs; 
    end
end 
