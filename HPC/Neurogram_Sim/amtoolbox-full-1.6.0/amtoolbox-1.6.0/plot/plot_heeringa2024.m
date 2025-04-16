function plot_heeringa2024(type,varargin)
%PLOT_HEERINGA2024 plots the output of data_heeringa2024
%
%   Usage:
%     plot_heeringa2024('waveform', curvedata, curveresp, curvesettings); 
%     plot_heeringa2024('waveform', curvedata, curveresp, curvesettings, animalID);
%     plot_heeringa2024('psth', andata, unit, TestLevel); 
%
%   This function plots the waveform of AN responses or peri-stimulus
%   histogram (PSTH) from AN responses. For more details,  
%   see https://datadryad.org/stash/downloads/file_stream/3070542.
%
%   PLOT_HEERINGA2024('waveform', ...) plots four panels: the unfiltered first data trace, 
%   the interspike interval (ISI) histogram, the first 300 spike waveforms, and 
%   the waveform average with the 95 percent confidence intervals. 
%   The ISI gives an indication whether a single or a multi unit
%   was recorded from. The waveform plots reveal if the spikes have 
%   a prepotential, i.e., they were recorded from AVCN neurons, instead of 
%   the auditory nerve. Also the click latency shows whether a single
%   unit was derived from AN or AVCN. The input parameters are:
%
%     curvedata     Structure with spike times and the information about 
%                   randomization of the trials. See exp.data.BF.curvedata 
%                   in https://datadryad.org/stash/downloads/file_stream/3070542 
%                   for detailed information.
%
%     curveresp     Cell matrix with a size of n x m, where n is the number of 
%                   different tone frequencies and m is the number of repetitions. 
%                   Each cell contains the (raw analogue data) voltage trace (in mV) 
%                   of the recording of its respective trial. Corresponding frequencies
%                   and sampling rate needs to be provided in curvesettings. 
%
%     curvesettings Structure with metadata of the recording. See exp.data.BF.curvesettings
%                   in https://datadryad.org/stash/downloads/file_stream/3070542 
%                   for detailed information. 
%
%     animalID      Optional string (e.g., with the animal ID) displayed in the panels.
%
%   The plot of the waveform is used in Fig. 4 in data_heeringa2024.
%
%   PLOT_HEERINGA2024('psth',...) plots a peri-stimulus time histogram (PSTH) 
%   of recordings above the TestLevel. The input parameters are:
%
%     andata    Struct with the AN recordings, the output of data_heeringa2024('data', animalID). 
%               The content of the andata is described in https://datadryad.org/stash/downloads/file_stream/3070542.
%     
%     unit      Index of the unit in andata to be plotted.
%     
%     TestLevel Level (in dB) above threshold at which the PSTH will be plotted.
%
%   The plot of the PSTH is used in Fig. 5b in data_heeringa2024.
%
%   References:
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
%      heeringa2020 steenken2021 heeringa2022 heeringa2023b
%
%   See also: data_heeringa2024
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/plot/plot_heeringa2024.php


%   #StatusDoc: Submitted
%   #StatusCode: Submitted
%   #Verification: Qualified
%   #Author: Amarins Heeringa (2024): original implementation of checkAN.m and makePSTH.m on <doi.org/10.5061/dryad.qv9s4mwn4>
%   #Author: Piotr Majdak(2024): integration in the AMT

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

definput.flags.type = {'waveform','psth'};
flags = ltfatarghelper({}, definput,{type});

if flags.do_waveform
  curvedata=varargin{1};
  curveresp=varargin{2};
  curvesettings=varargin{3};
  if nargin == 4
    local_plotAN(curvedata,curveresp,curvesettings);
  else
    animalID=varargin{4};
    local_plotAN(curvedata,curveresp,curvesettings,animalID);
  end
end
 
if flags.do_psth
  andata=varargin{1};
  unit=varargin{2};
  TestLevel=varargin{3};
  local_plotPSTH(andata,unit,TestLevel);
end

function local_plotAN(curvedata,curveresp,curvesettings, animalID)

% This script is based on checkAN.m from https://datadryad.org/stash/downloads/file_stream/3070542
%
% Original implementation by Amarins Heeringa, Koeppl Lab, July 2018
% Integration in the AMT by Piotr Majdak


Fs = curvesettings.Fs(1,1); 

T = length(curveresp{1,1})/Fs;
t = 1/Fs:1/Fs:T;
yspik = zeros(1,length(curvedata.spike_times{1,1})); 
yspik = yspik + max(curveresp{1,1})/10*1.1;

% plot the first datatrace and spikes
figure;
subplot(2,2,1);
plot(t*1000,curveresp{1,1}/10,'b')
hold on
scatter(curvedata.spike_times{1,1}*1000,yspik,[],'r','*');
xlabel('time (ms)');
ylabel('Amplitude (V)');
if exist('animalID','var')
  title([animalID newline 'First data trace, unfiltered']);
else
  title('First data trace, unfiltered');
end

% prepare variables to get single waveforms
[a,b,c] = size(curveresp);
ms1 = round(Fs*0.00125); % amount of datapoints for 1.25 ms
lwv = (ms1*2)+1; % total length waveform in datapoints
spks = nan(lwv,400000); % pre-allocate waveform matrix
cnt = 1;
isis = []; 

% get all the waveforms
for an = 1:a
    for bn = 1:b
        for cn = 1:c
            spT = curvedata.spike_times{an,bn,cn}; % spike times in s
            isis = [isis diff(spT)]; % get the interspike intervals
            spDP = round(spT*Fs); % spike times in data points
            resp = curveresp{an,bn,cn}; % get data trace
            for sp = 1:length(spT) % loop through spikes of that trial
                if spDP(sp)>ms1 && spDP(sp)+ms1<length(resp) % only include spikes not too close to the edges of the response
                    spks(:,cnt) = resp(spDP(sp)-ms1:spDP(sp)+ms1); % get the waveform
                    cnt = cnt+1;
                end
            end
        end
    end
end

% plot ISIs and info
subplot(2,2,2);
edges = 0:1:50;
histogram(isis*1000,edges,'FaceAlpha',0.8,'FaceColor',[11 154 51]/256);
xlabel('Interspike intervals (ms)');
ylabel('Count');
if exist('animalID','var')
  title([animalID newline 'Interspike interval histogram']);
else
  title('Interspike interval histogram');
end
yl=ylim;
text(23,yl(2)*0.9,sprintf('total ISIs = %d',length(isis)));
text(23,yl(2)*0.82,sprintf('ISIs < 1 ms = %d',sum(isis<0.001)));
text(23,yl(2)*0.74,sprintf('ISIs < 0.6 ms = %d',sum(isis<0.0006)));
text(23,yl(2)*0.66,sprintf('ISI median = %0.1f ms',median(isis)*1000));
text(23,yl(2)*0.58,sprintf('min ISI = %0.1f ms',min(isis)*1000));

spks=spks(:,1:cnt-1);
twv = linspace(-1.25,1.25,lwv);

% plot the first 300 waveforms
subplot(2,2,3);
plot(twv,spks(:,1)/10,'k','LineWidth',0.3);
hold on
if cnt>300
    n=300;
else
    n=cnt-1;
end
for i=2:n
    plot(twv,spks(:,i)/10,'k','LineWidth',0.3);
end
if exist('animalID','var')
  title([animalID newline 'First 300 spike waveforms']);
else
  title('First 300 spike waveforms');
end
xlabel('Time rel. spike peak (ms)');
ylabel('Amplitude (V)');
set(gca,'XTick',[-1 0 1],'XTickLabel',{'-1 ms','0','1 ms'});
xlim([-1.3 1.3]); yl=ylim;

% plot the average waveform
% mWV = mean(spks,2); 
% stdWV = std(spks,[],2);
mWV = median(spks,2)/10; 
ci1 = quantile(spks,0.025,2)/10;
ci2 = quantile(spks,0.975,2)/10;

subplot(2,2,4);
plot(twv,mWV,'r','LineWidth',2);
hold on
% plot(twv,mWV+2*stdWV,'r',twv,mWV-2*stdWV,'r','LineWidth',0.3)
plot(twv,ci1,'r',twv,ci2,'r','LineWidth',0.3);
patch([twv fliplr(twv)],[(ci2)' fliplr((ci1)')],'r','FaceAlpha',0.25,'EdgeColor','none');
text(-0.9,max(mWV),sprintf('n = %d',cnt));
xlabel('Time rel. spike peak (ms)');
ylabel('Amplitude (V)');
if exist('animalID','var')
  title([animalID newline 'Waveform median +/- 95% CI']);
else
  title('Waveform median +/- 95% CI');
end
set(gca,'XTick',[-1 0 1],'XTickLabel',{'-1 ms','0','1 ms'});
xlim([-1.3 1.3]); ylim(yl);



function local_plotPSTH(andata,i,TestLevel)
% This script is based on makePSTH.m from https://datadryad.org/stash/downloads/file_stream/3070542
%
% Original implementation by Amarins Heeringa
% Integration in the AMT by Piotr Majdak

figure;
binSize = 0.001; % set binsize for PSTH

if ~isempty(andata.data(i).BF)
    bf = andata.data(i).BF.analysis.bf;
else
    bf = [];
end
if ~isempty(andata.data(i).RLF)
    thr = andata.data(i).RLF.analysis.threshold;
else
    thr = [];
end

% plot PSTH of BF file as closest to BF as possible
if ~isempty(andata.data(i).BF)

    BF = andata.data(i).BF;
    BFdur = BF.curvesettings.tdt.AcqDuration; 
    BFdelay = BF.curvesettings.stim.Delay; 
    idx2 = find(abs(BF.curvedata.depvars_sort(:,1,1) - bf)==min(abs(BF.curvedata.depvars_sort(:,1,1) - bf)));
    if length(idx2) > 1
        idx2 = min(idx2);
    end
    reps = length(BF.curvedata.depvars_sort(1,:,1));
    spiksBF=[];
    for r = 1:reps
        spks = BF.curvedata.spike_times{idx2,r}; 
        spiksBF=[spiksBF spks];        
    end
    
    subplot(2,2,1);
    nbin = round(BFdur/binSize);
    [N,cent] = hist(spiksBF,nbin); N=(N/reps)/binSize;
    bar(cent,N,0.9,'k');
    xlabel('Time (s)'); ylabel('Rate (spikes/s)');
    xlim([0 BFdur]);
    
    level = unique(andata.data(i).BF.curvesettings.stimcache.ABI); level = level(end);
    title(sprintf('BF = %d Hz, PSTH at %d Hz\n Thr = %.1f dB, Level = %.1f dB',...
        bf, BF.curvedata.depvars_sort(idx2,1,1), thr, level));
else
    BF = [];
end

% plot PSTH of RLF file at TestLevel above threshold
if ~isempty(andata.data(i).RLF) && ~isnan(thr)

    ABI = andata.data(i).RLF;
    ABIdur = ABI.curvesettings.tdt.AcqDuration; 
    ABIdelay = ABI.curvesettings.stim.Delay; 
    lev = thr + TestLevel;
    idx2 = find(abs(ABI.curvedata.depvars_sort(:,1,1) - lev)==min(abs(ABI.curvedata.depvars_sort(:,1,1) - lev)));
    if length(idx2) > 1
        idx2 = max(idx2);
    end
    
    reps = length(ABI.curvedata.depvars_sort(1,:,1));
    spiksABI=[];
    for r = 1:reps
        spks = ABI.curvedata.spike_times{idx2,r}; 
        spiksABI=[spiksABI spks];        
    end
    
    subplot(2,2,2);
    nbin = round(ABIdur/binSize);
    [N,cent] = hist(spiksABI,nbin); N=(N/reps)/binSize;
    bar(cent,N,0.9,'k');
    xlabel('Time (s)'); ylabel('Rate (spikes/s)');
    xlim([0 ABIdur]);
    
    title(sprintf('BF = %d Hz, PSTH at %d Hz\n Thr = %.1f dB, Level = %.1f dB',...
        bf,andata.data(i).RLF.analysis.frequency,thr,ABI.curvedata.depvars_sort(idx2,1,1)));
else
    ABI = [];
end

% plot PSTH of PH file at TestLevel above threshold
if ~isempty(andata.data(i).PH) && ~isempty(thr)

    PH = andata.data(i).PH;
    PHdur = PH.curvesettings.tdt.AcqDuration; 
    PHdelay = PH.curvesettings.stim.Delay; 
    lev = thr + TestLevel;
    idx2 = find(abs(PH.curvedata.depvars_sort(:,1,1) - lev)==min(abs(PH.curvedata.depvars_sort(:,1,1) - lev)));
    if length(idx2) > 1
        idx2 = max(idx2);
    elseif isempty(idx2)
        idx2 = 1;
    end
    
    reps = length(PH.curvedata.depvars_sort(1,:,1));
    spiksPH=[];
    for r = 1:reps
        spks = PH.curvedata.spike_times{idx2,r}; 
        spiksPH=[spiksPH spks];        
    end
    
    subplot(2,2,3);
    nbin = round(PHdur/binSize);
    [N,cent] = hist(spiksPH,nbin); N=(N/reps)/binSize;
    bar(cent,N,0.9,'k');
    xlabel('Time (s)'); ylabel('Rate (spikes/s)');
    xlim([0 PHdur]);
    
    title(sprintf('BF = %d Hz, PSTH at %d Hz\n Thr = %.1f dB, Level = %.1f dB',...
        bf,andata.data(i).PH.analysis.frequency,thr,PH.curvedata.depvars_sort(idx2,1,1)));
else
    PH = [];

end

% Plot PSTH with as much as possible data combined
if isempty(ABI) && isempty(PH) || isempty(BF) && isempty(ABI) || isempty(BF) && isempty(PH)
    % do nothing, more than one file missing
    spiks = [];
elseif isempty(BF) || isempty(ABI) || isempty(PH)
    % only file missing, try to combine other two
    if isempty(BF)
        if ABIdelay == PHdelay && ABIdur == PHdur
            spiks = [spiksABI spiksPH];
            dur = ABIdur;
        else
            spiks = [];
        end
    elseif isempty(ABI)
        if BFdelay == PHdelay && BFdur == PHdur
            spiks = [spiksBF spiksPH];
            dur = BFdur;
        else
            spiks = [];
        end
    elseif isempty(PH)
        if BFdelay == ABIdelay && BFdur == ABIdur
            spiks = [spiksBF spiksABI];
            dur = BFdur;
        else
            spiks = [];
        end
    end
else
    % all files there, try to combine
    if ABIdelay == PHdelay && ABIdur == PHdur
        spiks = [spiksABI spiksPH];
        dur = ABIdur;
        if ABIdelay == BFdelay && ABIdur == BFdur
            spiks = [spiks spiksBF];
            dur = BFdur;
        end
    elseif PHdelay == BFdelay && PHdur == BFdur
        spiks = [spiksPH spiksBF];
        dur = BFdur;
    end
end

if ~isempty(spiks)
	subplot(2,2,4);
	nbin = round(dur/binSize);
	bar(cent,N,0.9,'k');
	[N,cent] = hist(spiks,nbin); N=(N/reps)/binSize;
	xlabel('Time (s)'); ylabel('Rate (spikes/s)');
	xlim([0 dur]);
	title('All data together');
end

