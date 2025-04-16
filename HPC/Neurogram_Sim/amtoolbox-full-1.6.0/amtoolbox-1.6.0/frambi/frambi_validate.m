function in = frambi_validate(in)
%frambi_validate Validate a FrAMBI structure
%
%   Usage: options = frambi_validate();
%          options = frambi_validate(options);
%          agent = frambi_validate(agent); 
%          environment = frambi_validate(environment); 
%          agent_state = frambi_validate(agent_state); 
%          environment_state = frambi_validate(environment_state);
%
%   Input parameters:
%     agent:             Structure with the FrAMBI agent as indicated by
%                        agent.type. If not 
%                        found, any structure having the field model 
%                        but not model.execute, will be treated as
%                        agent.
%     environment:       Structure with the FrAMBI environment as indicated by
%                        environment.type. If not 
%                        found, any structure having the field model.execute 
%                        will be treated as environment.
%     options:           Structure with the FrAMBI options as indicated by
%                        options.type. If not 
%                        found, any structure not being recognized as 
%                        agent, environment, nor a state will be treated as
%                        options. 
%     agent_state:       Structure with the FrAMBI agent state as indicated by
%                        agent_state.type. If not 
%                        found, any structure having the field parameters 
%                        but not parameters.output, will be treated as
%                        agent_state.
%     environment_state: Structure with the FrAMBI environment state as indicated by
%                        environment_type. If not 
%                        found, any structure having the field 
%                        parameters.output will be treated as
%                        environment_state.
%
%   Output parameter is the updated and validated input structure. 
%      
%   
%   See also: frambi_simulate exp_barumerli2024 sig_barumerli2024 barumerli2024_itdlateral barumerli2024_mockup
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_validate.php


%   #Author: Roberto Barumerli (2023): Original implementation of various validate functions.
%   #Author: Michael Mihocic (2024): Header documentation fixed.
%   #Author: Piotr Majdak (2024): Implementation of frambi_validate based on several validation functions

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

  
if ~exist('in','var')
    % if not provided, it's options
  in.type = 'FrAMBI Options';
elseif isempty(in)
    % if empty, it's options
  in.type = 'FrAMBI Options';
elseif ~isfield(in, 'type')
    % if .type not defined, detect the type from other fields
  if isfield(in, 'parameters')
      % it's a state
		if isfield(in, 'output')
			in.type = 'FrAMBI Environment State'; 
		else 
			in.type = 'FrAMBI Agent State'; 
		end
  elseif isfield(in, 'model')
      % it's environment or agent
      if isfield(in.model,'execute')
        % it's an environment
	     in.type = 'FrAMBI Environment';
      else
        % it's an agent 
        in.type = 'FrAMBI Agent';
      end
  else
      % it's options
    in.type = 'FrAMBI Options';
  end 
end

switch in.type

  case 'FrAMBI Agent'
			% Agent: must not contain parameters
		if isfield(in, 'parameters')
			error('FrAMBI agent structure must not contain the field parameters.'); 
		end
	    % name
    if ~isfield(in, 'name'), in.name = 'unknown'; end
		  % state
    if ~isfield(in, 'state'), in.state.parameters=[]; end
		in.state = frambi_validate(in.state); 
      % model  
	  if ~isfield(in,'model'), in.model=struct(); end
    if ~isfield(in.model, 'initialize'), in.model.initialize = @(astate) astate; end
    if ~isfield(in.model, 'act'), in.model.act = @(astate, options) astate.action; end
    if ~isfield(in.model, 'observe'), in.model.observe = @(eoutput, astate, options) eoutput; end
    if ~isfield(in.model, 'infer'), in.model.infer = @(astate, options) astate.beliefs; end
    if ~isfield(in.model, 'respond'), in.model.respond = @(astate, options) astate.action; end
    if isempty(in.model.initialize), in.model.initialize = @(astate) astate; end
    if isempty(in.model.act), in.model.act = @(astate, options) astate.action; end
    if isempty(in.model.observe), in.model.observe = @(eoutput, astate, options) eoutput; end
    if isempty(in.model.infer), in.model.infer = @(astate, options) astate.beliefs; end
    if isempty(in.model.respond), in.model.respond = @(astate, options) astate.action; end
	
  case 'FrAMBI Environment'
      % Environment: must contain: execute. Must not contain parameters nor simulate.
		if sum(isfield(in, {'parameters','simulate'}))
			error('FrAMBI Environment structure must not contain the fields parameters nor simulate.'); 
		end
	    % name
    if ~isfield(in, 'name'), in.name = 'unknown'; end
		  % state
    if ~isfield(in, 'state'), in.state.parameters.output=[]; end
		in.state = frambi_validate(in.state); 
      % model  
	  if ~isfield(in,'model'), in.model=struct(); end
    if ~isfield(in.model, 'initialize'), in.model.initialize = @(estate) estate; end
    if ~isfield(in.model,'execute'), in.model.execute = @(estate, aact, options) estate; end
    if ~isfield(in.model, 'conclude'), in.model.conclude = @(estate, options) true; end
    if isempty(in.model.initialize), in.model.initialize = @(estate) estate; end
    if isempty(in.model.execute), in.model.execute = @(estate, aact, options) estate; end
    if isempty(in.model.conclude), in.model.conclude = @(estate, options) true; end

  case 'FrAMBI Options'
    % Options: must contain the field sample. Must not contain parameters.
		if isfield(in, 'parameters')
			error('FrAMBI Options structure must not contain the field parameters.'); 
		end
	    % name
    if ~isfield(in, 'name'), in.name = 'unknown'; end
    if ~isfield(in, 'initialization'), in.initialization = true; end
    if ~isfield(in, 'validation'), in.validation = true; end    
      % options used by frambi_simulate	
    if ~isfield(in, 'simulate'), in.simulate = struct(); end
    if ~isfield(in.simulate, 'cycles_max'), in.simulate.cycles_max = 1; end  
      % options used by frambi_sample
    if ~isfield(in, 'sample'), in.sample = struct(); end
    if ~isfield(in.sample, 'bandwidth'), in.sample.bandwidth = 0; end 
    if ~isfield(in.sample, 'iterations'), in.sample.iterations = 500; end 
    if ~isfield(in.sample, 'support'), in.sample.support = [0 0]; end 
      % options used by frambi_estimate
    if ~isfield(in, 'estimate'), in.estimate = struct(); end
    if ~isfield(in.estimate, 'disp'), in.estimate.disp = true; end
    if ~isfield(in.estimate, 'optimizer'), in.estimate.optimizer = 'bads'; end
    if ~isfield(in.estimate, 'parameters'), in.estimate.parameters=struct(); end
    switch in.estimate.optimizer
      case 'bads' % Default options for BADS
				if ~isfield(in.estimate.parameters, 'Display'), in.estimate.parameters.Display = 'off'; end 
			otherwise
		    error('Unknown optimizer'); 			
    end		
		
  case 'FrAMBI Environment State'
      % State of the environment: must contain the fields parameters and output. 
    if ~isfield(in, 'parameters'), in.parameters = struct(); end
    if ~isfield(in, 'output'), in.output = struct(); end

  case 'FrAMBI Agent State'
    % State of the agent: must contain the field parameters and must not contain the field output. 
    if ~isfield(in, 'parameters'), in.parameters = struct(); end
		if isfield(in, 'output')
			error('FrAMBI Agent structure must not contain the field output.'); 
		end
    if ~isfield(in, 'action'), in.action = struct(); end
		if ~isfield(in, 'observation'), in.observation = struct(); end
    if ~isfield(in, 'beliefs'), in.beliefs = []; end
    if ~isfield(in, 'terminate'), in.terminate = false; end

  otherwise
    error([in.type ': Uknown type of FrAMBI structure']); 
end
  
