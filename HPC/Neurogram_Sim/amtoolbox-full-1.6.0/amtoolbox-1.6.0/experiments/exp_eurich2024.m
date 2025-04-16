function exp_eurich2024(varargin)
%EXP_EURICH2024 Reproduction of results from Eurich et al. (2024)
%   Usage: data = exp_eurich2024(flag)
%
%   EXP_EURICH2024(flag) reproduces figures of the study from
%   Eurich et al. (2024)
%
%   The following flag can be specified:
%
%     'fig2a'   Reproduces Figure 2;
%               Subjective quality ratings and instrumental quality predictions by eMoBi-Q
%               for the exemplary database from Flessner et al. (2017), Experiment 1.
%               Blue diamonds and black circles symbolize the overall quality ratings 
%               determined by the binaural and monaural paths, respectively.
%
%
%   Note that currently only Fig. 2a can be reproduced because the origin and/or the 
%   availability of the required data is unclear yet.
%
%   Examples:
%   ---------
%
%   To display Figure 2a use :
%
%     exp_eurich2024('fig2a');
%
%
%   See also: eurich2024 eurich2024_backend
%
%   References:
%     J.-H. Fleßner, R. Huber, and S. D. Ewert. Assessment and prediction of
%     binaural aspects of audio quality. Journal of the Audio Engineering
%     Society, 65(11):929--942, Nov. 2017.
%     
%     B. Eurich, S. D. Ewert, M. Dietz, and T. Biberger. A computationally
%     efficient model for combined assessment of monaural and binaural audio
%     quality. Journal of the Audio Engineering Society, 100(4):2381--2396,
%     June 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_eurich2024.php


%   #Author: Bernhard Eurich (2024): Original implementation and integration in the AMT
%   #Author: Piotr Majdak (2024): Small adaptions for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%% ------ Check input options --------------------------------------------


definput.import={'amt_cache'};

definput.flags.type = {'missingflag','fig2a'};
definput.flags.plot = {'plot','no_plot'};

definput.keyvals.FontSize = 9;
definput.keyvals.MarkerSize = 3;
definput.import={'amt_cache'};

flags  = ltfatarghelper({'FontSize','MarkerSize'},definput,varargin);

if flags.do_missingflag
    flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
        sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
    error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end


%% ------ FIGURE 2a -----------------------------------------------------------
if flags.do_fig2a
    %any calculations associated to Figure 2 in the publication

    desired_filters_per_ERB = 1;

    % ======= PROCESSING Fleßner ex. 1 ==========
    filename = 'features_fig2_fig5_fig6_Flessner_Exp1';
    features_Flessner_Exp1 = amt_cache('get',filename,flags.cachemode); 

    if isempty(features_Flessner_Exp1)

          % process signals of experiment 1
        cSigs = {'ATL10s','DD10s','PN10s','PNL10s','PNH10s','RB10s'};
        cAlgos = {'_anchor','_1_ASWILD_2','_1_ASWITD_100','_1_POS_5' ,'_1_TIT_5',...
          '_2_ASWILD_3','_2_ASWITD_200','_2_POS_10','_2_TIT_10',...
          '_3_ASWILD_5','_3_ASWITD_400','_3_POS_20','_3_TIT_20',...
          '_K_ASWILD_3_ASWITD200','_K_ASWILD_3_POS10','_K_ASWILD_3_TIT10',...
          '_K_ASWITD_400_POS10','_K_ASWITD_400_TIT10','_K_POS_10_TIT10'};

        for ii = length(cSigs):-1:1
            % reference signal
          [mRef] = amt_load('flessner2017',[cSigs{ii} '_ref.wav']);
          mRef = mRef .* 10^(15/20);

          for jj = 1:length(cAlgos)
              % test signal
            [mTest,fs] = amt_load('flessner2017',[cSigs{ii} cAlgos{jj} '.wav']);
            mTest = mTest .* 10^(15/20);
            features_Exp1(ii,jj,:) = eurich2024(mRef, mTest, fs);
            disp([num2str(ii) '/6  ' num2str(jj) '/19'])
          end
        end      
        features_Flessner_Exp1 = features_Exp1;         
        amt_cache('set',filename, features_Flessner_Exp1);
    end

    if flags.do_plot

        % Plotting
        specs.FontSize = 15;
        specs.MarkerSize = 4;
        specs.Outer_Position = [0.1 0.2 0.3 0.55];
        specs.bin_mon = 1;

        % ========= EVALUATION FLESSNER EXP. =========

        features_fig2_fig5_fig6_Flessner_Exp1 = features_Flessner_Exp1;
        testRowIdx = [1:6];
        testColIdx = 1:19;

        subj_scores = amt_load('eurich2024','subj_Flessner_Exp1.mat');
        subjMeanAllTest = subj_scores.subjMeanAll(testRowIdx,testColIdx);
        subj_mean_Exp1 = subjMeanAllTest(:);

          % backend processing
        [obj_mon, obj_bin] = eurich2024_backend(features_fig2_fig5_fig6_Flessner_Exp1,desired_filters_per_ERB);
        bin_tmp = obj_bin;
        mon_tmp = obj_mon;
        bin_tmp(isnan(bin_tmp)) = 0;
          % select lower quality component
        [obj_meas_Exp1, idx_Exp1]= min([bin_tmp(:) mon_tmp(:) ],[],2);


        % *****************Accuracy measure*****************************************************
        corrcoeff_Exp1=corrcoef(subj_mean_Exp1,obj_meas_Exp1);
        corrcoeff_Exp1=corrcoeff_Exp1(2,1);

        % *****************Monotonicity measure**************************************************
        rank_corr_Exp1 = corr(subj_mean_Exp1,obj_meas_Exp1,'Type','Spearman');       
        b = regress(subj_mean_Exp1,[obj_meas_Exp1 ones(size(obj_meas_Exp1))]);
        obj_meas_Exp1 = [obj_meas_Exp1 ones(size(obj_meas_Exp1))]*b;
        obj_meas_Exp1(obj_meas_Exp1<0)=0;
        obj_meas_Exp1(obj_meas_Exp1>100)=100;

        corrcoeff_Exp1=round(corrcoeff_Exp1*100)/100;
        corrcoef_rank_Exp1=round(rank_corr_Exp1*100)/100;
        text_pear=['$r_{Pearson}$=',num2str(corrcoeff_Exp1)];
        text_rank=['$r_{rank}$=',num2str(corrcoef_rank_Exp1)];
       
        % ============== PLOTTING Exp 1==============
        hfigure=figure('Name','fig2','units','normalized','outerposition',specs.Outer_Position);
        x_int=[0,100];
        y_int=[0,100];

        specs.MarkerSize = 6;

        if exist('idx_Exp1','var') && specs.bin_mon == 1
            p_intersec=plot(x_int,y_int,'k','LineWidth',3);
            hold on
            test = 1:length(idx_Exp1);
            mon_lower = test(idx_Exp1==2);
            bin_lower = test(idx_Exp1==1);
            p1= plot(subj_mean_Exp1(mon_lower),obj_meas_Exp1(mon_lower),'ko','MarkerSize',specs.MarkerSize,'LineWidth',3);
            hold on;
            p1= plot(subj_mean_Exp1(bin_lower),obj_meas_Exp1(bin_lower),'bd','MarkerSize',specs.MarkerSize,'LineWidth',3);
        elseif specs.bin_mon == 2;
            p1= plot(subj_mean_Exp1,obj_meas_Exp1,'bd','MarkerSize',specs.MarkerSize,'LineWidth',3);
        else
            p1= plot(subj_mean_Exp1,obj_meas_Exp1,'ko','MarkerSize',specs.MarkerSize,'LineWidth',3);
        end

        set(p1,'markerfacecolor',[1 1 1]);

        ylim([0 100])
        t_xticks=[0,20,40,60,80,100];
        t_yticks=[0,20,40,60,80,100];
        set(gca,'xtick',t_xticks);
        set(gca,'XTicklabel',{'0','20','40','60','80','100'});
        set(gca,'ytick',t_yticks);
        set(gca,'YTicklabel',{'0','20','40','60','80','100'});

        tit_lab=title('Flessner et al. (2017), Exp. 1','FontSize',specs.FontSize);
        set(gca,'box','off')

        xlabel('Subjective rating')
        ylabel('Objective rating')

    end

end


