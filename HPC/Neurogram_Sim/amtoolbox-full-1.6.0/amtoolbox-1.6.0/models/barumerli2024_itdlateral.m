function [agent, options] = barumerli2024_itdlateral(options)
%barumerli2024_itdlateral FrAMBI agent performing ITD-based lateralization
%
%   Usage: [agent, options] = barumerli2024_itdlateral();
%          [agent, options] = barumerli2024_itdlateral(options);
%
%   Input parameters:
%     options : Optional structure representing the FrAMBI options.
%
%   Output parameters:
%     agent   : Structure representing the FrAMBI agent. See the general description of 
%               FrAMBI for more details. In addition, the following agent-specific
%               fields are created: 
%
%               - name*: String describing the agent. Default: 'ITD-based Lateralization'.
%
%               - model*: Structure defining the functionality of agent by
%                 storing functions handles in fields initialize, observe, 
%                 infer, act, and respond. 
%
%               - state.beliefs*: Prior beliefs on the sound-source lateral 
%                 direction. If set to a number (in degrees), the inference 
%                 will be the average between the belief and the posterior. 
%                 Default: Empty vector, meaning no prior.
%
%               - state.parameters*: Parameter structure as in FRAMBI_PARAMETERS with:
%
%                 - lateral_gain*: The lateral gain (i.e., the slope of the response-target 
%                   function). Default: 1, meaning a perfect lateralization 
%                   without any under- or over shooting.
%
%                 - itd_uncertainty*: The ITD uncertainty (i.e., the ITD standard deviation
%                   in the processing, in s). Default: 20 mu s. 
%
%     options :  Structure representing the FrAMBI options with the following
%                agent-specific fields: 
%
%                - agent.angles*: Sound-source angles (in degrees) used for 
%                  the interpolation to infer the lateralization based on ITDs. 
%                  Set to linearly spaced 15 angles from -90 to +90 degrees. 
%
%                - agent.itds*: ITDs (in s) calculated according to 
%                  Woodworth (1954) based on agent.angles for a head radius
%                  of 7 cm and sound speed of 340 m/s. 
%               
%
%   BARUMERLI2024_ITDLATERAL(..) returns a structure describing an agent 
%   performing ITD-based lateralization. It also creates FrAMBI options 
%   (or updates them, if provided as input). 
%
%   This agent follows the structure required by FRAMBI_SIMULATE.
%   Specifically, BARUMERLI2024_ITDLATERAL(..) defines the following
%   functionality linked with local functions:
%
%   - model.initialize is linked with local_initialize, which sets the 
%     head direction to 0 degrees (i.e., front).
%     The head direction is not considered, but it makes sense to have the head
%     looking to the front when localizing a sound source.
%
%   - model.observe is linked with local_observe, which calculates the 
%     ITD in the observed binaural signal
%     from the environment. The observed ITD is subject to the lateral_gain 
%     and the itd_uncertainty.
%   
%   - model.infer is linked with local_infer, which infers the source 
%     lateral angle based on 
%     the observed ITD. The posterior is based on the precomputed ITD-angle 
%     relation stored in options.agent.angles and options.agent.itd. 
%     If belief is set to an angle, the inference is calculated as the average 
%     between the belief (i.e., the prior) and the posterior. Otherwise
%     the inference is just the posterior. 
%
%   - model.act is linked with local_act, in which it acts by setting: 
%
%     - head to state.head, which, unless modified will be looking at front.
%
%     - hand to state.belief, which is the infered sourceangle.
%
%   - model.respond is linked with local_respond, which responses with 
%     the action of the hand, which is 
%     the infered lateral angle of the sound source (in degrees).
%
%
%   See also: frambi_simulate exp_barumerli2024 frambi_parameters frambi_validate
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%     R. S. Woodworth and H. Schlosberg. Experimental psychology, Rev. ed.
%     Holt, Oxford, England, 1954.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/barumerli2024_itdlateral.php


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

%% define the agent
agent.name = 'ITD-based Lateralization';

% add state and parameters
agent.state.beliefs = []; % No prior 
agent.state.parameters = frambi_parameters('set',[], ...
      {'lateral_gain', 'itd_uncertainty'}, ...
       [1.0,            20e-6]); 

  % Link between the ITD and sound-source direction from Woodworth (1954)'s formula
sound_speed = 340; % in m/s
head_radius = 0.07; % in m
angles = linspace(-pi/2, pi/2, 15); % Evaluated on a grid ...
options.agent.itds = head_radius / sound_speed * (angles + sin(angles)); % (in s) ... and stored as constant 
options.agent.angles = rad2deg(angles); % in degrees
  % add functions
agent.model.initialize = @local_initialize;
agent.model.observe = @local_observe;
agent.model.infer = @local_infer;
agent.model.act = @local_act;
agent.model.respond = @local_respond;
  % validate the structures
options=frambi_validate(options);
agent=frambi_validate(agent);

%% initialize: intitalize the trial
function astate = local_initialize(astate, options)
    % trial starts with the head facing the frontal source
    astate.head = 0; 
  
%% observe: calculate features given the binaural input
function observation = local_observe(input, astate, options)
    [~, lag] = max(abs(xcorr(input.signal(:, 1), input.signal(:, 2))));
    itd = (lag - size(input.signal, 1)) / input.fs;

    observation = itd * astate.parameters.lateral_gain.value + randn * astate.parameters.itd_uncertainty.value;

%% infer: infer the environmental states given the observation
function beliefs = local_infer(astate, options)
      % decode the angle from spatial features
    angle = -spline(options.agent.itds, options.agent.angles, astate.observation);
      % this is the heart of bayesian belief update
    if isempty(astate.beliefs)
        % when prior not available, use current observation
        % (i.e. maximum likelihood assuming gaussian distribution)
        beliefs = angle; 
    else
        % when prior available, combine prior with observation
        % (i.e. maximum a posteriori assuming conjugate distribution - 
        % gaussian distributions with equal variance)
        beliefs = 0.5*(astate.beliefs + angle); 
    end

%% act: perform an action according to the beliefs
function action = local_act(astate, options)
    action.head = astate.head; % the head's direction
    action.hand = astate.beliefs; % the hand shows the perceived angle

%% respond: provide a response given the states
function response = local_respond(astate, options)
    response = astate.action.hand;
  


