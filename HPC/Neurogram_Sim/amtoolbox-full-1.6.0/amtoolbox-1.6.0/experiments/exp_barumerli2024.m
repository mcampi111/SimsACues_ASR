function exp_barumerli2024(varargin)
%exp_barumerli2024 Examples of FrAMBI reproducing figures from Barumerli and Majdak (2024)
%
%   Usage: exp_barumerli2024(flag);
%
%   EXP_BARUMERLI2024(..) reproduces figures from Barumerli and Majdak (2024). 
%   It serves as showing example on the usage of FrAMBI. The flag can be one of the following:
%
%     'basic'     Demonstrates how to use FRAMBI_SAMPLE by applying a simple ITD-based sound-lateralization model 
%                 BARUMERLI2024_ITDLATERAL as the agent and simulating response distributions for tasks. It uses 
%                 SIG_BARUMERLI2024 as the enviroment. 
%
%     'dynamic'   Demonstrates how to create a dynamic scenario and apply FRAMBI_PLOT and FRAMBI_DISP 
%                 to visualize and display the agent-environment interactions. In this example, 
%                 the agent tracks a moving sound source and interacts with the environment over time. 
%                 This example also uses BARUMERLI2024_ITDLATERAL as the agent and SIG_BARUMERLI2024 as the enviroment.
%
%     'variants'  Demonstrates how to handle multiple model variants. It compares the results for two model variants: 
%                 with and without considering the lateral gain. 
%                 This example also uses BARUMERLI2024_ITDLATERAL as the agent and SIG_BARUMERLI2024 as the enviroment.
%
%     'fitting'   Demonstrates how to handle actual data from a behavioral experiment, fit model parameters to that data, 
%                 and perform model comparisons.  The model comparison is based on the Bayesian Information Criterion (BIC).
%                 It uses the mock-up model BARUMERLI2024_MOCKUP as the agent and SIG_BARUMERLI2024 as the enviroment.
%
%     'all'       Runs all the examples.
%
%
%   Examples:
%   ---------
%
%   To run the basic example use :
%
%     exp_barumerli2024('basic'); 
%
%   To run the dynamic example use :
%
%     exp_barumerli2024('dynamic'); 
%
%   To run the example comparing variants use :
%
%     exp_barumerli2024('variants'); 
%
%   To run the fitting example use :
%
%     exp_barumerli2024('fitting'); 
%
%
%   See also: barumerli2024_itdlateral barumerli2024_mockup sig_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_barumerli2024.php


%   #Requirements: MATLAB M-Signal BADS
%   #Author: Roberto Barumerli (2023): Original implementation.
%   #Author: Roberto Barumerli (2024): Integration in the AMT and documentation. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% your code starts here
definput.flags.type = {'missingflag','all',...
                        'basic', ...
                        'dynamic', ...
                        'variants', ...
                        'fitting'}; 

flags = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end

%% Run all examples
if flags.do_all
    amt_disp('Creating figure: basic...');
    exp_barumerli2024('basic');
    amt_disp('Creating figure: dynamic...');
    exp_barumerli2024('dynamic');
    amt_disp('Creating figure: variants...');
    exp_barumerli2024('variants');
    amt_disp('Creating figure: fitting...');
    exp_barumerli2024('fitting');
end

% setting seed for random generator 
rng('default');

%% Basic scenario: setup and distribution sampling
if flags.do_basic
    % setup the environment
    [environment, options] = sig_barumerli2024('horizontal');
    % setup the agent
    [agent, options] = barumerli2024_itdlateral(options);
    % start the stimulation for the sound-source lateral angle of 15 degrees
    environment.state.parameters.angle.value = 0;
    response = frambi_simulate(agent, environment, options);
    
    amt_disp('FrAMBI Basic scenario: Sound lateralisation'); 
    amt_disp(['  Actual angle: ' num2str(environment.state.parameters.angle.value) ' deg']);
    amt_disp(['  Estimated  angle: ' num2str(response) ' deg']);

    % generate histogram of responses
    options.sample.measurement_samples = 1000; 
    options.sample.support = (-90:1:90)';
    options.sample.bandwidth = 0;
    [~, dist0, support] = frambi_sample(agent, environment, options);    
    % generate a Gaussian estimation of the response distribution
    options.sample.bandwidth = 2;
    [~, dist2, support] = frambi_sample(agent, environment, options);

    f = figure('Position',[509,410,329,324], 'Units','pixels');        
    plot(support, dist0, ':', 'Color', [0, 128, 255, 127]./255, 'LineWidth',1.5);
    hold on
    plot(support, dist2, '-', 'Color', [0, 128, 255]./255, 'LineWidth',1.5);
    set(gca,'FontSize', 12); 
    xlabel('Lateral angle (deg)', 'FontSize',12);
    ylabel('Response probability', 'FontSize',12);
    xlim([-31 31]+environment.state.parameters.angle.value);
    ylim([-0.001, .185]);
    yticks(0:.05:0.15);
    line(environment.state.parameters.angle.value*[1 1],ylim,'LineStyle','-','LineWidth',1,'Color','k');
    legend1 = legend({'Raw density', 'Smoothed density','Actual angle'},'Location','Best','FontSize',9);
    set(legend1,...
            'Position',[0.544652990847977 0.835933643573503 0.449848015529403 0.163580242498421])
end

%% Plot the predictions for the dynamic model with observations
if flags.do_dynamic
    % setup the environment
    [environment, options] = sig_barumerli2024('horizontal');
    environment.state.parameters.angle.value = 0; % start with 0 deg angle
    environment.state.parameters.angular_speed.value = 90; % deg/s
    environment.state.parameters.time_increment.value = 0.005; % ms

    % setup the agent
    [agent, options] = barumerli2024_itdlateral(options);
    agent.state.beliefs = 0; % set the prior to the frontal angle   
    agent.state.parameters.lateral_gain.value = 1.65; % lateral overshoot  

    % define the maximal number of perception-action cycles and start the simulation
    options.simulate.cycles_max = 100; 

    [~, logging] = frambi_simulate(agent, environment, options); 

    % print the logs
    frambi_disp(logging);
    % plot the results 
    fig_handle = frambi_plot(logging, {'beliefs'}, {'angle', 'time'});
    set(fig_handle, 'Position',[509,410,329,324], 'Units','pixels'); 
    set(gca,'FontSize',12)
    ylim([-5, 25])
    yticks(0:10:20)
    
    ylabel('Lateral angle (deg)', 'FontSize',12, 'FontWeight','normal');
    xlabel('Time (s)', 'FontSize',12, 'FontWeight','normal');
    legend('Location','Best','FontSize',9);
end

%% How to run multiple model variants 
% (Here: Two dynamic ITD-based model variants)
if flags.do_variants
    % setup the environment
    [environment, options] = sig_barumerli2024('horizontal');
    environment.state.parameters.angle.value = 0; % start with 0 deg angle
    environment.state.parameters.angular_speed.value = 90; % deg/s
    environment.state.parameters.time_increment.value = 0.005; % ms    
    
    % setup the agent
    [agent, options] = barumerli2024_itdlateral(options);  
    agent.state.beliefs = 0; % set the prior to the frontal angle   

    % define some general options
    options.simulate.cycles_max = 100; 
    options.sample.measurement_samples = 500;
    % using response grid as in Perrott and Musicant (1977)
    options.sample.support = (-89:2.2:89)';
    
    % create variants
    pars = frambi_parameters('set', agent.state.parameters, {'itd_uncertainty'}, 5e-5);
    % variant #1: agent with belief update and without lateral overshoot 
    variants{1,1} = frambi_parameters('set', pars, {'lateral_gain'}, 1);    
    % variant #2: agent with belief update and a lateral overshoot
    variants{2,1} = frambi_parameters('set', pars, {'lateral_gain'}, 1.65);
    
    % data from Table II, Perrott and Musicant (1977)
    perrott1977mean = 21.7; % actual behavioral response for 90 deg/s

    % iterate over variants
    for p=1:length(variants)
        agent.state.parameters = variants{p};
        [~, dists(p,:), support] = frambi_sample(agent, environment, options);
    end
    

    f = figure('Position',[0,0,329*2,324],'Units', 'pixels');
    bar(support, dists(1,:), 'FaceColor', [255,255,191]./255, 'FaceAlpha',0.5);
    hold on;
    bar(support, dists(2,:), 'FaceColor', [171,221,164]./255, 'FaceAlpha',0.5);
    ylim([0, .3])

    plot(13.5*[1 1], ylim, '--k','LineWidth',1.5); % actual sound angle
    plot(perrott1977mean*[1 1], ylim, '-', 'Color', [0, 128, 255]./255, 'LineWidth',1.5); % behavioral response
    set(gca,'FontSize',12)
    legend({'Variant w/ lateral gain', ...
                'Variant with lateral gain', ...
                'Actual angle', ...
                'Reported angle'}, 'FontSize',9, 'Position',[0.688383844028217 0.684146536120015 0.266666661022288 0.303493441452626]);
    xlim([0, 35]);
    yticks(0:.1:.3)
    yticklabels(0:.1:.3)
    xlabel('Lateral angle (deg)', 'FontSize',12, 'FontWeight','normal');
    ylabel('Response probability', 'FontSize',12, 'FontWeight','normal');
end

%% How to fit parameters for two model variants: 
% Here, plot mock-up vertical localization with fitted parameters
if flags.do_fitting
    % setup the environment
    [environment, options] = sig_barumerli2024('mockup');
    % setup the agent
    [agent, options] = barumerli2024_mockup(options);
    % load behavioral data
    majdak2013 = data_majdak2010('HMD_H'); % data from Majdak et al. (2010)
    mtx = majdak2013(3).mtx; % use data from subject #3
    mtx(abs(mtx(:, 7)) > 30,:) = []; % take only targets +/-30 deg around the median plane
    target_angles = round(mtx(:,6));
    response_angles = round(mtx(:,8));
    % define some general options      
    options.sample.support = (-30:5:210)';
    options.sample.measurement_samples = 500;
    options.sample.bandwidth = 5;
	  angles = -30:5:210; % target angles for the simulation

    % define the parameter for variant #1: agent considering front-back confusions
    aparams = frambi_parameters('init', [], {'angular_uncertainty'}, 22.7);          
    ap_v(1) = frambi_parameters('set', aparams, {'confusion_rate'}, .046);
    % define the parameter for variant #2: agent agnostic to front-back confusions
    ap_v(2) = frambi_parameters('set', aparams, {'confusion_rate'}, 0);
    
    % figure configuration
    fig = figure('Position', [0,0,350,450], 'Units', 'pixels');
    ha = tight_subplot(2,2, [.01 .01],[.125 .125],[.14 .001]);    
    MarkerSize = 4.5;
    FontSize = 12; 
    ax_steps = 0:90:180;
    % simulate for ad-hoc parameter choice
    for v=1:2
        % prepare agent variant
        agent_temp = agent;
        agent_temp.state.parameters = ap_v(v);
          % loop over the targets        
        for idx = 1:length(angles)
            environment.state.parameters.angle.value = angles(idx);
            [~, dists(idx,:), support] = frambi_sample(agent_temp, environment, options);
        end
        % plot predictions
        axes(ha(v));
        pcolor(support, angles, log(dists+eps));
        caxis([-7, -2]);
        colormap bone
        shading flat
        hold on 
        % plot actual behavioral data
        plot(target_angles, response_angles, 'or', 'MarkerSize', MarkerSize,'MarkerFaceColor','red');        
        
        % general plotting
        axis([-30, 210, -30, 210]);
        yticks([]);
        set(gca,'XTick',ax_steps);
        set(gca,'fontsize',FontSize);
    end
    % plotting details
    set(ha(1),'YTick',0:60:210);
    cbar = colorbar('northoutside', 'Position', [0.37 0.89 0.35 0.03], 'FontSize', 9);
    set(get(cbar,'YLabel'),'String', ...
              'Resp. Prob. (log-scale)', 'FontSize', 9)
    
    % fitting the parameters to behavioral data 
    data.variables = target_angles;    % variables varying with the trials
    data.variablenames = {"angle"};    % name of those variables
    data.responses = response_angles;  % behavioral responses as targets for the optimization
    
    % set the parameter for the fitting
    options.sample.iterations = 50;
    
    % variant #1: setup the parameters and their ranges
    v1 = frambi_parameters('init', [], ...
            {'angular_uncertainty'}, 10, true, 'log',  [1, 2, 120, 150]);
    v1 = frambi_parameters('set', v1, ...
            {'confusion_rate'}, .10, true, {'logit'}, [0.001, 0.1, .9, .999]);
    
    amt_disp('Running optimizer for the variant considering front-back confusions...');
    agent.state.parameters = v1;
    [params, models{1}] = frambi_estimate(data, agent, environment, options);
    v1 = frambi_parameters('assign', v1, params.names, params.values);
    
    % variant #2 (no front-back confusions): setup the parameters and their ranges
    v2 = frambi_parameters('init', [], ...
            {'angular_uncertainty'}, 10, true, 'log',  [1, 2, 120, 150]);    
    v2 = frambi_parameters('set', v2, ...
            {'confusion_rate'}, 0);
    
    amt_disp('Running optimizer for the variant agnostic to front-back confusions...');
    agent.state.parameters = v2;
    [params, models{2}] = frambi_estimate(data, agent, environment, options);
    v2 = frambi_parameters('assign', v2, params.names, params.values);
    
    ap_f(1)=v1; ap_f(2)=v2;
    for v=1:2
        % prepare agent variant
        agent_temp = agent;
        agent_temp.state.parameters = ap_f(v);
          % loop over the targets        
        for idx = 1:length(angles)
          environment.state.parameters.angle.value = angles(idx);
          [~, dists(idx,:), support] = frambi_sample(agent_temp, environment, options);
        end
    
        axes(ha(v+2,1));
        pcolor(support, angles, log(dists+eps));
        caxis([-7, -2])
        colormap bone
        shading flat
        hold on 
        plot(target_angles, response_angles, 'or', 'MarkerSize', MarkerSize,'MarkerFaceColor','red');
        axis([-30, 210, -30, 210])
        xticks([]);
        yticks([]);
        set(gca,'fontsize',FontSize);
        set(gca,'XTick',ax_steps);
    end

    xlabel('Target angle (deg)','Position',[-26 -66, -1], 'FontSize',FontSize);
    ylabel('Response angle (deg)','Position',[-324 236, -1], 'FontSize',FontSize);    

    set(ha([1,3]),'YTick',ax_steps);
    
    % test which one is better
    frambi_test(models, ...
        {'considering front-back confusions', ...
            'agnostic to front-back confusions'});
    
end


