%demo_baumgartner2021 Demonstration of the externalization model BAUMGARTNER2021
%
%   DEMO_BAUMGARTNER2021 demonstrates how to apply the model in
%   order to estimate perceived externalization deterioration following
%   spectral distortions based on the example of using non-individualized
%   HRTFs for binaural headphone reproduction.
%
%   Figure 1: Degree of externalization predicted for subject S01 listening to HRTFs from other subjects Sxx.
%
%   See also: baumgartner2021 exp_baumgartner2021 
%
%   References:
%     R. Baumgartner and P. Majdak. Decision making in auditory
%     externalization perception: model predictions for static conditions.
%     Acta Acustica, 5:59, 2021. Publisher: EDP Sciences.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_baumgartner2021.php


%   #Author: Robert Baumgartner (2021): Integrated in the AMT.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%% Settings

subjNum = 1;    % choose target listener by number (1 through 23)
lat = 0;        % lateral target angle in degrees
   

%% Get listener's data

data = data_baumgartner2017looming('hrtf');   % load frontal horizontal-plane HRTFs of listener pool
Nsubj = length(data);


%% Run model to get externalization scores for every HRTF

template = data(subjNum).Obj;
E = nan(Nsubj,1);
amt_disp(''); % start of volatile display
for ids = 1:Nsubj
  target = data(ids).Obj;
  E(ids) = baumgartner2021(target,template,'lat',lat);
  amt_disp(['Processing subject #' num2str(ids),' out of ',num2str(Nsubj)],'volatile')
end
amt_disp(); % end of volatile display
%% Plot results

figure;
bar(100*E)
set(gca,'XTick',1:Nsubj,'XTickLabel',{data.id})
ylabel('Degree of externalization (%)')
xlabel('HRTFs from subject')


