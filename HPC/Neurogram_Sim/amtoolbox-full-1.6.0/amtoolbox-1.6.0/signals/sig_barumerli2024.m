function [environment, options] = sig_barumerli2024(flag, options)
%sig_barumerli2024 Spatialization of sound sources as FrAMBI examples
%
%   Usage: [environment, options] = sig_barumerli2024(flags, options)
%
%   Input parameters:
%     flag    : String describing the type of the environment:
%
%               - 'horizontal': Spatializes a sound source in the horizontal 
%                 plane. It is used by the agent BARUMERLI2024_ITDLATERAL.
%
%               - 'mockup': A mockup of spatialization in the vertical plane. 
%                 It is used by the agent BARUMERLI2024_MOCKUP.
%
%     options : Optional structure representing the FrAMBI options.
%
%   Output parameters:
%     environment: Structure representing the FrAMBI environment. See the 
%                  general description of FrAMBI for more details. In 
%                  addition, the following environment-specific fields are 
%                  created: 
%
%                  - name*: String describing the environment. Default: 
%                    The string from flag.
%
%                  - model*: Structure defining the functionality of the
%                    environment by storing functions handles in fields 
%                    initialize, execute, and conclude. 
%
%                  - state.parameters*: Parameter structure as in FRAMBI_PARAMETERS 
%                    storing the states of the evironment:
%
%                    - angle*: The sound source angle (in degrees).
%                      Default: 0 degrees. 
%
%                    - duration*: The duration (in s) of the sound. 
%                      Used in the 'horizontal' environment only. 
%                      Default: 150 ms. 
%
%                    - angular_speed*: The angular speed (in degrees/s) of 
%                      the sound source. 
%                      Used in the 'horizontal' environment only. 
%                      Default: 0 degrees/s, i.e., stationary source. 
%
%                    - time_increment*: The duration between the looks 
%                      updating the source movement. 
%                      Used in the 'horizontal' environment only. 
%                      Default: 150 ms, i.e., a single look. 
%                  
%                  - hrtf*: SOFA structure storing the HRTF set used for 
%                    the spatialization. 
%                    Used in the 'horizontal' environment only. 
%
%                  - sound.fs*: Sampling rate (in Hz) of the HRTF set. It is 
%                    used as the sampling rate of the sound. 
%                    Used in the 'horizontal' environment only. 
%
%     options :  Structure representing the FrAMBI options. No agent-specific 
%                fields are added.
%
%
%   SIG_BARUMERLI2024('horizontal',..) generates a FrAMBI environment simulating
%   a sound source rotating in the horizontal plane. The sound is spatialized 
%   using a preloaded HRTF set. The environment updates the source position 
%   over time according to the specified angular speed and sound duration. 
%   Note that to reduce computational time, the spatialization is done at 
%   the initialization of the environment for all source angles. 
%   It defines the following functionality linked with local functions: 
%
%   - model.initialize is linked with local_initialize, in which 
%     the sound for the whole trial is generated (as a 
%     white-noise burst) and spatialized. The sound is stored as sound.signal. 
%     Further, the simulation time is reset and stored as time. 
%
%   - model.execute is linked with local_execute, in which the chunk of 
%     the sound to be observed by the agent 
%     is returned as output.signal together with the sampling rate 
%     as output.fs. Further, the hidden environmental states such as 
%     the source angle and time are updated. 
%
%   - model.conclude is linked with local_conclude, in which the 
%     environment concludes whether the trial has reached its end. 
%     It returns true if the time passes the sound duration.
%
%   SIG_BARUMERLI2024('mockup',..) generates a FrAMBI environment as a  mockup 
%   for the vertical-plane sound-source localization. In this mockup, 
%   the source angle is directly accessible by the agent, which then 
%   does not need to infer it at all. The mockup uses the model.execute functionality
%   only which is linked with local_execute_mockup. It returns the angle 
%   of the source directly as the output to the agent. This results in fast 
%   simulation useful for educational purposes only. 
%
%
%   See also: exp_barumerli2024 frambi_simulate barumerli2024_itdlateral barumerli2024_mockup
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_barumerli2024.php


%   #Requirements: MATLAB SOFA
%   #Author: Roberto Barumerli (2023): Original implemenation. 
%   #Author: Piotr Majdak (2024): Initial implementation based on barumerli2024_dynamic from see https://gitlab.com/robaru/amt_clone/-/tree/frambi_release
%   #Author: Roberto Barumerli (2024): Further integration in AMT and documentation. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

if ~exist('options','var'), options=[]; end

switch flag
	case 'horizontal'
%% define the environment with a source in the horizontal plane
    environment.name = 'horizontal';
    
    % parameters
    params = frambi_parameters('init', struct);
    
    params = frambi_parameters('set', params, {'angle'}, 0); % default: direction at the front
    params = frambi_parameters('set', params, {'duration'}, .15); 
    params = frambi_parameters('set', params, {'angular_speed'}, 0); % default: stationary sound source
    params = frambi_parameters('set', params, {'time_increment'}, params.duration.value); % default: one increment
    
    environment.state.parameters = params;     
    
      % additional state's values
    hrtf = amt_load('barumerli2024', 'Kemar_HRTF_sofa.sofa');
    environment.state.hrtf = hrtf;
    environment.state.sound.fs = hrtf.Data.SamplingRate; % fs of the HRTFs => fs of the sound      
      % add functions
    environment.model.initialize = @local_initialize;
    environment.model.execute = @local_execute;
    environment.model.conclude = @local_conclude;
      % validate structure 
    options=frambi_validate(options);
    environment=frambi_validate(environment);

	case 'mockup'
%% define the mockup environment
    environment.name = 'mockup';
      % add state and parameters
    environment.state.parameters = frambi_parameters('init', struct, {'angle'}, 0);		
      % define functions
    environment.model.execute = @local_execute_mockup; % it's a mockup: the environment passes its state as ouput to the agent
      % validate structures
    options=frambi_validate(options);
    environment=frambi_validate(environment);
end % end of main

%% horizontal environment: intialize 
function estate = local_initialize(estate)
      % generate the sound of the source
    source = randn(estate.parameters.duration.value * estate.sound.fs, 1); 
      % calculate the end angle of the moving source
    angle_end = estate.parameters.angular_speed.value * estate.parameters.duration.value + estate.parameters.angle.value;
      % spatialize the sound emitted by a moving source
    estate.sound.signal = SOFAspat(source, estate.hrtf, [estate.parameters.angle.value, angle_end], 0); 
      % reset the time
    estate.time = 0; 

%% horizontal environment: execute 
function [estate] = local_execute(estate, action, options)
      % generate output
    time_idx = round(estate.time*estate.sound.fs + (1:estate.parameters.time_increment.value*estate.sound.fs));
    estate.output.signal = estate.sound.signal(time_idx,:);
    estate.output.fs = estate.sound.fs;
      % increment time 
    estate.time = estate.time + estate.parameters.time_increment.value;
      % update source's direction 
    estate.angle = estate.parameters.angular_speed.value * estate.time + estate.parameters.angle.value;      

%% horizontal environments: conclude 
function stop = local_conclude(estate, options)
      % the rounding prevents numerical errors
    stop = (estate.time + estate.parameters.time_increment.value) > estate.parameters.duration.value;

%% mockup environment: execute
function [estate] = local_execute_mockup(estate, action, options)
    estate.output = estate.parameters.angle.value;
