function varargout = exp_laback2023(varargin)
%EXP_LABACK2023 Figures from Laback (2023)
%
%   Usage: exp_laback2023('fig5')
%          exp_laback2023('fig5','i_cond',X)
%
%   EXP_LABACK2023('fig5') predicts the effect of various types of precursors
%   on ILD-based perceived lateralization. It is based on AN model by
%   Smalt et al. (2014), which is a binaural version of the
%   AN model by Zilany et al. (2014), that
%   involves ipsi- and contralateral cochlear compression control via
%   efferent feedback.
%
%   EXP_LABACK2023('fig5','i_cond',X); displays predictions for the specific
%   condition, with X being:
%
%     1 : Condition 'noP'
%
%     2 : Condition 'Central'
%
%     3 : Condition 'Ipsi'
%
%     4 : Condition 'Contra'
%
%
%   Examples:
%   ---------
%
%   To display Fig.5, which shows the predictions for all four models use :
%
%     exp_laback2023('fig5');
%
%   Note*: The last row of the AMT's Fig. 5 shows results drastically different
%   than those in Laback's Fig. 5. The results in other rows also are not
%   fully compliant. This is a bug and the AMT Team is working on that
%   (see Issue `#247 <https://sourceforge.net/p/amtoolbox/bugs/247/).
%   The model status is thus "untrusted" for the moment.
%
%   See also: laback2023 smalt2014 zilany2014
%
%   References:
%     B. Laback. Contextual lateralization based on interaural level
%     differences is preshaped by the auditory periphery and predominantly
%     immune against sequential segregation. Trends in Hearing,
%     27:23312165231171988, 2023. PMID: 37161352.
%     
%     C. J. Smalt, M. G. Heinz, and E. A. Strickland. Modeling the
%     Time-Varying and Level-Dependent Effects of the Medial Olivocochlear
%     Reflex in Auditory Nerve Responses. Journal of the Association for
%     Research in Otolaryngology, 15(2):159--173, Apr. 2014.
%     
%     M. S. A. Zilany, I. C. Bruce, and L. H. Carney. Updated parameters and
%     expanded simulation options for a model of the auditory periphery. The
%     Journal of the Acoustical Society of America, 135(1):283--286, Jan.
%     2014.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_laback2023.php


% #Author: Bernhard Laback (2022): Original implementation
% #Author: Clara Hollomey (2023): Adaptations for AMT
% #Author: Alejandro Osses (2023): further adaptations for AMT 1.4
% #Author: Joonas Guevara (2023): Clearer plotting
% #Author: Piotr Majdak (2023): Rewrite to be able to debug in the future.

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

definput.import={'amt_cache'}; % setup the usage of cache mode flags
definput.flags.type = {'missingflag','fig5','fig5ab','fig5cd'};
definput.keyvals.i_cond = [1 2 3 4];
[flags,kv]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end

modelreps = 3;
fibtype_str = {'low-SR', 'mid-SR', 'high-SR'};
flags_MOC={'no_MOC','MOC'};
ILD_vector = 0:2:10; % vector of ILD's
num_ILD = length(ILD_vector); % remove kv.NrILD
idxs_cond = kv.i_cond;
num_cond = length(idxs_cond);

%% Predictions based on the model Smalt et al. (2014)
if flags.do_fig5 || flags.do_fig5ab

  [Results_Ave_LOW, Results_Ave_MID, Results_Ave_HIGH,...
   Results_STD_LOW, Results_STD_MID, Results_STD_HIGH] = ...
      amt_cache('get','fig5 model smalt2014',flags.cachemode);

  if isempty(Results_Ave_LOW)

    expdefinput.import = {'laback2023'};
    expdefinput.importdefaults={'exp1'};
    [fg,kv]  = ltfatarghelper({},expdefinput,{}); % obtained the keyvalues

    % Taking some variables out of the keyvalues (easier for debugging)
    model = kv.model;
    fs = kv.fs;
    Modeldelay = 240;   %Delay between stimulus and model response (in samples) [default: 240]

    % Define time vectors for P and T
    nvec = 0: 1/fs : kv.DurN-1/fs;
    tvec = 0: 1/fs : kv.DurT-1/fs;

    % Memory allocation for results matrices
    ResultMatrixvecLOW  = zeros(modelreps,num_cond*2,num_ILD);
    ResultMatrixvecMID  = zeros(modelreps,num_cond*2,num_ILD);
    ResultMatrixvecHIGH = zeros(modelreps,num_cond*2,num_ILD);
    NrFiberTypes = length(kv.spontvec);

    for i_fibtype=1:NrFiberTypes %three fiber types (based on SR)
        amt_disp(sprintf('Model:smalt2014; Fibertype=%s', fibtype_str{i_fibtype}));

        for i_modelreps=1:modelreps %loop for repetition
          amt_disp(sprintf('\tRepetition %.0f of %.0f', i_modelreps,modelreps));

            % Variables containing the results per condition and ILD.
          ResultMatrix = nan(num_cond*2,num_ILD); % 8=2*4 conditions
          for i_cond = idxs_cond %loop for four stimulus conditions (1: noP, 2: Central, 3: Ipsi, 4: Contra)

            diffvec = zeros(2, num_ILD);
            switch i_cond %Define precursor conditions
              case 1 % no precursor
                precmode = 0; %precursor mode: 0 = without precursor, 1 = with precursor
                ILDNoise = 0; %ILD of precursor noise, positive value favoring left ear
                PrecITD_side = [];
                PrecITD_t= [];
              case 2 % diotic precursor
                precmode = 1;
                ILDNoise = 0;
                PrecITD_side = 0;
                PrecITD_t=0;
              case 3 % precursor favoring LEFT ear (ipsilateral, because target is always left leading)
                precmode = 1;
                ILDNoise = kv.PrecILD;
                PrecITD_side = -1;
                PrecITD_t=kv.PrecITD;
              case 4 % precursor favoring right ear (contralater, because target is always left leading)
                precmode = 1;
                ILDNoise = -1*kv.PrecILD;
                PrecITD_side = 1;
                PrecITD_t=kv.PrecITD;
            end

            ILDNoiseLin = 10^(ILDNoise/20);
            [stimTarg, ~, noiseILDvec] = sig_laback2023(precmode,...
                tvec, nvec, ILDNoiseLin, PrecITD_side, PrecITD_t, model, 'SubExp',0);

              % Run the models
            for MOCstat=1:2 % NoMOC and MOC
              for i_ILD=1:num_ILD
                ILD = ILD_vector(i_ILD); % dB, for calculating all ILDs around zero: add -12
                ILD_linear = 10^(ILD/20);
                  %Apply ILD
                stim = stimTarg*sqrt(ILD_linear); %positive ILD value enhances left ear
                stim(:,2) = stimTarg/sqrt(ILD_linear);
                  % add precursor if required
                if  precmode == 1 % used in cond=2, 3, 4, zilany2014
                    targR = stim(:,2);
                    stim = [noiseILDvec(:,1); kv.gapvec; stim(:,1)]; %stimnoise
                    stim(:,2) = [noiseILDvec(:,2); kv.gapvec; targR];
                end
                output = laback2023(stim,fs,'argimport',fg,kv,'fiberType',i_fibtype,'precmode',precmode, ...
                    'Modeldelay',Modeldelay,'Onset',kv.Onset, ...
                    'noiseILDvec',noiseILDvec,'length_stimTarg',length(stimTarg), ... % flags from the stimuli
                    flags_MOC{MOCstat});
                diffvec(MOCstat, i_ILD) = output.diffvec;
              end % for i_ILD
            end % for MOCstat

            ResultMatrix(i_cond*2-1:i_cond*2,:) = diffvec(1:2,:);
          end % i_cond

          switch i_fibtype %various P conditions
              case 1
                ResultMatrixvecLOW(i_modelreps,:,:)=ResultMatrix;
              case 2
                ResultMatrixvecMID(i_modelreps,:,:)=ResultMatrix;
              case 3
                ResultMatrixvecHIGH(i_modelreps,:,:)=ResultMatrix;
          end
        end %i_modelreps
    end %i_fibtype

    %% Calculate Mean and SD across model repetitions
    Results_Ave_LOW = zeros(num_ILD, length(ResultMatrix(:,1)));
    Results_STD_LOW = Results_Ave_LOW;
    Results_Ave_MID = Results_Ave_LOW;
    Results_STD_MID = Results_Ave_LOW;
    Results_Ave_HIGH = Results_Ave_LOW;
    Results_STD_HIGH = Results_Ave_LOW;

    for ILDidx=1:i_ILD
      for condvec=1:length(ResultMatrix(:,1))
        Results_Ave_LOW(ILDidx,condvec) = mean(ResultMatrixvecLOW(:,condvec,ILDidx));
        Results_STD_LOW(ILDidx,condvec) = std(ResultMatrixvecLOW(:,condvec,ILDidx));
        Results_Ave_MID(ILDidx,condvec) = mean(ResultMatrixvecMID(:,condvec,ILDidx));
        Results_STD_MID(ILDidx,condvec) = std(ResultMatrixvecMID(:,condvec,ILDidx));
        Results_Ave_HIGH(ILDidx,condvec) = mean(ResultMatrixvecHIGH(:,condvec,ILDidx));
        Results_STD_HIGH(ILDidx,condvec) = std(ResultMatrixvecHIGH(:,condvec,ILDidx));
      end
    end

    amt_cache('set','fig5 model smalt2014',Results_Ave_LOW, Results_Ave_MID, Results_Ave_HIGH,...
      Results_STD_LOW, Results_STD_MID, Results_STD_HIGH);
  end

    %Plotting_MOC_noLSO
  W=[83 17 0]; %Weighting Coefficients for Low-, Mid-, and High-SR fibers
  axy=[-15 75; -29 149; -29 149; -15 75];
  tit='NoPL\_MOC\_NoLSO';
  local_plot(ILD_vector, W, axy, tit, ...
    Results_Ave_LOW(:,2:2:8), Results_Ave_MID(:,2:2:8), Results_Ave_HIGH(:,2:2:8), ...
    Results_STD_LOW(:,2:2:8), Results_STD_MID(:,2:2:8), Results_STD_HIGH(:,2:2:8));

    %Plotting_noMOC_noLSO
  W=[66 0 34]; %Weighting Coefficients for Low-, Mid-, and High-SR fibers
  axy=[-15 75; -15 75; -15 75; -15 75];
  tit='NoPL\_NoMOC\_NoLSO';
  local_plot(ILD_vector, W, axy, tit, ...
    Results_Ave_LOW(:,1:2:7), Results_Ave_MID(:,1:2:7), Results_Ave_HIGH(:,1:2:7), ...
    Results_STD_LOW(:,1:2:7), Results_STD_MID(:,1:2:7), Results_STD_HIGH(:,1:2:7));

end % if fig5ab



%% Prediction based on the model Zilany et al. (2014)
if flags.do_fig5 || flags.do_fig5cd

  [Results_Ave_LOW, Results_STD_LOW, Results_Ave_MID, Results_STD_MID,...
   Results_Ave_HIGH, Results_STD_HIGH] = ...
          amt_cache('get','fig5 model zilany2014',flags.cachemode);

  if isempty(Results_Ave_LOW)
    expdefinput.import = {'laback2023'};
    expdefinput.importdefaults={'exp2'};
    [fg,kv]  = ltfatarghelper({},expdefinput,{}); % obtained the keyvalues

    % Taking some variables out of the keyvalues (easier for debugging)
    fs = kv.fs;
    Modeldelay = 400;   %Delay between stimulus and model response (in samples) [default: 240]

    % Define time vectors for P and T
    nvec = 0: 1/fs : kv.DurN-1/fs;
    tvec = 0: 1/fs : kv.DurT-1/fs;

    % Memory allocation for results matrices
    ResultMatrixvecLOW  = zeros(modelreps,num_cond*2,num_ILD);
    ResultMatrixvecMID  = zeros(modelreps,num_cond*2,num_ILD);
    ResultMatrixvecHIGH = zeros(modelreps,num_cond*2,num_ILD);

    NrFiberTypes = length(kv.spontvec);

    for i_fibtype=1:NrFiberTypes %three fiber types (based on SR)
      amt_disp(sprintf('Model: zilany2014; Fibertype=%s', fibtype_str{i_fibtype}));
      for i_modelreps=1:modelreps %loop for repetition
        amt_disp(sprintf('\tRepetition %.0f of %.0f', i_modelreps,modelreps));
          % Variables containing the results per condition and ILD.
        ResultMatrix = nan(num_cond*2,num_ILD); % 8=2*4 conditions
        for i_cond = idxs_cond %loop for four stimulus conditions (1: no T, 2:diotic P, 3: ipsi P, 4: contra P)

          diffvec = zeros(2, num_ILD);
            %Define precursor conditions
          switch i_cond
              case 1 % no precursor
                  precmode = 0; %precursor mode: 0 = without precursor, 1 = with precursor
                  ILDNoise = 0; %ILD of precursor noise, positive value favoring left ear
                  ILDNoiseLin = 10^(ILDNoise/20);
                  PrecITD_side = [];
                  PrecITD_t= [];
              case 2 % diotic precursor
                  precmode = 1;
                  ILDNoise = 0;
                  ILDNoiseLin = 10^(ILDNoise/20);
                  PrecITD_side = 0;
                  PrecITD_t=0;
              case 3 % precursor favoring LEFT ear (ipsilateral, because target is always left leading)
                  precmode = 1;
                  ILDNoise = kv.PrecILD;
                  ILDNoiseLin = 10^(ILDNoise/20);
                  PrecITD_side = -1;
                  PrecITD_t=kv.PrecITD;
              case 4 % precursor favoring right ear (contralater, because target is always left leading)
                  precmode = 1;
                  ILDNoise = kv.PrecILD*-1;
                  ILDNoiseLin = 10^(ILDNoise/20);
                  PrecITD_side = 1;
                  PrecITD_t=kv.PrecITD;
          end

          [stimTarg, ~, noiseILDvec] = sig_laback2023(precmode,...
              tvec, nvec, ILDNoiseLin, PrecITD_side, PrecITD_t, kv.model, 'SubExp',0);

          %% Run the models
          for MOCstat=1:2 % noMOC and MOC
            for i_ILD=1:num_ILD
                ILD = ILD_vector(i_ILD); % dB, for calculating all ILDs around zero: add -12
                ILD_linear = 10^(ILD/20);
                  %Apply ILD
                stim = stimTarg*sqrt(ILD_linear); %positive ILD value enhances left ear
                stim(:,2) = stimTarg/sqrt(ILD_linear);
                  % add precursor if required
                if  precmode == 1 % used in cond=2, 3, 4, zilany2014
                    targR = stim(:,2);
                    stim = [noiseILDvec(:,1); kv.gapvec; stim(:,1)]; %stimnoise
                    stim(:,2) = [noiseILDvec(:,2); kv.gapvec; targR];
                end
                output = laback2023(stim,fs,'argimport',fg,kv,'fiberType',i_fibtype,'precmode',precmode, ...
                    'Modeldelay',Modeldelay,'Onset',kv.Onset, ...
                    'noiseILDvec',noiseILDvec,'length_stimTarg',length(stimTarg), ... % flags from the stimuli
                    flags_MOC{MOCstat});
                diffvec(MOCstat, i_ILD) = output.diffvec;

            end % for i_ILD
          end % for MOCstat

          ResultMatrix(i_cond*2-1:i_cond*2,:) = diffvec(1:2,:);

        end % i_cond

          %various P conditions
        switch i_fibtype
          case 1
            ResultMatrixvecLOW(i_modelreps,:,:)=ResultMatrix;
          case 2
            ResultMatrixvecMID(i_modelreps,:,:)=ResultMatrix;
          case 3
            ResultMatrixvecHIGH(i_modelreps,:,:)=ResultMatrix;
        end

      end %repetition
    end % i_fibtype

    %% Calculate Mean and SD across model repetitions
    Results_Ave_LOW = zeros(i_ILD, length(ResultMatrix(:,1)));
    Results_STD_LOW = zeros(i_ILD, length(ResultMatrix(:,1)));
    Results_Ave_MID = zeros(i_ILD, length(ResultMatrix(:,1)));
    Results_STD_MID = zeros(i_ILD, length(ResultMatrix(:,1)));
    Results_Ave_HIGH = zeros(i_ILD, length(ResultMatrix(:,1)));
    Results_STD_HIGH = zeros(i_ILD, length(ResultMatrix(:,1)));

    for ILDidx=1:i_ILD
        for condvec=1:length(ResultMatrix(:,1))
          Results_Ave_LOW(ILDidx,condvec) = mean(ResultMatrixvecLOW(:,condvec,ILDidx));
          Results_STD_LOW(ILDidx,condvec) = std(ResultMatrixvecLOW(:,condvec,ILDidx));
          Results_Ave_MID(ILDidx,condvec) = mean(ResultMatrixvecMID(:,condvec,ILDidx));
          Results_STD_MID(ILDidx,condvec) = std(ResultMatrixvecMID(:,condvec,ILDidx));
          Results_Ave_HIGH(ILDidx,condvec) = mean(ResultMatrixvecHIGH(:,condvec,ILDidx));
          Results_STD_HIGH(ILDidx,condvec) = std(ResultMatrixvecHIGH(:,condvec,ILDidx));
        end
    end

    amt_cache('set','fig5 model zilany2014', ...
      Results_Ave_LOW, Results_STD_LOW, Results_Ave_MID, Results_STD_MID,...
      Results_Ave_HIGH, Results_STD_HIGH);
  end
    %Plotting_MOC_noLSO
  W=[70 0 30]; %Weighting Coefficients for Low, Mid, and High-SR fibers
  axy=[-4.9 24.9; -15 75; -4.9 24.9; -4.9 24.9];
  tit='PL\_NoMOC\_NoLSO';
  local_plot(ILD_vector, W, axy, tit, ...
    Results_Ave_LOW(:,2:2:8), Results_Ave_MID(:,2:2:8), Results_Ave_HIGH(:,2:2:8), ...
    Results_STD_LOW(:,2:2:8), Results_STD_MID(:,2:2:8), Results_STD_HIGH(:,2:2:8));

    %Plotting_noMOC_LSO
  W=[73 27 0]; %Weighting Coefficients for Low, Mid, and High-SR fibers
  axy=[-15 75; -15 75; -15 75; -15 75];
  tit='PL\_NoMOC\_LSO';
  local_plot(ILD_vector, W, axy, tit, ...
    Results_Ave_LOW(:,1:2:7), Results_Ave_MID(:,1:2:7), Results_Ave_HIGH(:,1:2:7), ...
    Results_STD_LOW(:,1:2:7), Results_STD_MID(:,1:2:7), Results_STD_HIGH(:,1:2:7));

end % if fig5cd

function local_plot(ILDvec, W, axy, tit, ...
    Results_Ave_LOW, Results_Ave_MID, Results_Ave_HIGH, ...
    Results_STD_LOW, Results_STD_MID, Results_STD_HIGH)

      %Calculate Weighted Mean
    Results_Ave_WMean = ( Results_Ave_LOW*W(1) + Results_Ave_MID*W(2) + Results_Ave_HIGH*W(3) ) / sum(W);
    Results_STD_WMean = ( Results_STD_LOW*W(1) + Results_STD_MID*W(2) + Results_STD_HIGH*W(3) ) / sum(W);

    figure('Name', 'PL_NoMOC_NoLSO','Position',[0 300 1300 250]);
      %Low-SR fibers
    subplot(1,4,1);
    hold on; box on;
    errorbar(ILDvec,Results_Ave_LOW(:,1)', Results_STD_LOW(:,1)', 'b'); %NoPrec
    errorbar(ILDvec,Results_Ave_LOW(:,2)', Results_STD_LOW(:,2)', 'r'); %Diotic
    errorbar(ILDvec,Results_Ave_LOW(:,3)', Results_STD_LOW(:,3)', 'g'); %Ipsi
    errorbar(ILDvec,Results_Ave_LOW(:,4)', Results_STD_LOW(:,4)', 'c'); %Contra
    axis([min(ILDvec)-1.5 max(ILDvec)+1.5 axy(1,:)]);
    title('LOW-SR fibers');
    legend('NoP','Diotic','Ipsi','Contra', 'Location','northwest');

      %Mid-SR fibers
    subplot(1,4,2);
    hold on; box on;
    errorbar(ILDvec,Results_Ave_MID(:,1)', Results_STD_MID(:,1)', 'b'); %NoPrec
    errorbar(ILDvec,Results_Ave_MID(:,2)', Results_STD_MID(:,2)', 'r'); %Diotic
    errorbar(ILDvec,Results_Ave_MID(:,3)', Results_STD_MID(:,3)', 'g'); %Ipsi
    errorbar(ILDvec,Results_Ave_MID(:,4)', Results_STD_MID(:,4)', 'c'); %Contra
    axis([min(ILDvec)-1.5 max(ILDvec)+1.5 axy(2,:)]);
    title('MID-SR fibers')

      %High-SR fibers
    subplot(1,4,3);
    hold on; box on;
    errorbar(ILDvec,Results_Ave_HIGH(:,1)', Results_STD_HIGH(:,1)', 'b'); %NoPrec
    errorbar(ILDvec,Results_Ave_HIGH(:,2)', Results_STD_HIGH(:,2)', 'r'); %Diotic
    errorbar(ILDvec,Results_Ave_HIGH(:,3)', Results_STD_HIGH(:,3)', 'g'); %Ipsi
    errorbar(ILDvec,Results_Ave_HIGH(:,4)', Results_STD_HIGH(:,4)', 'c'); %Contra
    axis([min(ILDvec)-1.5 max(ILDvec)+1.5 axy(3,:)]);
    title('HIGH-SR fibers')

      %Weighted Mean
    subplot(1,4,4);
    hold on; box on;
    errorbar(ILDvec,Results_Ave_WMean(:,1)', Results_STD_WMean(:,1)', 'b'); %NoPrec
    errorbar(ILDvec,Results_Ave_WMean(:,2)', Results_STD_WMean(:,2)', 'r'); %Diotic
    errorbar(ILDvec,Results_Ave_WMean(:,3)', Results_STD_WMean(:,3)', 'g'); %Ipsi
    errorbar(ILDvec,Results_Ave_WMean(:,4)', Results_STD_WMean(:,4)', 'c'); %Contra
    axis([min(ILDvec)-1.5 max(ILDvec)+1.5 axy(4,:)]);
    title('Weighted Mean')

    han = axes(gcf, 'visible','off');
    if isoctave
      ylabel(han,'ILD_{AN} (spikes/s)');
      xlabel(han, 'Target ILD (dB)');
    else
      han.Title.Visible='on';
      han.XLabel.Visible='on';
      han.YLabel.Visible='on';
      ylabel(han, 'ILD_{AN} (spikes/s)');
      xlabel(han, 'Target ILD (dB)');
    end
    title(han, tit);


