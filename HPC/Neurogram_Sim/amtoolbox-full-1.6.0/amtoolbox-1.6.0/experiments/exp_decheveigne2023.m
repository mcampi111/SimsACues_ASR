function exp_decheveigne2023(varargin)
%EXP_DECHEVEIGNE2023 model of auditory-nerve spike generation
%
%   Usage: data = exp_decheveigne2023(flags)
%
%   exp_cheveigne2023 reproduces the figures from de Cheveigne (2023), 
%   where a spike generator is described.
%
%   To display Fig. 1 of de Cheveigne (2023) use :
%
%     out = exp_decheveigne2023('fig1');
%
%   To display Fig. 2 of de Cheveigne (2023) use :
%
%     out = exp_decheveigne2023('fig2');
%
%   To display Fig. 3 of de Cheveigne (2023) use :
%
%     out = exp_decheveigne2023('fig3');
%
%   To display Fig. 5 of de Cheveigne (2023) use :
%
%     out = exp_decheveigne2023('fig5');
%
%   References:
%     A. de Cheveigné. Simple and efficient auditory-nerve spike generation.
%     bioRxiv, 2023.
%     
%
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/experiments/exp_decheveigne2023.php


%   #Author: Alain de Cheveigne (2023): Original code
%   #Author: Alejandro Osses (2023): Adaptations for AMT 1.4
%   #Author: Alejandro Osses (2023): Uses the model decheveigne2023.m (AMT 1.5)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

definput.import={'amt_cache'};
definput.flags.type={'missingflag','fig1','fig2','fig3','fig5','fig3_old'};

% definput.flags.plot={'plot','no_plot'};
% definput.keyvals.models=[];

[flags,keyvals]  = ltfatarghelper({},definput,varargin);

if flags.do_missingflag
  flagnames=[sprintf('%s, ',definput.flags.type{2:end-2}),...
             sprintf('%s or %s',definput.flags.type{end-1},definput.flags.type{end})];
  error('%s: You must specify one of the following flags: %s.',upper(mfilename),flagnames);
end;

%%% fig1 required:
% spike_to_pulse.m renamed to decheveigne2023_spike_to_pulse.m
%   spike_train.m
%   spike_poisson.m
% spike_refractory.m

%%% fig2 required:
% spike_isih.m
% spike_ach.m
%   spike_cch.m

%%% fig3 required:
% spike_psth.m

%%% fig5 required:
% spike_vs

%%% fig6 required:
% spike_cancel
fg_default = {'no_refractoriness'}; % this is the default flag for decheveigne2023
    
%% ------ FIG 1 de Cheveigne 2023 -----------------------------------------
if flags.do_fig1

    % FigA.m
    max_rate=2000; % spikes/s
    sr=44100; % Hz, sampling rate of driving function
	f=100; % Hz
	D=10; % s
	drive=max(0,sin(2*pi*(1:round(sr*D)')/sr*f))*max_rate;
	reffun=0.001;
	nfibers=1;
	binwidth=0.0001;

    a=0; % tweak for visual effect
	rng(0); rand(a,1);
    insig_drive1 = max_rate*ones(size(drive)); % 'Rate equal to the peak of the driving function'
	
    % 'Homogeneous Poisson process with a rate equal to the peak of the 
    %    driving function procudes a train of spikes (black dots: p1)':
    p1 = decheveigne2023(insig_drive1,sr,fg_default{:}); 
    % % This new code replaces two commands:
    %       spikes1=decheveigne2023_spiketrain(insig_drive,sr); 
	%       p1 = decheveigne2023_spiketopulse(spikes1,sr);
    
    rng(0);  rand(a,1);
    insig_drive = drive;
    fg_refractoriness = {'refractoriness'};
    % Now we apply refractoriness, obtaining the train pulse in p3:
    [p3, outs_extra] = decheveigne2023(insig_drive,sr,fg_refractoriness{:});
    
    % We need to retrieve the train pulse p2 from the intermediate spikes:
    p2 = decheveigne2023_spiketopulse(outs_extra.output_spikes_before_refractoriness,sr);
    
	t=linspace(0,D,numel(drive))*1000;

    figure;
    clf; 
	subplot(2,1,1);
	plot(t,drive); xlim([0 30]); ylim([-100 2500]);
	set(gca,'fontsize',14);
	set(gca,'ytick', [0 1000 2000], 'xticklabel',[])
	ylabel('spikes/s');
	title('driving function');

    p1 = min(p1,1); % if there are multiple spikes, they will be visualised as one
    idx_null = find(p1==0); p1(idx_null) = nan; % samples with no spikes will be ignored
    
    p2 = min(p2,1);
    idx_null = find(p2==0); p2(idx_null) = nan; % samples with no spikes will be ignored
    
    p3 = min(p3,1);
    idx_null = find(p3==0); p3(idx_null) = nan; % samples with no spikes will be ignored
    
    subplot(2,1,2);
	plot(t(1:numel(p1)), p1*3, '.k'); hold on
    plot(t(1:numel(p2)), p2*2, '.b');  
    plot(t(1:numel(p3)), p3, '.r')
    
    xlim([0 30])
	ylim([0.5 3.5])
	set(gca,'fontsize',14);
	set(gca,'ytick', [], 'xtick',[0 10 20 30])
	xlabel('time (ms)');
	set(gca,'ycolor', [1 1 1], 'box','off');
	title('spike train');

    % disp(spike_rate(spikes3))

end

%% ------ FIG 2 de Cheveigne 2023 -----------------------------------------
if flags.do_fig2
    % Fig_B.m
    
    max_rate=400; % spikes/s
	sr=44100; % Hz, sampling rate of driving function
	f=100; % Hz
	D=600; % s
	drive=ones(round(sr*D),1)*max_rate;
	nfibers=1;
	binwidth=0.00005;

    recfun=0;
	[p1,outs1] = decheveigne2023(drive,sr,'recfun',recfun,fg_default{:});
    spikes1 = outs1.output_spikes;

    recfun=0.0009;
    [p2,outs2] = decheveigne2023(drive,sr,'recfun',recfun,fg_default{:});
    spikes2 = outs2.output_spikes;

    recfun=@local_example_recovery_function;
	[p3,outs3] = decheveigne2023(drive,sr,'recfun',recfun,fg_default{:});
    spikes3 = outs3.output_spikes;

	% disp([spike_rate(spikes1),spike_rate(spikes2),spike_rate(spikes3)])
	figure; clf
    subplot(1,2,1)
	[h,b]=decheveigne2023_spikeisih(spikes1,binwidth); % 'processing the data'
    stairs(b*1000,h/D,'k', 'linewidth',1); hold on;

    [h,b]=decheveigne2023_spikeisih(spikes2,binwidth); 
	stairs(b*1000,h/D,'b', 'linewidth',1); hold on;
	
    [h,b]=decheveigne2023_spikeisih(spikes3,binwidth); 
	stairs(b*1000,h/D, 'r', 'linewidth',1); hold on;
	xlim([0 5])
	set(gca,'fontsize',14)
	xlabel('inter-spike interval (ms)')
	ylabel('intervals/s')
	title('first-order ISI histogram')
	legend('Poisson','w dead time', 'w recovery','location','northeast'); legend boxoff

    subplot(1,2,2)
    [h,b] = decheveigne2023_spikeach(spikes1,binwidth); % old: spike_ach
	stairs(b*1000,h/D,'k', 'linewidth',1); hold on;

    [h,b] = decheveigne2023_spikeach(spikes2,binwidth); 
	stairs(b*1000,h/D,'b', 'linewidth',1); hold on;

    [h,b] = decheveigne2023_spikeach(spikes3,binwidth); 
    stairs(b*1000,h/D, 'r', 'linewidth',1); hold on;
	xlim([0 5])
	set(gca,'fontsize',14)
	xlabel('inter-spike interval (ms)')
	ylabel('intervals/s')
	title('all-order ISI histogram');

end

%% ------ FIG 3 de Cheveigne 2023 -----------------------------------------
if flags.do_fig3
    % Fig_C.xml
    
    max_rate=500; % spikes/s
	sr=44100; % Hz, sampling rate of driving function
	f=100; % Hz
	D=600; % s
	nfibers=1;
	binwidth=0.00005;
 
    drive=max(0,sin(2*pi*(1:round(sr*D)')/sr*f))*max_rate;
	
    recfun=[];
	[p1,outs1] = decheveigne2023(drive,sr,'recfun',recfun,'nfibers',nfibers,fg_default{:}); 
    spikes1 = outs1.output_spikes;
	
    recfun=@local_example_recovery_function;
	[p3,outs3] = decheveigne2023(drive,sr,'recfun',recfun,'nfibers',nfibers,fg_default{:}); 
    spikes3 = outs3.output_spikes;

    figure; clf
	set(gcf,'position',[145   793   800 300])

    subplot 131
	[h,b] = decheveigne2023_spikepsth(spikes1,binwidth, 0.01); hold on
    stairs(b*1000,h,'k');

    [h,b] = decheveigne2023_spikepsth(spikes3,binwidth, 0.01); hold on
	stairs(b*1000,h,'r', 'linewidth',1);
	ylim([0 2500])
	set(gca,'fontsize',14);
	set(gca,'ytick',[0 1000 2000]);
	xlabel('time (ms)')
	ylabel('count per bin');
	title('period histogram')
	% plot_tweak([0 0.1 0 -0.15])
	legend('w/o recovery', 'w recovery','location','northeast'); legend boxoff

    subplot 132
	[h,b] = decheveigne2023_spikeisih(spikes1,binwidth); hold on
    stairs(b*1000,h,'k');

    [h,b] = decheveigne2023_spikeisih(spikes3,binwidth);
    stairs(b*1000,h,'r', 'linewidth',1);
	xlim([0,25]); ylim([0 2500])
	set(gca,'fontsize',14);
	set(gca,'ytick',[]);
	xlabel('time (ms)')
	title('1st-order ISIH');
	% plot_tweak([0 0.1 0 -0.15])

    subplot 133
	[h,b] = decheveigne2023_spikeach(spikes1,binwidth, 0.025); hold on
    stairs(b*1000,h,'k');

    [h,b] = decheveigne2023_spikeach(spikes3,binwidth, 0.025);
    stairs(b*1000,h,'r', 'linewidth',1);
	xlim([0,25]); 
    ylim([0 2500])
	set(gca,'fontsize',14);
	set(gca,'ytick',[]);
	xlabel('time (ms)')
	title('all-order ISIH')
    % plot_tweak([0 0.1 0 -0.15])  
end

% %% ------ FIG 4 de Cheveigne 2023 -----------------------------------------
% if flags.do_fig4
%     % To be implemented
% end

%% ------ FIG 5 de Cheveigne 2023 -----------------------------------------
if flags.do_fig5
    % Fig_E.xml
	max_rate=1000; % spikes/s
	sr=44100; % Hz, sampling rate of driving function
	D=10; % s
	recfun=.001;
	nfibers=1;

    ff=50*2.^(0:0.5:8);
	vv=zeros(size(ff));

    sigmas=0.000025*[1 2 4];
    
    fg_jitter_but_no_refrac = {'no_refractoriness','jitter'};
    kv_here = {'recfun',recfun,'nfibers',nfibers};
    
    for iSigma=1:numel(sigmas)
        sigma=sigmas(iSigma);
        
        sigmas_str{iSigma} = num2str(1e6*sigma);
        
        for iF=1:numel(ff)
            f=ff(iF);
            drive=max(0,sin(2*pi*(1:round(sr*D)')/sr*f))*max_rate;
            [pulse_train,outs] = decheveigne2023(drive,sr, ...
                fg_jitter_but_no_refrac{:},kv_here{:},'sigma',sigma); 
            spikes = outs.output_spikes;
            
            vv(iF,iSigma)=decheveigne2023_spikevs(spikes,1/f);
        end
    end
    
    figure; clf
    semilogx (ff,vv(:,1), 'k:'); hold on
	semilogx (ff,vv(:,2), 'k', 'linewidth', 1);
	semilogx (ff,vv(:,3), 'k--');
	set(gca,'fontsize',14);
	set(gca,'ygrid','on','xgrid','on');
	ylabel('Vector strength');
	xlabel('Frequency (Hz)');
	legend( ['\sigma = ' sigmas_str{1} '\mu s'], ...
            ['\sigma = ' sigmas_str{2} '\mu s'], ...
            ['\sigma = ' sigmas_str{3} '\mu s'], ...
            'interpreter', 'tex', 'location','southwest'); legend boxoff
end

% %% ------ FIG 6 de Cheveigne 2023 -----------------------------------------
% if flags.do_fig6
%     % To be implemented
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ok=local_example_recovery_function(interval)
%ok=local_example_recovery_function(d) - example recovery function
%
%   ok: 0: delete, 1: keep
%
%   interval: (s) interspike interval
%
    
if interval<=0; error('!'); end

% the function is piecewise linear after a dead time

% 0.8 ms dead time
if interval<0.0009; 
	ok=0; 
   
    % full recovery after 5 ms
elseif interval>=0.005; 
    ok=1; 

    % probability of keeping varies from 0 to 0.5 from 0.9 to 1 ms
elseif interval<0.001;
    if rand<(interval-0.0009)/0.0001*0.5;
        ok=1;  
    else
        ok=0; 
    end
    
    % probability of keeping varies from 0.5 to 0.9 from 1 to 2 ms
elseif interval<0.002;
    if rand<0.5+(interval-0.001)/0.001*0.4;
        ok=1;  
    else
        ok=0; 
    end
    
    % probability of keeping varies from 0.9 to 1 from 2 to 5 ms
elseif interval>=0.002 && interval<0.005
    if rand<0.9+(interval-0.002)/0.003*0.1
        ok=1; 
    else
        ok=0; 
	end
end

