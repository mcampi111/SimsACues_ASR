function data = data_majdak2013(varargin)
%DATA_MAJDAK2013 Listener-specific localization responses
%   Usage: data = data_majdak2013();
%          data = data_majdak2013('control');
%          data = data_majdak2013('target');
%          data_majdak2013('fig6')
%          pretest = data_majdak2013('B');
%          pretest = data_majdak2013('LP');
%          pretest = data_majdak2013('W');          
% 
%   Input parameters:
%     B          : Return the data from the pretest for the broadband condition
%     LP         : Return the data from the pretest for the low-passed condition
%     W          : Return the data from the pretest for the warped condition
%     fig6       : Plot the Figure 6
%     all        : Default. Return all data of all subjects
%     control    : Return all data of the control group (trained on the low-passed condition)
%     target     : Return all data series of the target group (trained on the warped condition)
%
%     
%   Output parameters:
%     pretest  : Structure with the data from the pretest only. It contains the following fields:
%
%                - id*: Subject ID.
%
%                - mtx*: Item list with trials and angles. Each row contains information 
%                  about a single trial. The columnn describe the target 
%                  and response angles in the format of the item list used 
%                  in LOCALIZATIONERROR.
%
%                      
%     data       : Structure with the data from the pretest, training, and posttest. 
%                  It contains the following fields:
%
%                  - subject_str*: Listener ID (string).
%
%                  - pos*: Item list with trials and angles. Each row contains information 
%                    about a single trial. The columnn describe the target 
%                    and response angles in the format of the item list used 
%                    in LOCALIZATIONERROR.
%
%                  - session*: Session index (as an integer number).
%
%                  - session_str*: Session name (as a string).
%
%                  - trial*: Trial index within each session.
%
%                  - is_control*: Flag describing the control group (1) or target group (0).
%
%
%   pretest = DATA_MAJDAK2013(..) returns listener-specific responses
%   from Majdak et al.  (2013) obtained from a localization pretest.
%
%   data = DATA_MAJDAK2013(..) returns listener-specific responses
%   from Majdak et al.  (2013) obtained from a localization pretest, training, 
%   and posttest. 
%
%   To display Figure 6 from Majdak et al. (2013) use :
%
%     data_majdak2013('fig6');
%
%   References:
%     P. Majdak, T. Walder, and B. Laback. Effect of long-term training on
%     sound localization performance with spectrally warped and band-limited
%     head-related transfer functions. The Journal of the Acoustical Society
%     of America, 134:2148--2159, 2013.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/data/data_majdak2013.php


%   #Requirements: M-Curve
%   #Author: Robert Baumgartner (2015): implementation of control and target data.
%   #Author: David Poirier-Q. (2022): implementation of learning data (fig6)
%   #Author: Clara Hollomey (2023): integration in the AMT
%   #Author: Piotr Majdak (2024): integration of plotting figure 6 and fixing issue #215.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% Check input options

% Define input flags
definput.import={'amt_cache'};
definput.flags.condition = {'all','BB','LP','W','control', 'target', 'fig6'};

% Parse input options
[flags, ~] = ltfatarghelper({},definput,varargin);


%% Load data
if flags.do_all
    data = amt_load('majdak2013', 'data_fig6.mat');
    data = data.data;
end

if flags.do_control || flags.do_target
    data = amt_load('majdak2013', 'data_fig6.mat');
    data = data.data;
      % select data
    selVect = data.is_control == contains(flags.condition, 'control');    
      % apply filter across struct fields
    fieldNames = fieldnames(data);
    for iField = 1:length(fieldNames)
        data.(fieldNames{iField}) = data.(fieldNames{iField})(selVect, :);
    end

end

if flags.do_BB || flags.do_W || flags.do_LP 
    x = amt_load('majdak2013', 'data.mat');
    C = find(ismember(x.condition,flags.condition));
    for ll = 1:length(x.subject)

      data(ll).mtx = x.subject(ll).expData{C}(:,1:8);
      data(ll).id = x.subject(ll).id;

    end
end

%% Plot Figure 6
if flags.do_fig6
  data = amt_load('majdak2013', 'data_fig6.mat');
  data = data.data;

    % init locals
  nonTrainingSessionNames = {'learn', 'post_learn', 'pre_test_dummy', 'post_test_dummy', 'pre_test_warped', 'post_test_warped'};
  traininSessionNames = {'training_1', 'training_2', 'training_3', 'training_4', 'training_5', 'training_6', 'training_7', 'training_8', 'training_9', 'training_10', 'training_11', 'training_12', 'training_13', 'training_14', 'training_15', 'training_16', 'training_17', 'training_18', 'training_19', 'training_20', 'training_21'};
  configs = struct('sessionNames', {{}}, 'stat', [], 'isControl', 0);

    % loop over subject groups
  for iControl = 0:1
      % loop over pre/post test sessions
      for iSession = 1:length(nonTrainingSessionNames)
          configs(end+1) = struct('sessionNames', {{nonTrainingSessionNames{iSession}}}, 'stat', [], 'isControl', iControl);
      end
      % add training sessions (grouped)
      configs(end+1) = struct('sessionNames', {traininSessionNames}, 'stat', [], 'isControl', iControl);
  end
  configs(1) = [];  % remove first (dummy)

  % compute stats
  errbaridx = 2;
  cialpha = 0.05; % 95% confidence interval
  N = 4200;
  errorTypeStr = {'querrMiddlebrooks', 'rmsPmedianlocal', 'precL'};
  amt_disp(''); 
    % loop over error types
  for ii = 1:numel(errorTypeStr)
    err = errorTypeStr{ii};
      % loop over config (sessions)
    for iConfig = 1:length(configs)
        config = configs(iConfig);
        meanallid = [];
        % loop over subsession (for training)
        for iSession = 1:length(config.sessionNames)
              % log
            amt_disp(sprintf('Process Test:    %d/%d; Session: %d/%d', iConfig, length(configs), iSession, length(config.sessionNames)), 'volatile');
              % init filter
            selVect = data.is_control == config.isControl;
            selVect = selVect & ismember(data.session_str, config.sessionNames{iSession});
              % discard first 50 trials for learning session 
            if( ismember(config.sessionNames, 'learn') ); selVect = selVect & data.trial > 50; end
              % stats
            meanallid(iSession, :) = bootstrp(sum(selVect), @(m) localizationerror(m,err), data.pos(selVect, :));
        end
          % compute stats
        [muprepost,sigprepost,muciprepost,sigciprepost] = normfit(meanallid.', cialpha);
        configs(iConfig).stat(:,1) = muprepost;
        configs(iConfig).stat(:,2) = sigprepost;
        configs(iConfig).stat(:,3) = diff(muciprepost)/2;
        configs(iConfig).stat(:,4) = diff(sigciprepost)/2;
    end
	amt_disp();

    % model training performances
    
      % control group
    x=(200:200:N)';
    yhat=configs(14).stat(:,1);
    [yfitC, r, ~, COVB]=nlinfit(x,yhat,@exponential,[10 -0.0005 min(yhat)]);
      % warped group
    x=(200:200:N)';
    yhatW=configs(7).stat(:,1);
    [yfitW, rW, ~, COVBW]=nlinfit(x,yhatW,@exponential,[16 -0.0005 min(yhatW)]);

      % plot data
    figure; hold on;
    set(gcf,'Position',[10   226   616   484],'PaperType','A4');
    prepos=-200;
    postpos=N+400;
      % prepare variables
    statPP = reshape([configs(8:13).stat], 4, 6).';
    statPPW = reshape([configs(1:6).stat], 4, 6).';
    stat = configs(14).stat;
    statW = configs(7).stat;
      % model: control
    newx=(100:50:N+100)';
      % model: warped
    [ypred, delta]=nlpredci(@exponential,newx,real(yfitW),real(rW),'covar',real(COVBW));
    hp=patch([newx; flipud(newx)], [ypred+delta; flipud(ypred-delta)],[1 1 1]*0.7);
    set(hp, 'Edgecolor', [1 1 1]*0.7);
    plot(newx,ypred,'k','LineWidth',1);
    [ypred, delta]=nlpredci(@exponential,newx,real(yfitC),real(r),'covar',real(COVB));
    hp=patch([newx; flipud(newx)], [ypred+delta; flipud(ypred-delta)],[1 1 1]*0.8);
    set(hp, 'Edgecolor', [1 1 1]*0.8);
    plot(newx,ypred,'k','LineWidth',1);
      % control: pre- & post
    h=errorbar([prepos; N+100], [statPP(1,1); NaN], [statPP(2,errbaridx); NaN], 'g^'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','g'); leg_BBcontrol=h;
    h=errorbar([postpos; N+100], [statPP(2,1); NaN], [statPP(2,errbaridx); NaN], 'g^'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','g');
    h=errorbar([prepos; N+100], [statPP(3,1); NaN], [statPP(3,errbaridx); NaN], 'ro'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','r'); leg_BLcontrol=h;
    h=errorbar([postpos; N+100], [statPP(4,1); NaN], [statPP(4,errbaridx); NaN], 'ro'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','r');
    h=errorbar([prepos; N+100], [statPP(5,1); NaN], [statPP(5,errbaridx); NaN], 'bs'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','b'); leg_WPcontrol=h;
    h=errorbar([postpos; N+100], [statPP(6,1); NaN], [statPP(6,errbaridx); NaN], 'bs'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','b');
      % warped: pre- & post
    h=errorbar([prepos+50; N+150], [statPPW(1,1); NaN], [statPPW(2,errbaridx); NaN], 'g^'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w'); leg_BBtarget=h;
    h=errorbar([postpos+50; N+150], [statPPW(2,1); NaN], [statPPW(2,errbaridx); NaN], 'g^'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w');
    h=errorbar([prepos+50; N+100], [statPPW(3,1); NaN], [statPPW(3,errbaridx); NaN], 'ro'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w'); leg_BLtarget=h;
    h=errorbar([postpos+50; N+100], [statPPW(4,1); NaN], [statPPW(4,errbaridx); NaN], 'ro'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w');
    h=errorbar([prepos+50; N+100], [statPPW(5,1); NaN], [statPPW(5,errbaridx); NaN], 'bs'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w'); leg_WPtarget=h;
    h=errorbar([postpos+100; N+100], [statPPW(6,1); NaN], [statPPW(6,errbaridx); NaN], 'bs'); local_tick(h);
    set(h,'LineWidth', 1,  'LineStyle','none','MarkerFaceColor','w');
      % training: control group
    h1=errorbar([(200:200:N)'; N+100],[stat(:,1); NaN],[stat(:,errbaridx); NaN],'ro');
    set(h1,'LineWidth', 1, 'LineStyle','none','MarkerFaceColor','r','LineStyle','-');
      % training: warped group
    h1=errorbar([(200:200:N)'; N+100],[statW(:,1); NaN],[statW(:,errbaridx); NaN],'bs');
    set(h1,'LineWidth', 1, 'LineStyle','none','MarkerFaceColor','w','LineStyle','-');
      % plot formatting
    xlabel('Training day number','FontName','Arial');
    [~,meta]=localizationerror(zeros(1, 9), err);
    ylabel(meta.ylabel,'FontName','Arial');
    box on;
    set(gca,'XLim',[prepos-300 postpos+300],'FontName','Arial');
    set(gca,'XTick',[200:2*200:N ]);
    celli=1:N/200';
    c=num2cell(celli(1:2:end))';
    set(gca,'XTickLabel',c);
    set(gca, 'TickLength', [0.02 0.05]);
    set(gca,'LineWidth',1);
    switch err
        case 'querrMiddlebrooks'
            set(gca,'YLim', [2 34.9]);
        case 'rmsPmedianlocal'
            set(gca,'YLim', [26 49]);
        case 'precL'
            set(gca,'YLim', [10.2 20.2]);
            set(gca, 'YTick', 10:2:20);
            h=legend([leg_BBcontrol leg_BLcontrol leg_WPcontrol leg_BBtarget leg_BLtarget leg_WPtarget], ...
                'Control Broadband', 'Control Band-Limited', 'Control Warped', ...
                'Target Broadband', 'Target Band-Limited', 'Target Warped');
            set(h,'Fontsize',10,'LineWidth',1);
    end
  end
end

%% local functions
function y=exponential(a,x)
y=real(a(1).*exp(a(2)*x)+a(3));

function local_tick(h)
% Adjust the width of errorbars
% Based on errorbar_tick from Arnaud Laurent (2009) and Jerome Briot (Dut) 
%   http://www.developpez.net/forums/f148/environnements-developpement/matlab/
%   http://www.mathworks.com/matlabcentral/newsreader/author/94805
%   http://www.developpez.net/forums/u125006/dut/
%
% Adapted for data_majdak2013 by Piotr Majdak (2024)

w = diff(get(gca,'XLim'))/80;
x = get(h(1),'xdata');
x(4:9:end) = x(1:9:end)-w/2;
x(7:9:end) = x(1:9:end)-w/2;
x(5:9:end) = x(1:9:end)+w/2;
x(8:9:end) = x(1:9:end)+w/2;
set(h(1),'xdata',x(:));



