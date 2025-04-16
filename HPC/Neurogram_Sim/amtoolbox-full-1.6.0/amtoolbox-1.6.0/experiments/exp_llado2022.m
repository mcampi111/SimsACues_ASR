function varargout = exp_llado2022(varargin)
%EXP_LLADO2022 Experiments of Llado et al. (2022)
%
%   Usage: [] = exp_llado2022(flag)
%
%   EXP_LLADO2022(flag) reproduces figures and results of the study
%   from Llado et al. (2022).
%
%
%   To display Fig.5 use :
%
%     exp_llado2022('fig5');
%
%   To display Fig.6 use :
%
%     exp_llado2022('fig6');
%
%
%   See also: llado2022 exp_llado2022 demo_llado2022
%
%   References:
%     Lladó, Pedro, Hyvärinen, Petteri, and Pulkki, Ville. Auditory
%     model-based estimation of the effect of head-worn devices on frontal
%     horizontal localisation. Acta Acust., 6:1, 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_llado2022.php


%   #Requirement: NNET
%   #Author: Pedro Llado (2021)
%   #Author: Petteri Hyvärinen (2021)
%   #Author: Ville Pulkki (2021)
%   #Author: Clara Hollomey (2022): adaptations for AMT
%   #Author: Piotr Majdak (2023): if no NNET, load cacehd data or throw an error

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

definput.import={'amt_cache'};
definput.flags.type = {'missingflag', 'fig5', 'fig6'};

[flags,~]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},...
             definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.', ...
      upper(mfilename),flagnames);
end

%% Load precomputed binaural estimates

[~,kv]=amt_configuration; % get installed toolboxes

if flags.do_fig5
    % Load pretrained model
    if kv.nnet
      x = amt_load('llado2022', 'NN_pretrained.mat');
    else
        % if NNET not available, we load auxdata without the network to avoid a warning
      x = amt_load('llado2022', 'NN_pretrained_nonet.mat');
    end
    NN_pretrained = x.NN_pretrained;
    % Load extracted binaural features itd and ild features
    x_input = [NN_pretrained.x_itd;NN_pretrained.x_ild];

    %% Training set: all devices but the test device
    testDevice = 'F-Gecko';

    % Getting the test subset
    angle_id = NN_pretrained.angle_id;
    nAngles = NN_pretrained.nAngles;
    device_id = NN_pretrained.device_id; %string array
    nDevices = NN_pretrained.nDevices;
    y_output = NN_pretrained.y';

    if isoctave %This works only for testDevice =*F-Gecko' = 9
      temp_id = strcmp(device_id, testDevice); %can't find since device_id is not string array
      %testDevice_id = find(testDevice)
      testDevice_id = 9;
    else  %Matlab
      testDevice_id = find(device_id == testDevice);
    end
    testDevicePos = nAngles*(testDevice_id-1)+1:nAngles*(testDevice_id);

    x_test = x_input(:,testDevicePos);
    y_test = y_output(testDevicePos,:);

    %% evaluate pretrained model
    if kv.nnet
        % NNET available: to the actual evaluation
      y_hat = llado2022_evaluatenn(x_test,NN_pretrained);
      amt_cache('set','y_hat',y_hat);
    else
        % NNET not available: use cached data
      y_hat = amt_cache('get','y_hat',flags.cachemode);
      if isempty(y_hat)
        error('Cached data not available. Install the Deep Learning Toolbox to recalculate the figure.');
      end
    end

    y_est_dir = y_hat(:,1);
    y_est_uncertainty = y_hat(:,2);

    if ~isvector(y_est_dir)
        y_est_dir = mean(y_est_dir);
        y_est_uncertainty = mean(y_est_uncertainty);
    end

    plot_llado2022(y_est_dir,y_est_uncertainty,angle_id,y_test);
end

if flags.do_fig6
      % Load pretrained model
    if kv.nnet
      x = amt_load('llado2022', 'NN_pretrained.mat');
    else
        % if NNET not available, we load auxdata without the network to avoid a warning
      x = amt_load('llado2022', 'NN_pretrained_nonet.mat');
    end
    NN_pretrained = x.NN_pretrained;

        % NN weights analysis: perceived direction
    for j = 1:8
        for i = 1:10
            A(:,:) = abs(NN_pretrained.preTrained_dir(1,j,i).net.IW{1}(:,:))';
            B = zeros(1, 22);
            B(:) = abs(NN_pretrained.preTrained_dir(1,j,i).net.LW{2}(:,:))';
            T(i,:) = mean((A.*B)');
        end
        TOTAL(j,:) = mean(T);
    end
    TOTALavg = mean(TOTAL);
    TOTALavg = TOTALavg./(sum(TOTALavg));

    subplot(1,2,1);
    plot(TOTALavg(1:18),'b');
    hold on;

    subplot(1,2,2);
    plot(TOTALavg(19:end),'b');
    hold on;

      % NN weights analysis: position uncertainty
    clear A B T TOTAL TOTALavg
    for j = 1:8
        for i = 1:10
            A(:,:) = abs(NN_pretrained.preTrained_uncertainty(1,j,i).net.IW{1}(:,:))';
            B = zeros(1, 16);
            B(:) = abs(NN_pretrained.preTrained_uncertainty(1,j,i).net.LW{2}(:,:))';
            T(i,:) = mean((A.*B)');
        end
        TOTAL(j,:) = mean(T);
    end

    TOTALavg = mean(TOTAL);
    TOTALavg = TOTALavg./(sum(TOTALavg));

    subplot(1,2,1);
    plot(TOTALavg(1:18),'r');
    ylim([0.02 0.04]);
    xlim([0 19]);
    set(gca,'XTick',0:2:18);  % ITD weights are between 0.05 and 1.5 kHz
    set(gca,'XTickLabel',{'' '0.09' '' '0.26' '' '0.5' '' '0.9' '' '1.5'});
    title("ITD");
    ylabel('Relative weight');

    subplot(1,2,2);
    plot(TOTALavg(19:end),'r');
    ylim([0.02 0.04]);
    xlim([0 19]);
    set(gca,'XTick',0:2:19);  % ILD weights are between 1 and 18 kHz
    set(gca,'XTickLabel',{'' '1.2' '' '2' '' '3.2' '' '5' '' '7.8'});
    title("ILD");

    h=xlabel('Center frequency of cochlear frequency bands (kHz)');
    set(gca,'YTickLabel',[]);
    set(h,'Position',[-3 0.018875 -1]);
    legend("Perceived direction estimation", "Position uncertainty estimation",'Location','Southeast');

end


