function data = data_heeringa2024(varargin) 
%DATA_HEERINGA2024 Single-unit responses from the auditory nerve of gerbils
%   Usage: data = data_heeringa2024(flag);
%          data = data_heeringa2024(flag, animalID);
%          data = data_heeringa2024(.., 'unit', unit);
%
%   DATA_HEERINGA2024(flag) plots various figures 
%   from Heeringa (20204) or displays tables. 
%
%   data = DATA_HEERINGA2024(flag) returns the corresponding data to a variable.
% 
%   The following flags can be provided:
%
%     'list'    Returns a cell array with available animal IDs. The animal 
%               ID can be used as animalID to retrieve data and info 
%               and plot specific figures. 
%
%     'info'    Returns the information about an animal. Provide animalID*
%               to specify the animal (default: G220922). For more details, 
%               see exp.info in https://datadryad.org/stash/downloads/file_stream/3070542.
%
%     'data'    Returns the responses from an animal. Provide animalID*
%               to specify the animal (default: G220922). The output 
%               data is structure containing all the data and metadata 
%               structured by units and recording types. 
%               Note that data of some animals are stored in multiple batches
%               to keep the file sizes below 1 GB. All data from all batches
%               are returned. For more details, 
%               see exp.data in https://datadryad.org/stash/downloads/file_stream/3070542.
%
%     'fig3'    Reproduce Fig. 3:
%               Plot the animal's hearing sensitivity as derived from the 
%               ABR to chirps as a function of the animal's age in months.
%               Males and females are plotted separately. 
%
%     'fig4'    Reproduce Fig. 4:
%               Plot the waveform shapes of a single unit. Default is 
%               the animal G220922 and unit 12 (3p_607).
%
%     'fig5a'   Reproduce Fig. 5a:
%               Plot all rate-level functions from an animal. Default is the 
%               animal G220922. 
%
%     'fig5b'   Reproduce Fig. 5b:
%               Plot a PSTH from the animal G220908 and unit 23
%               (3p_181) at the test level of 20 dB above threshold.
%
%     'fig6'    Reproduce Fig. 6:
%               Plot BF vs threshold (Fig. 6a), BF distribution in young-
%               adult gerbils (Fig. 6b), BF vs spontaneous rate (Fig. 6c) 
%               and BF vs vector strength to pure tones at BF (Fig. 6d) based
%               on the full dataset.
%
%     'fig7'    Reproduce Fig. 7:
%               Fig. 7a: Characteristic frequencies as a function of the 
%               fibre’s BF and as a histogram. 
%               Fig. 7b: Click latencies as a function of the BF with their
%               histogram. Fig. 7c: Spontaneous rates (SR) as a function of 
%               fibre's BF. Fig. 7d, 7e, and 7f: Thresholds for the complex stimuli 
%               recordings NOISE, SPS, and CVC, respectively.
%
%     'tab1'    Returns the Tab. 1 from Heeringa (20204). 
%
%     'summary' Returns a summary table with the metadata of the dataset. 
%
%
%   DATA_HEERINGA2024(.., 'unit', unit) plots and/or provides data for 
%   a specific unit number. Default is unit 1, except for Fig. 4, where default
%   is unit 12 to be consistent with Heeringa (2004). 
%   
%
%   Examples:
%   ---------
%
%   To display Fig. 3 use :
%
%     data_heeringa2024('fig3');
%
%   To display Fig. 4 use :
%
%     data_heeringa2024('fig4');
%
%   To display Fig. 5a use :
%
%     data_heeringa2024('fig5a');
%
%   To display Fig. 5b use :
%
%     data_heeringa2024('fig5b');
%
%   To display Fig. 6 use :
%
%     data_heeringa2024('fig6');
%
%   To display Fig. 7 use :
%
%     data_heeringa2024('fig7');
%
%   To display Tab. 1 use :
%
%     data_heeringa2024('tab1');
%
%   To display the summary of all data use :
%
%     data_heeringa2024('summary');
%
%
%   References:
%     A. N. Heeringa, F. Teske, G. Ashida, and C. Köppl. Cochlear aging
%     disrupts the correlation between spontaneous rate and sound-level
%     coding in auditory nerve fibers. Journal of Neurophysiology,
%     130(3):736--750, 2023. PMID: 37584075.
%     
%     A. N. Heeringa and C. Köppl. Auditory nerve fiber discrimination and
%     representation of naturally-spoken vowels in noise. eNeuro, 9(1), 2022.
%     
%     F. Steenken, A. N. Heeringa, R. Beutelmann, L. Zhang, S. Bovee, G. M.
%     Klump, and C. Köppl. Age-related decline in cochlear ribbon synapses
%     and its relation to different metrics of auditory-nerve activity.
%     Neurobiology of Aging, 108:133--145, 2021.
%     
%     A. N. Heeringa, L. Zhang, G. Ashida, R. Beutelmann, F. Steenken, and
%     C. Köppl. Temporal coding of single auditory nerve fibers is not
%     degraded in aging gerbils. Journal of Neuroscience, 40(2):343--354,
%     2020.
%     
%     A. N. Heeringa, C. Jüchter, R. Beutelmann, G. M. Klump, and C. Köppl.
%     Altered neural encoding of vowels in noise does not affect behavioral
%     vowel discrimination in gerbils with age-related hearing loss.
%     Frontiers in Neuroscience, 17, 2023.
%     
%     F. Steenken, H. Oetjen, R. Beutelmann, L. H. Carney, C. Koeppl, and
%     G. M. Klump. Neural processing and perception of schroeder-phase
%     harmonic tone complexes in the gerbil: Relating single-unit
%     neurophysiology to behavior. European Journal of Neuroscience,
%     56(3):4060--4085, 2022.
%     
%     A. Heeringa. Single-unit auditory nerve fibre responses of young-adult
%     and aging gerbils, 2024.
%     
%     A. N. Heeringa. Single-unit data for sensory neuroscience: Responses
%     from the auditory nerve of young-adult and aging gerbils. Scientific
%     Data, 11:411, Apr. 2024.
%     
%
%   See also: plot_heeringa2024
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/data/data_heeringa2024.php


%   #StatusDoc: Perfect
%   #StatusCode: Perfect
%   #Verification: Verified
%   #Author: Amarins Heeringa (2024): Original version provided for the AMT.
%   #Author: Piotr Majdak(2024): Integration in the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

definput.flags.type = {'missingflag', 'list','data', 'info', 'fig3', 'fig4', 'fig5a', 'fig5b', 'fig6', 'fig7', 'tab1', 'summary'};
% definput.flags.plot = {'plot', 'no_plot'};
% definput.keyvals.unit = {};

definput.import={'data_heeringa2024'}; % import from arg_data_heeringa2024
[flags,kv]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},...
             definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.', ...
      upper(mfilename),flagnames);
end

% Create the list of all animalIDs
animalIDs = kv.animalIDs(:,1); 
% If a list is requested, to the list and exit
if flags.do_list
  data = animalIDs;
  return;
end

animalID = flags.animalID;
unit = kv.unit; 
  % determine the correct default animal ID and unit - depending on the figure to plot
switch flags.type
  case 'fig5b'
    if strcmp(flags.animalID,'default_animalID')
      animalID = 'G220908'; % Default animalID is G220908 for Fig. 5b
    end
  case 'fig4'      
    if strcmp(flags.animalID,'default_animalID')
      animalID = 'G220922'; % Default animalID is G220922 for Fig 4
      if isempty(unit), unit = 12; end % If nothing specified, the default unit is 12
    else
      if isempty(unit), unit = 1; end % If animalID specified, the default unit is 1
    end
  otherwise
    if strcmp(flags.animalID,'default_animalID'), animalID = 'G220922'; end
    if isempty(unit), unit = 1; end
end
  % calculate the number of batches for the requested animal
batches = cell2mat(kv.animalIDs(:,2));
batch_num=batches(find(contains(animalIDs, animalID),1));

%% Get the info
if flags.do_info

  data=amt_load('heeringa2024',[animalID '_1.mat'], 'info'); % infos are identical in all batches, thus we load only the first one
  data=data.info;
  
end

%% Get the data and/or info
if flags.do_data

  data = [];
  for ii=1:batch_num % load all batches
    data_ii = amt_load('heeringa2024',[animalID '_' num2str(ii) '.mat'],'data');
    data = [data data_ii.data];
  end
  
end

%% ------ Prepare data for Fig. 3, Tab. 1 and the Summary -------
if flags.do_fig3 || flags.do_tab1 || flags.do_summary

      % load the all_exp struct
    all_exp = amt_load('heeringa2024','all_exp.mat');
    all_exp = all_exp.all_exp; 

      % pre-allocate variables that will store the metadata per animal
    ages = nan(1,length(all_exp));
    sex = nan(1,length(all_exp));
    abr = nan(1,length(all_exp));
    weights = nan(1,length(all_exp));
    nunit = nan(1,length(all_exp));
    bfsR = nan(2,length(all_exp));
    oxy = nan(1,length(all_exp));
    noise = nan(1,length(all_exp));
    sps = nan(1,length(all_exp));
    cvc = nan(1,length(all_exp));

      % loop through the animals and store the animal specific metadata
    for i = 1:length(all_exp)

        ages(i) = all_exp(i).info.age;
        if strcmp(all_exp(i).info.sex,'F')
            sex(i) = 0;
        elseif strcmp(all_exp(i).info.sex,'M')
            sex(i) = 1;
        end
        abr(i) = all_exp(i).info.ABR.threshold;
        weights(i) = all_exp(i).info.weight;
        nunit(i) = length(all_exp(i).data);
        oxy(i) = all_exp(i).info.anesthesia.oxygen;

        bfs = []; noiT = []; spsT = []; cvcT = [];
        for j = 1:length(all_exp(i).data)

            if ~isempty(all_exp(i).data(j).BF)
                bfs = [bfs all_exp(i).data(j).BF.analysis.bf];
            elseif ~isempty(all_exp(i).data(j).CF)
                bfs = [bfs all_exp(i).data(j).CF.analysis.cf];
            end
            if ~isempty(all_exp(i).data(j).NOISE)
                noiT = [noiT j];
            end
            if ~isempty(all_exp(i).data(j).SPS)
                spsT = [spsT j];
            end
            if ~isempty(all_exp(i).data(j).CVC)
                cvcT = [cvcT j];
            end
        end
        bfsR(1,i) = min(bfs);
        bfsR(2,i) = max(bfs);
        noise(i) = length(noiT);
        sps(i) = length(spsT);
        cvc(i) = length(cvcT);
    end

    % find the indices for young, middle-aged and old animals
    yo = find(ages <= 365);
    ma = find(ages > 365 & ages <= 3*365);
    ol = find(ages > 3*365);

    % find the indices for male and female animals
    F = find(sex == 0);
    M = find(sex == 1);

end

%% ====== Plot Figure 3 ======
if flags.do_fig3
      % define settings
    mo = 365/12;                    % average length of a month in days
    sz = 70;                        % marker size
    f_col = [11 154 51]./256;       % green
    m_col = [111 32 130]./256;      % purple
    fs = 22;                        % fontsize
    xl = [0 45];                    % x-axis limits

    figure;
    scatter(ages(F)./mo, abr(F), sz, f_col, 'filled')
    hold on
    scatter(ages(M)./mo, abr(M), sz, m_col, 'filled')
    xlabel('Age (months)')
    ylabel('ABR threshold (dB SPL)')
    set(gca,'FontSize',fs,'XTick',[0 6 12 18 24 30 36 42],'XTickLabel',{'0','','12','','24','','36',''})
    legend('Female','Male', 'location','northwest')
    xlim(xl)
end

%% ====== Input for Table 1 ======
if flags.do_tab1
    
  Parameter = { 'Total number of animals'; 'Number of female animals'; ... 
    'Age in months (mean)'; 'Age in months (std. dev)'; ...
    'Age in months (min)'; 'Age in months (max)'; ...
    'ABR threshold in dB SPL (mean)'; 'ABR threshold in dB SPL (std. dev.)'; ...
    'ABR threshold in dB SPL (min)'; 'ABR threshold in dB SPL (max)'; ...
    'Weight in grams (mean)'; 'Weight in grams (std. dev)'; ... 
    'Weight in grams (min)'; 'Weight in grams (max)'; ... 
    'Total number of single units'; ... 
    'Range of best frequency in Hz (min)'; 'Range of best frequency in Hz (max)'};
  
  mo = 365/12;
    % young-adult animals
  Young_adult = [length(yo); length(yo)-sum(sex(yo)); ...
           nanmean(ages(yo))/mo; nanstd(ages(yo))/mo; min(ages(yo))/mo; max(ages(yo))/mo; ...
           nanmean(abr(yo)); nanstd(abr(yo)); min(abr(yo)); max(abr(yo)); ...
           nanmean(weights(yo)); nanstd(weights(yo)); min(weights(yo)); max(weights(yo)); ... 
           sum(nunit(yo)); ...
           min(bfsR(1,yo)); max(bfsR(2,yo))];
    % middle-aged animals
  Middle_aged = [length(ma); length(ma)-sum(sex(ma)); ...
            nanmean(ages(ma))/mo; nanstd(ages(ma))/mo; min(ages(ma))/mo; max(ages(ma))/mo; ...
            nanmean(abr(ma)); nanstd(abr(ma)); min(abr(ma)); max(abr(ma)); ...
            nanmean(weights(ma)); nanstd(weights(ma)); min(weights(ma)); max(weights(ma)); ...
            sum(nunit(ma)); ...
            min(bfsR(1,ma)); max(bfsR(2,ma))];
    % quiet-aged animals
  Quiet_aged = [length(ol); length(ol)-sum(sex(ol)); ...
          nanmean(ages(ol))/mo; nanstd(ages(ol))/mo; min(ages(ol))/mo; max(ages(ol))/mo; ...
          nanmean(abr(ol)); nanstd(abr(ol)); min(abr(ol)); max(abr(ol)); ...
          nanmean(weights(ol)); nanstd(weights(ol)); min(weights(ol)); max(weights(ol)); ...
          sum(nunit(ol)); ...
          min(bfsR(1,ol)); max(bfsR(2,ol))]; 
              
  data = table(Young_adult, Middle_aged, Quiet_aged,'RowNames',Parameter);
  if nargout == 0, amt_disp(data,'documentation'); end % display the table
  
end

%% ====== make the summary of metadata ======
if flags.do_summary   
  
  T = table;
  W=warning; warning('off'); % switch off warnings
  for i = 1:length(all_exp)

      T.animalID{i} = all_exp(i).animalID;
      T.age_days(i) = all_exp(i).info.age;
      T.sex{i} = all_exp(i).info.sex;
      T.ABR_threshold(i) = all_exp(i).info.ABR.threshold;
      T.n_units(i) = length(all_exp(i).data);
      nbf = 0; bfs = []; ncf = 0; nph = 0; nclick = 0; nrlf = 0; nsr = 0; nnoise = 0; nsps = 0; ncvc = 0; % ntfs1 = 0; nvcv = 0;
      for j = 1:length(all_exp(i).data)
          if ~isempty(all_exp(i).data(j).BF)
              nbf = nbf + 1;
              bfs = [bfs all_exp(i).data(j).BF.analysis.bf];
          end
          if ~isempty(all_exp(i).data(j).CF)
              ncf = ncf + 1;
          end
          if ~isempty(all_exp(i).data(j).PH)
              nph = nph + 1;
          end
          if ~isempty(all_exp(i).data(j).CLICK)
              nclick = nclick + 1;
          end
          if ~isempty(all_exp(i).data(j).RLF)
              nrlf = nrlf + 1;
          end
          if ~isempty(all_exp(i).data(j).SR)
              nsr = nsr + 1;
          end
          if ~isempty(all_exp(i).data(j).NOISE)
              nnoise = nnoise + 1;
          end
          if ~isempty(all_exp(i).data(j).SPS)
              nsps = nsps + 1;
          end
          if ~isempty(all_exp(i).data(j).CVC)
              ncvc = ncvc + 1;
          end
      end
      T.BF_range{i} = [num2str(min(bfs)) ' - ' num2str(max(bfs))];
      T.n_BF(i) = nbf;
      T.n_CF(i) = ncf;
      T.n_PH(i) = nph;
      T.n_CLICK(i) = nclick;
      T.n_RLF(i) = nrlf;
      T.n_SR(i) = nsr;
      T.n_NOISE(i) = nnoise;
      T.n_SPS(i) = nsps;
      T.n_CVC(i) = ncvc;
  end

  warning(W); % restore warnings 
  if nargout > 0, data = T; else, amt_disp(T,'documentation'); end % display the table
  
end

%% ----------- Make the plots of Figure 4 ---------------
if flags.do_fig4

  data = [];
  for ii=1:batch_num % load all batches
    data_ii = amt_load('heeringa2024',[animalID '_' num2str(ii) '.mat'],'data');
    data = [data data_ii.data];
  end
  
  if unit > length(data)
    error('Requested unit not available');
  end
  
  pretitle = [animalID ' (unit ' num2str(unit) ')']; 
  plot_heeringa2024('waveform',data(unit).BF.curvedata, data(unit).BF.curveresp, ... 
                    data(unit).BF.curvesettings, pretitle); 
                  
end

%% ----------- Make the plots of Figure 5a ---------------
if flags.do_fig5a
  
  data = [];
  for ii=1:batch_num % load all batches
    data_ii = amt_load('heeringa2024',[animalID '_' num2str(ii) '.mat'],'data');
    data = [data data_ii.data];
  end
    % set the axes limitations
  xl = [5 85];
    % plot the data
  figure;
  for i = 1:length(data) % loop through all the units
    if ~isempty(data(i).RLF) % only proceed if there is RLF data
        % get the rate, stds, and levels of the unit
      rate = data(i).RLF.analysis.rates;
      std = data(i).RLF.analysis.stdevs;
      levs = data(i).RLF.analysis.levels;
        % errorbar(levs,rate,std,'LineWidth',1.5)
      plot(levs,rate,'LineWidth',1.5)
      hold on
    end
  end
    % beautify
  set(gca,'FontSize',22)
  xlabel('Level (dB SPL)')
  ylabel('Rate (spikes/s)')
  xlim(xl)
  title(animalID); 
  box off
end

%% ----------- Make the plots of Figure 5b ---------------
if flags.do_fig5b

    exp = amt_load('heeringa2024','G220908_1.mat');
    unit = 23; % '3p_181'
    TestLevel = 20; % 'in dB above threshold'
      % plot
    plot_heeringa2024('psth',exp,unit,TestLevel);
end


%% ----------- Prepare the data for Figures 6 and 7 ---------------
if flags.do_fig6 || flags.do_fig7

      % load the struct
    all_exp = amt_load('heeringa2024','all_exp.mat');
    all_exp = all_exp.all_exp; 

      % pre-allocate variables that will store the metadata per animal
    largeNumber = 2000; % make sure this is larger than the total number of units
    ages = nan(1,largeNumber);
    sex = nan(1,largeNumber);
    abr = nan(1,largeNumber);
    bfs = nan(1,largeNumber);
    thr = nan(1,largeNumber);
    srsT = nan(5,largeNumber);
    clk = nan(4,largeNumber);
    vss = nan(1,largeNumber);
    cfs = nan(2,largeNumber);
    cmx = nan(3,largeNumber);

      % initialize a counter for the units
    cnt = 1;

      % loop through all animals and store the animal specific metadata
    for i = 1:length(all_exp)
          % loop through all units of an animal and store their characteristics
        for j = 1:length(all_exp(i).data)
            if ~isempty(all_exp(i).data(j).BF)
                bfs(1,cnt) = all_exp(i).data(j).BF.analysis.bf;
                srsT(4,cnt) = all_exp(i).data(j).BF.analysis.sr;
            end
            if ~isempty(all_exp(i).data(j).RLF)
                thr(1,cnt) = all_exp(i).data(j).RLF.analysis.threshold;
                srsT(3,cnt) = all_exp(i).data(j).RLF.analysis.sr;
            end
            if ~isempty(all_exp(i).data(j).CLICK)
                if length(all_exp(i).data(j).CLICK) == 1
                    clk(1,cnt) = all_exp(i).data(j).CLICK.analysis.fsl_mean;
                    clk(2,cnt) = all_exp(i).data(j).CLICK.analysis.fsl_median;
                    clk(3,cnt) = all_exp(i).data(j).CLICK.analysis.latency_2bins;
                    clk(4,cnt) = all_exp(i).data(j).CLICK.analysis.latency_poisson;
                end
            end
            if ~isempty(all_exp(i).data(j).SR)
                srsT(1,cnt) = all_exp(i).data(j).SR.analysis.sr;
            end
            if ~isempty(all_exp(i).data(j).PH)
                srsT(2,cnt) = all_exp(i).data(j).PH.analysis.sr;
                tmp = find(~isnan(all_exp(i).data(j).PH.analysis.prob) & all_exp(i).data(j).PH.analysis.prob<0.001);
                if ~isempty(tmp)
                    vss(1,cnt) = max(all_exp(i).data(j).PH.analysis.vs(tmp));
                end
            end
            
            if ~isempty(all_exp(i).data(j).CF)
                cfs(1,cnt) = all_exp(i).data(j).CF.analysis.cf;
                cfs(2,cnt) = all_exp(i).data(j).CF.analysis.q10;
            end
            if ~isempty(all_exp(i).data(j).NOISE)
                cmx(1,cnt) = 1;
            end
            if ~isempty(all_exp(i).data(j).SPS)
                cmx(2,cnt) = 1;
            end
            if ~isempty(all_exp(i).data(j).CVC)
                cmx(3,cnt) = 1;
            end
            
            ages(1,cnt) = all_exp(i).info.age;
            if strcmp(all_exp(i).info.sex,'F')
                sex(1,cnt) = 0;
            elseif strcmp(all_exp(i).info.sex,'M')
                sex(1,cnt) = 1;
            end
            abr(1,cnt) = all_exp(i).info.ABR.threshold;

            cnt = cnt + 1;

        end
    end

      % find the indices for young, middle-aged and old animals
    yo = find(ages <= 365);
    ma = find(ages > 365 & ages <= 3*365);
    ol = find(ages > 3*365);
      % find the indices for male and female animals
    F = find(sex == 0);
    M = find(sex == 1);
      % get the best estimate of spontaneous rate
    srs = nan(1,largeNumber);
    for i = 1:largeNumber
        if ~isnan(srsT(1,i))
            srs(1,i) = srsT(1,i);
        elseif ~isnan(srsT(2,i))
            srs(1,i) = srsT(2,i);
        elseif ~isnan(srsT(3,i))
            srs(1,i) = srsT(3,i);
        elseif ~isnan(srsT(4,i))
            srs(1,i) = srsT(4,i);
        end
    end


      % settings for the plots
    fs = 22;                                    % fontsize
    yo_sym = 'o'; yo_col = 'b';                 % symbol and color to plot data of young-adult gerbils
    ma_sym = '^'; ma_col = [251 186 0]./256;    % symbol and color to plot data of middle-aged gerbils
    ol_sym = 's'; ol_col = 'r';                 % symbol and color to plot data of quiet_aged gerbils
    sz = 70;                                    % markersize


    % ====== BF vs threshold - Fig 6A ======
      % set limitations and ticks of the two axes
    xl = [0.3 20];
    yl = [0 100];
    xt = [0.2 0.5 1 2 5 10 20];

      % make running average
    logvec = logspace(log10(xl(1)),log10(xl(2)),25);
    YLra = nan(3,length(logvec)-1);
    BFra = nan(1,length(logvec)-1);
    for Age = 1:3 % loop through the age groups
        if Age == 1; ag = yo;
        elseif Age == 2; ag = ma;
        else; ag = ol;
        end
        for i = 1:length(logvec)-1 % loop through the logarithmically spaced vector
            idx = find(bfs(ag)/1000>logvec(i) & bfs(ag)/1000<=logvec(i+1));
            data = thr(ag);
            YLra(Age,i) = nanmean(data(idx));
            BFra(1,i) = logspace(log10(logvec(i)),log10(logvec(i+1)),1);
        end
    end
end

%% Plot figure 6
if flags.do_fig6
  
    % ====== Fig 6A - Thresholds ======
  figure;
  scatter(bfs(yo)/1000,thr(yo),sz,yo_col,yo_sym)
  hold on
  scatter(bfs(ma)/1000,thr(ma),sz,ma_col,ma_sym)
  scatter(bfs(ol)/1000,thr(ol),sz,ol_col,ol_sym)
  plot(BFra,YLra(1,:),yo_col,'LineWidth',2)
  plot(BFra,YLra(2,:),'color',ma_col,'LineWidth',2)
  plot(BFra,YLra(3,:),ol_col,'LineWidth',2)
  xlabel('Best frequency (kHz)')
  ylabel('Threshold (dB SPL)')
  set(gca,'FontSize',fs,'XScale','log','XTick',xt)
  xlim(xl); ylim(yl);
  legend('Young adult','Middle aged','Old','Location','northwest')

    % ====== Fig 6B - BF distribution ======
  edges = logspace(log10(200),log10(20000),25); % some settings for the histogram
  xl = [300 20000];
  xt = [200 500 1000 2000 5000 10000 20000];

  figure;
  histogram(bfs(yo),edges,'FaceColor','k','EdgeColor','w')
  set(gca,'XScale','log','FontSize',fs,'XTick',xt,'XTickLabel',{'0.2','0.5','1','2','5','10','20'})
  xlim(xl)
  ylabel('Unit count')
  xlabel('Best frequency (kHz)')
  box off

    % ====== Fig 6C - SR vs BF ======
  xl = [0.3 20];   % some settings
  yl = [0 200];
  xt = [0.2 0.5 1 2 5 10 20];

  figure
  plot([3.5 3.5],yl,'--','LineWidth',3,'Color',[0,78,158]/256)
  hold on
  scatter(bfs(yo)/1000,srs(yo),sz,'k',yo_sym)
  text(3.9,190,'BF > 3.5 kHz','Color',[0,78,158]/256,'FontSize',19)
  set(gca,'FontSize',fs,'XScale','log','XTick',xt)
  xlim(xl)
  ylabel('Spontaneous rate (spikes/s)')
  xlabel('Best frequency (kHz)')

    % ====== Fig 6D - BF vs phase locking ======
  xl = [0.3 6];   % some settings
  yl = [0 1];
  xt = [0.2 0.5 1 2 5 10 20];

    % differentiate between low- and high-SR fibers, find the indices
  srl = find(srs<18); 
  srh = find(srs>=18);
  ylo = intersect(yo,srl);
  yhi = intersect(yo,srh);
  mlo = intersect(ma,srl);
  mhi = intersect(ma,srh);
  olo = intersect(ol,srl);
  ohi = intersect(ol,srh);

  figure
  scatter(bfs(yhi)/1000,vss(yhi),sz,yo_col,yo_sym,'filled')
  hold on
  scatter(bfs(ylo)/1000,vss(ylo),sz,yo_col,yo_sym,'LineWidth',1)
  scatter(bfs(mhi)/1000,vss(mhi),sz,ma_col,ma_sym,'filled')
  scatter(bfs(mlo)/1000,vss(mlo),sz,ma_col,ma_sym,'LineWidth',1)
  scatter(bfs(ohi)/1000,vss(ohi),sz,ol_col,ol_sym,'filled')
  scatter(bfs(olo)/1000,vss(olo),sz,ol_col,ol_sym,'LineWidth',1)
  set(gca,'FontSize',fs,'XScale','log','XTick',xt)
  xlim(xl)
  ylim(yl)
  ylabel('Max. vector strength')
  xlabel('Best frequency (kHz)')

    % plot the legend
  x1 = 2.7; x2 = 3.4; x3 = 4;
  y1 = 0.92; y2 = 0.86; y3 = 0.8;
  fs2 = fs - 6;
  scatter(x1,y1,sz,yo_col,yo_sym,'filled')
  scatter(x2,y1,sz,yo_col,yo_sym,'LineWidth',1)
  scatter(x1,y2,sz,ma_col,ma_sym,'filled')
  scatter(x2,y2,sz,ma_col,ma_sym,'LineWidth',1)
  scatter(x1,y3,sz,ol_col,ol_sym,'filled')
  scatter(x2,y3,sz,ol_col,ol_sym,'LineWidth',1)
  text(x3,y1,'Young adult','FontSize',fs2)
  text(x3,y2,'Middle aged','FontSize',fs2)
  text(x3,y3,'Old','FontSize',fs2)
  text(x1,y1+0.04,'high SR','Rotation',45,'FontSize',fs2)
  text(x2,y1+0.04,'low SR','Rotation',45,'FontSize',fs2)

end

%% ----------- Make the plots of Figure 7 ---------------
if flags.do_fig7

    % ====== Figure 7A -- BF vs CF
  figure;
  xl = [0.3 20];    
  xt = [0.2 0.5 1 2 5 10 20];
    % plot the main plot
  subplot(1, 5, 1:4)
  scatter(bfs(yo)/1000,cfs(1,yo)/1000,sz,yo_col,yo_sym,'LineWidth',1.2)
  hold on
  scatter(bfs(ma)/1000,cfs(1,ma)/1000,sz,ma_col,ma_sym,'LineWidth',1.2)
  scatter(bfs(ol)/1000,cfs(1,ol)/1000,sz,ol_col,ol_sym,'LineWidth',1.2)
  plot(xl,xl,'--k','LineWidth',1)
  xlabel('Best frequency (kHz)')
  ylabel('Characteristic frequency (kHz)')
  title('Units with CF recording')
  set(gca,'FontSize',fs,'XScale','log','XTick',xt,'YScale','log','YTick',xt)
  xlim(xl); ylim(xl);
  legend('Young adult','Middle aged','Old','Location','northwest')

    % plot the histogram of the CF
  subplot(1,5,5)
  edges = logspace(log10(200),log10(20000),25);
  xl = [300 20000];
  xt = [200 500 1000 2000 5000 10000 20000];
  histogram(cfs(1,:),edges,'FaceColor','k','EdgeColor','w')
  set(gca,'XScale','log','XTick',xt,'XTickLabel',{'','','','','','',''},'view',[90 -90],'YTick',[0 5 10],'YTickLabel',{'','',''})
  xlim(xl)
  box off

    % output the total number of units with a CF recording
  amt_disp(['Number of units with CF recording: ' num2str(sum(~isnan(cfs(1,:))))],'documentation');

    % ====== Figure 7B -- BF vs Click latency
  figure;
  xl = [0.3 20];
  yl = [0 3.5];
  xt = [0.2 0.5 1 2 5 10 20];

    % select the type of click latency analysis to be plotted
  type = 3; % 1 = mean fsl, 2 = median fsl, 3 = 2-bins method, 4 = poisson method

    % differentiate between low- and high-SR fibers, find the indices
  srl = find(srs<18);
  srh = find(srs>=18);
  ylo = intersect(yo,srl);
  yhi = intersect(yo,srh);
  mlo = intersect(ma,srl);
  mhi = intersect(ma,srh);
  olo = intersect(ol,srl);
  ohi = intersect(ol,srh);

    % plot the main plot: latencies
  subplot(5, 1, 1:4)
  scatter(bfs(yhi)/1000,clk(type,yhi)*1000,sz,yo_col,yo_sym,'filled')
  hold on
  scatter(bfs(ylo)/1000,clk(type,ylo)*1000,sz,yo_col,yo_sym,'LineWidth',1)
  scatter(bfs(mhi)/1000,clk(type,mhi)*1000,sz,ma_col,ma_sym,'filled')
  scatter(bfs(mlo)/1000,clk(type,mlo)*1000,sz,ma_col,ma_sym,'LineWidth',1)
  scatter(bfs(ohi)/1000,clk(type,ohi)*1000,sz,ol_col,ol_sym,'filled')
  scatter(bfs(olo)/1000,clk(type,olo)*1000,sz,ol_col,ol_sym,'LineWidth',1)
  ylabel('Click latency (ms)')
  title('Units with CLICK recording')
  set(gca,'FontSize',fs,'XScale','log','XTick',xt,'XTickLabel',{'','','','','','',''})
  xlim(xl); ylim(yl);

    % create the legend
  x1 = 5; x2 = 6.5; x3 = 8;           % x-coordinates legend
  y1 = 2.8; y2 = 2.55; y3 = 2.3;      % y-coordinates legend
  fs2 = fs - 6;                       % fontsize legend
  scatter(x1,y1,sz,yo_col,yo_sym,'filled')
  scatter(x2,y1,sz,yo_col,yo_sym,'LineWidth',1)
  scatter(x1,y2,sz,ma_col,ma_sym,'filled')
  scatter(x2,y2,sz,ma_col,ma_sym,'LineWidth',1)
  scatter(x1,y3,sz,ol_col,ol_sym,'filled')
  scatter(x2,y3,sz,ol_col,ol_sym,'LineWidth',1)
  text(x3,y1,'Young adult','FontSize',fs2)
  text(x3,y2,'Middle aged','FontSize',fs2)
  text(x3,y3,'Old','FontSize',fs2)
  text(x1,y1+0.15,'high SR','Rotation',45,'FontSize',fs2)
  text(x2,y1+0.15,'low SR','Rotation',45,'FontSize',fs2)

    % plot the histogram of the CF distribtion
  subplot(5,1,5);
  edges = logspace(log10(200),log10(20000),25);
  xl = [300 20000];
  xt = [200 500 1000 2000 5000 10000 20000];
  clki = find(~isnan(clk(type,:)));
  histogram(bfs(clki),edges,'FaceColor','k','EdgeColor','w')
  set(gca,'FontSize',fs,'XScale','log','XTick',xt,'XTickLabel',{'0.2','0.5','1','2','5','10','20'},'YTick',0,'YTickLabel',{''})
  xlim(xl)
  xlabel('Best frequency (kHz)')
  box off

    % output the total number of units with a CLICK recording
  amt_disp(['Number of units with CLICK recording: ' num2str(length(clki))],'documentation');

    % ===== Figure 7C -- BF vs SR
  xl = [0.3 20]; 
  xt = [0.2 0.5 1 2 5 10 20];
  yl = [0 150];

    % plot the main plot
  figure;
  scatter(bfs(yo)/1000,srsT(1,yo),sz,yo_col,yo_sym,'LineWidth',2)
  hold on
  scatter(bfs(ma)/1000,srsT(1,ma),sz,ma_col,ma_sym,'LineWidth',2)
  scatter(bfs(ol)/1000,srsT(1,ol),sz,ol_col,ol_sym,'LineWidth',2)
  xlabel('BF (kHz)')
  ylabel('SR (spikes/s)')
  title('Units w/ SR')
  set(gca,'FontSize',fs+10,'XScale','log','XTick',xt);%,'YScale','log','YTick',xt)
  xlim(xl); ylim(yl);

    % output the total number of units with a SR recording
  amt_disp(['Number of units with SR recording: ' num2str(sum(~isnan(srsT(1,:))))],'documentation');

    % ==== Figure 7D -- BF vs threshold, NOISE
  xl = [0.3 20]; 
  xt = [1 10];
  yl = [0 90];
  yt = [0 40 80];
  lw = 2;

  noise = find(cmx(1,:) == 1);
  yoi = intersect(yo,noise);
  mai = intersect(ma,noise);
  oli = intersect(ol,noise);

    % plot the data
  figure;    
  scatter(bfs(yoi)/1000,thr(yoi),sz,yo_col,yo_sym,'LineWidth',lw)
  hold on
  scatter(bfs(mai)/1000,thr(mai),sz,ma_col,ma_sym,'LineWidth',lw)
  scatter(bfs(oli)/1000,thr(oli),sz,ol_col,ol_sym,'LineWidth',lw)
  xlabel('BF (kHz)')
  ylabel('Threshold (dB SPL)')
  title('Units w/ NOISE')
  set(gca,'FontSize',fs+10,'XScale','log','XTick',xt,'XTickLabel',{'1','10'},'YTick',yt)
  xlim(xl); ylim(yl);

    % output the total number of units with a NOISE recording
  amt_disp(['Number of units with NOISE recording: ' num2str(length(noise))],'documentation');


    % ==== Figure 7E -- BF vs threshold, SPS
  sps = find(cmx(2,:) == 1);
  yoi = intersect(yo,sps);
  mai = intersect(ma,sps);
  oli = intersect(ol,sps);

    % plot the data
  figure;
  scatter(bfs(yoi)/1000,thr(yoi),sz,yo_col,yo_sym,'LineWidth',lw)
  hold on
  scatter(bfs(mai)/1000,thr(mai),sz,ma_col,ma_sym,'LineWidth',lw)
  scatter(bfs(oli)/1000,thr(oli),sz,ol_col,ol_sym,'LineWidth',lw)
  xlabel('BF (kHz)')
  title('Units w/ SPS')
  set(gca,'FontSize',fs+10,'XScale','log','XTick',xt,'XTickLabel',{'1','10'},'YTick',yt)
  xlim(xl); ylim(yl);

    % output the total number of units with a SPS recording
  amt_disp(['Number of units with SPS recording: ' num2str(length(sps))],'documentation');

  % === Figure 7F -- BF vs threshold, CVC
  cvc = find(cmx(3,:) == 1);
  yoi = intersect(yo,cvc);
  mai = intersect(ma,cvc);
  oli = intersect(ol,cvc);
  
    % plot the data
  figure;    
  scatter(bfs(yoi)/1000,thr(yoi),sz,yo_col,yo_sym,'LineWidth',lw)
  hold on
  scatter(bfs(mai)/1000,thr(mai),sz,ma_col,ma_sym,'LineWidth',lw)
  scatter(bfs(oli)/1000,thr(oli),sz,ol_col,ol_sym,'LineWidth',lw)
  xlabel('BF (kHz)')
  title('Units w/ CVC')
  set(gca,'FontSize',fs+10,'XScale','log','XTick',xt,'XTickLabel',{'1','10'},'YTick',yt)
  xlim(xl); ylim(yl);

    % output the total number of units with a CVC recording
  amt_disp(['Number of units with CVC recording: ' num2str(length(cvc))],'documentation');

end

