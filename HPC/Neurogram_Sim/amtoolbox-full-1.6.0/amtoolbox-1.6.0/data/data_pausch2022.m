function [data,itd] = data_pausch2022(varargin)
%DATA_PAUSCH2022 Results from Pausch et al. (2022)
%
%   Usage: [data,itd] = data_pausch2022()
%          [data,itd] = data_pausch2022(flags)
%          weights = data_pausch2022('weights', flags)
%          features = data_pausch2022('features', flags)
%
%   Input parameters:
%     flags    : select the type of spatial transfer function (STF) and model, see below. 
%
%   Output parameters:
%     data: Structure with the STFs:
%
%           - id: the participant ID if flag is 'hrtf', 'hartf_front', or 'hartf_rear'
%
%           - sofa: individual STFs as a SOFA structure if flag is 'hrtf', 'hartf_front', or 'hartf_rear'
%
%     itd: Estimated ITDs for directions in the horizontal plane:
%
%          - itd_hor: ITDs (in s)
%
%          - itd_max: maximum ITD (in s)
%
%          - itd_arg_max_idx: index of the argument of the the maximum ITD
%
%          - itd_arg_max_phi: argument of the the maximum ITD (in deg)
%
%          - itd_hor_mean: direction-dependent mean ITDs across participants (in s)
%
%          - itd_hor_std: direction-dependent standard deviation of ITDs across participants (in s)
%
%          - bp_fc_low: lower cut-off frequency (Hz) of the bandpass filter applied before estimating the ITDs
%
%          - bp_fc_high: upper cut-off frequency (Hz) of the bandpass filter applied before estimating the ITDs
%
%
%     weights: Matrix of (M*P+1) x N polynomial regression weights (degree of P=4) 
%              to be applied on a subset of M=5 individual features. 
%              For the model pausch, N=4. For other models, N=1.
%
%     features: Individual anthropometric features and subject IDs as in Pausch et al. (2022)
%   
%
%   DATA_PAUSCH2022(...) returns spatial transfer function (STFs) and 
%   ITDs calculated for a specified model. 
%
%   DATA_PAUSCH2022('weights',...) returns the polynomial regression weights. 
%
%   DATA_PAUSCH2022('features',...) returns the individual features. 
%
%
%   The following STFs flags can be selected: 
%
%     'hrtf'         load individual HRTF datasets
%     'hartf_front'  load invidual front HARTF datasets (default)
%     'hartf_rear'   load invidual rear HARTF datasets
%
%
%   The following ITD model flags can be selected (only required if weights are 
%   selected): 
%
%     'pausch2022'     hybrid ITD model by Pausch et al. (2022) (default)
%     'kuhn1977'       analytic ITD model by Kuhn (1977)
%     'woodworth1954'  analytic ITD model by Woodworth and Schlosberg (1954)
%     'aaronson2014'   analytic ITD model by Woodworth and Schlosberg (1954) 
%                      extended by Aaronson and Hartmann (2014)
%
%
%   Additional key/value pairs include:
%
%     'bp_fc_low'      lower cut-off frequency (Hz) of the bandpass filter 
%                      applied before estimating the ITDs (default: []) [double]
%     'bp_fc_high'     upper cut-off frequency (Hz) of the bandpass filter 
%                      applied before estimating the ITDs (default: []) [double]
%
%   Further information on key/value pairs can be found in arg_pausch2022.m 
%
%
%   Requirements:
%   -------------
%
%   1) SOFA Toolbox from http://sourceforge.net/projects/sofacoustics 
%      for Matlab
%
%   2) Data in auxdata/pausch2022 (downloaded on the fly)
%
%   See also: pausch2022 exp_pausch2022
%
%   References:
%     F. Pausch, S. Doma, and J. Fels. Hybrid multi-harmonic model for the
%     prediction of interaural time differences in individual behind-the-ear
%     hearing-aid-related transfer functions. Acta Acust., 6:34, 2022.
%     
%     G. F. Kuhn. Model for the interaural time differences in the azimuthal
%     plane. The Journal of the Acoustical Society of America,
%     62(1):157--167, 1977.
%     
%     R. S. Woodworth and H. Schlosberg. Experimental psychology, Rev. ed.
%     Holt, Oxford, England, 1954.
%     
%     N. L. Aaronson and W. M. Hartmann. Testing, correcting, and extending
%     the Woodworth model for interaural time difference. The Journal of the
%     Acoustical Society of America, 135(2):817--823, 2014.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/data/data_pausch2022.php


%   #Author: Florian Pausch (2022): Integration in the AMT
%   #Author: Piotr Majdak (2023): Documentation expanded
%   #Author: Florian Pausch (2023): Code improvements

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% Parse flags and keyvals

definput.import = {'pausch2022','amt_cache'};
definput.flags.weights = {'no_weights','weights'};
definput.flags.features = {'no_features','features'};

[flags,kv] = ltfatarghelper({},definput,varargin);

%% Load the polynomial-regression weights

if flags.do_weights

    if flags.do_kuhn1977 || flags.do_woodworth1954 || flags.do_aaronson2014
        if flags.do_hrtf, fn = 'weights_hrtf_mod1_2plus'; end
        if flags.do_hartf_front, fn = 'weights_hartf_mod1_2plus'; end
        if flags.do_hartf_rear, fn = 'weights_hartf_mod1_2plus'; end
    end
    if flags.do_pausch2022
        if flags.do_hrtf, fn = 'weights_hrtf_mod3'; end
        if flags.do_hartf_front, fn = 'weights_fhartf_mod3'; end
        if flags.do_hartf_rear, fn = 'weights_rhartf_mod3'; end
    end

    data = amt_load('pausch2022','weights.mat',fn);
    data = data.(fn);

    amt_disp([mfilename,': Loaded polynomial regression weights for model ',flags.type_mod,...
        ' and ',flags.type_stf,'.'])

end

%% Neither weights nor features: Load the individual directional datasets as per flag type_stf

if ~flags.do_weights && ~flags.do_features

    switch flags.type_stf
        case 'hrtf'
            [itd,flag_stf,bp_fc_low,bp_fc_high] = amt_cache('get', ...
                ['hrtf_bp_',...
                num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], flags.cachemode);
        case 'hartf_front'
            [itd,flag_stf,bp_fc_low,bp_fc_high] = amt_cache('get', ...
                ['hartf_front_bp_',...
                num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], flags.cachemode);
        otherwise
            [itd,flag_stf,bp_fc_low,bp_fc_high] = amt_cache('get', ...
                ['hartf_rear_bp_',...
                num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], flags.cachemode);
    end

    fileNames = struct();
    num_part = 30;
    phi_vec = 0:180;

    if flags.do_hrtf
        for id=1:num_part
            fileNames(id).name = ['id',num2str(id,'%02d'),'_HRTF.sofa'];
        end
    elseif flags.do_hartf_front
        for id=1:num_part
            fileNames(id).name = ['id',num2str(id,'%02d'),'_HARTF_front.sofa'];
        end
    elseif flags.do_hartf_rear
        for id=1:num_part
           fileNames(id).name = ['id',num2str(id,'%02d'),'_HARTF_rear.sofa'];
        end
    end

    amt_disp([mfilename,': Loading ',upper(flags.type_stf),' datasets...'])
    data = struct('id',{},'sofa',{});
    for idx = 1:length(fileNames)
        data(idx).id = idx;
        data(idx).sofa = amt_load('pausch2022',fileNames(idx).name);
    end
    amt_disp([mfilename,': Finished loading of ',upper(flags.type_stf),' datasets.'])

    if isempty(flag_stf) || ~isequal(bp_fc_low,kv.bp_fc_low) || ~isequal(bp_fc_high,kv.bp_fc_high)

        % Estimate the ITDs for directions in the horizontal plane, and calculate mu+/-std
        idx_dir_hor = data(1).sofa.SourcePosition(:,2)==0;
        num_dir_hor = sum(idx_dir_hor);

        itd = struct('itd_hor',{},'itd_max',{},'itd_arg_max_idx',{},...
            'itd_arg_max_phi',{},'itd_hor_mean',{},'itd_hor_std',{});
        itd(idx).itd_hor = zeros(num_dir_hor,1);

        amt_disp([mfilename,': Estimating ITDs between ',num2str(kv.bp_fc_low),...
            '-',num2str(kv.bp_fc_high),' Hz in ',upper(flags.type_stf),' datasets...'])
        itd_hor = zeros(num_dir_hor,num_part);
        fs = data(1).sofa.Data.SamplingRate;
        for idx=1:num_part
            data_hor = data(idx).sofa.Data.IR(idx_dir_hor,:,:);

            % apply low-pass pre-filter
            filter_order = 10;
            f_cutoff = 1.6e3;
            
            h_lp = fdesign.lowpass('n,f3db',filter_order,f_cutoff,fs);
            Filter.Hd = design(h_lp,'butter');
            
            data_filt = filter(Filter.Hd, data_hor, 3);
           
            % estimate ITDs
            itd(idx).itd_hor = itdestimator(fliplr(data_filt),...
                'pausch2022',...
                'fs',fs,...
                'lower_cutfreq',500,...
                'upper_cutfreq',1.5e3);

            % remove ITD outliers in HRTF datasets measured from participant 8
            if idx==8 && strcmp(flags.type_stf,'hrtf')
                itd(idx).itd_hor(18:21) = NaN;
                temp = itd(idx).itd_hor;
                x = 1:numel(temp);
                itd(idx).itd_hor(18:21) = pchip(x(~isnan(temp)), temp(~isnan(temp)), x(isnan(temp)));
            end

            % store max(itd)
            [itd(idx).itd_max,itd(idx).itd_arg_max_idx] = max(itd(idx).itd_hor);

            % store arg_max_phi(itd)
            itd(idx).itd_arg_max_phi = phi_vec(itd(idx).itd_arg_max_idx);

            % temporarily store ITD data for the calculation of mean/std
            itd_hor(:,idx) = itd(idx).itd_hor;

        end

        [itd.itd_hor_mean] = deal(mean(itd_hor,2));
        [itd.itd_hor_std] = deal(std(itd_hor,0,2));

        amt_disp([mfilename,': Finished ITD estimations between ',num2str(kv.bp_fc_low),...
            '-',num2str(kv.bp_fc_high),' Hz in ',upper(flags.type_stf),' datasets.'])

        switch flags.type_stf
            case 'hrtf'
                amt_cache('set', ['hrtf_bp_',...
                    num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], ...
                    itd, flags.type_stf, kv.bp_fc_low, kv.bp_fc_high);
            case 'hartf_front'
                amt_cache('set', ['hartf_front_bp_',...
                    num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], ...
                    itd, flags.type_stf, kv.bp_fc_low, kv.bp_fc_high);
            otherwise
                amt_cache('set', ['hartf_rear_bp_',...
                    num2str(kv.bp_fc_low),'_',num2str(kv.bp_fc_high),'_Hz'], ...
                    itd, flags.type_stf, kv.bp_fc_low, kv.bp_fc_high);
        end

    end

end

%% Load the individual features

if flags.do_features
    data = amt_load('pausch2022','features.mat');
    data = data.features; 

    if isempty(data)
          amt_disp('The features are not available when offline.')
    end
end

end
