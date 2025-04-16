function [agent, options] = barumerli2024_mockup(options)
%barumerli2024_mockup FrAMBI agent performing a mock-up vertical-plane sound localization 
%
%   Usage: [agent, options] = barumerli2024_mockup();
%          [agent, options] = barumerli2024_mockup(options);
%
%   Input parameters:
%     options : Optional structure representing the FrAMBI options.
%
%     agent   : Structure representing the FrAMBI agent. See the general description of 
%               FrAMBI for more details. In addition, the following agent-specific
%               fields are created: 
%
%               - name*: String describing the agent. Default: 'Vertical-Plane Localization Mockup'.
%
%               - model*: Structure defining the functionality of agent by
%                 storing functions handles in fields initialize, observe, 
%                 infer, act, and respond. 
%
%               - state.parameters*: Parameter structure as in FRAMBI_PARAMETERS with:
%
%                 - angular_uncertainty*: The angular uncertainty (i.e., the 
%                   angular standard deviation in the processing, in degrees). 
%                   Default: 22.7 degrees, as in Tab. I, Middlebrooks (1999).
%
%                 - confusion_rate*: The rate (as ratio) of confusing front and back when
%                   localizaing the source. Default: 0.046, as in Tab. I, 
%                   Middlebrooks (1999).
%
%     options :  Structure representing the FrAMBI options. No agent-specific 
%                fields are added.
%
%   BARUMERLI2024_MOCKUP(..) returns a structure describing a mock-up agent 
%   performing vertical-plane sound-source localization. The agent accounts 
%   for angular uncertainty and front-back confusions. 
%
%   BARUMERLI2024_MOCKUP(..) also creates an empty structure with FrAMBI 
%   options or passes options if provided as input. 
%
%   Note that this agent is just a *mock up* to demonstrate some FrAMBI functionality. 
%   This agent does not handle actual sounds, instead, it uses a mock-up
%   environment (from SIG_BARUMERLI2024, which provides the target angle 
%   directly). Specifically, BARUMERLI2024_MOCKUP(..) defines defines the 
%   following functionality linked with local functions:
%
%   - model.observe is linked with local_observe, which adds front-back 
%     confusions and sensory noise to the actual target angle. 
%   
%   - model.infer is linked with local_infer, which uses directly the 
%     observation as the inference (i.e., the agent trusts the observation).
%
%   - model.act is linked with local_act, in which the action is directly the 
%     inference (i.e., the target angle is the action).
%
%   - model.respond is linked with local_respond, which responses with the 
%     action, which is the actual target angle.
%
%   See also: frambi_simulate exp_barumerli2024 frambi_parameters
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%     P. Majdak, M. J. Goupell, and B. Laback. 3-D localization of virtual
%     sound sources: Effects of visual environment, pointing method and
%     training. Atten Percept Psycho, 72:454--469, 2010.
%     
%     J. C. Middlebrooks. Virtual localization improved by scaling
%     nonindividualized external-ear transfer functions in frequency. The
%     Journal of the Acoustical Society of America, 106:1493--1510, 1999.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/barumerli2024_mockup.php


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

if ~exist('options','var'), options=[]; end

%% define the agent 
    agent.name = 'Vertical-Plane Localization Mockup';
      % define default parameters
    agent.state.parameters = frambi_parameters('set',[], ...
      {'angular_uncertainty', 'confusion_rate'}, ...
       [22.7,                  0.046]); 
      % define functions
    agent.model.observe = @local_observe;  
    agent.model.infer = @local_infer;
    agent.model.act = @local_act;
    agent.model.respond = @local_respond;
      % add other default fields and validate
    options=frambi_validate(options);
    agent=frambi_validate(agent);

%% observe: process the input to an observation
function observation = local_observe(input, astate, ~) 
    % mock up: just copy the angle from the input, introduce a random front-back confusion and sensory noise
    % side note: calling randn(1,1) is ~10% faster than just randn 
    angular_noise = randn * astate.parameters.angular_uncertainty.value; % get the uncertainty in the angular estimations
    % consider random front-back confusion (c=0 -> no confusion; c=1 -> confusion)
    confusion = rand < astate.parameters.confusion_rate.value;     
    % introduce front-back confusion to the angle and add angular noise
    observation = 180*confusion + (1-2*confusion)*input + angular_noise;

%% infer: infer the beliefs from observation
function beliefs = local_infer(astate, ~) 
    % mock up: believe what is observed
    beliefs = astate.observation;

%% act: take actions based on beliefs
function action = local_act(astate, ~)
    % mock up: agent does nothing
    action = astate.beliefs;


%% respond: calculate the simulated response
function response = local_respond(astate, ~)
    % mock up: the response is the belief is the observation is the target angle 
    response = astate.action; 

