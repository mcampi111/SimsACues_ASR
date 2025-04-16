function data = data_mclachlan2023(varargin)
%data_mclachlan2023  Responses from a dynamic sound-localization experiment (basic)
%   Usage: data = data_mclachlan2023(condition);
%          data = data_mclachlan2023(condition, id);
%
%   Input parameters:
%     condition: Optional condition of the experiment: 
%
%                - 'static': Static localization, i.e., the head rotations of 
%                  the subjects were not tracked and the subjects had to keep the 
%                  head still. Default. 
%           
%                - 'dynamic': Dynamic localization, i.e., the head rotations 
%                  of the subjects were tracked and the subjects had to rotate their head
%                  in a specified direction. 
%
%     id: Optional string specifying the subject ID. It can be one of 
%         the following: 'NH257', 'NH714', 'NH919', 'NH963', 
%         'NH983', 'NH1016', 'NH1017'. Default: All subjects.
%
%   Output parameters: 
%     data: Structure array with the following fields for each subject: 
%
%           - id*: ID of the subject.
%        
%           - HRTF*: SOFA structure with the subject's HRTFs.
%        
%           - T*: Cell array with head rotations. Size: (*trial*). Per trial, each 
%             cell has the size: (*time x pos*), with time being unclear and pos 
%             representing the head direction in columns:
%
%             - 1*: Azimuth angle (in degrees). 
%
%             - 2*: Elevation angle (in degrees). 
%
%             - 3*: Radius (in m). 
%        
%           - m*: Matrix with the behavioral responses. Size: (*trial x C x P*). 
%        
%
%   The dimension C encodes the data obtained in each trial*:
%
%   - 1 and 2*: Target azimuth and elevation (in degrees).
%   - 3 and 4*: Response azimuth and elevation (in degrees). 
%   - 5 and 6*: Target lateral and polar angles (in degrees).
%   - 7 and 8*: Response lateral and polar angles (in degrees). 
%   - 9, 10, and 11*: Target Cartesian coordinates X, Y, and Z (Units unclear). 
%   - 12, 13, and 14*: Response Cartesian coordinates X, Y, and Z (Units unclear). 
%   - 15*: Trial duration (probably in ms, however, unclear). 
%   - 16*: Required head-rotation direction (uncoding unclear). 
%   - 17*: Subject number. Meaning unclear. 
%
%
%   The dimension P encodes the experiment condition: 
%
%   - 1*: Flat, i.e., signals presented via headphones with no spectral cues in the HRTFs.
%   - 2*: Full, i.e., signals presented via headphones with full HRTFs. 
%   - 3*: VBAP, i.e., signals presented via loudspeakers. 
%   - 4*: Fixed, i.e., signals presented via headphones with no dynamic changes 
%     in the spectral cues in the HRTFs. Only available when condition is 'dynamic'. 
%
%   DATA_MCLACHLAN2023(..) returns data from McLachlan et al. (2023),
%   which describes results from a sound-localization experiment done under 
%   static and dynamic conditions, i.e., without and with head rotations, 
%   respectively. The focus of this study was four HRTFs conditions with 
%   many spatial targets, as in contrast to McLachlan et al. (2024). 
%
%   See also: data_mclachlan2024
%
%   References:
%     G. McLachlan, P. Majdak, J. Reijniers, M. Mihocic, and H. Peremans.
%     Dynamic spectral cues do not affect human sound localization during
%     small head movements. Frontiers in Neuroscience, 17, 2023.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/data/data_mclachlan2023.php


%   #Author: Glen McLachlan (2024). Original implementation. 
%   #Author: Piotr Majdak (2024). Adaptations for AMT 1.6.


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% % Parse input options
definput.flags.type = {'static','dynamic'};
definput.flags.subject = {'all','NH257','NH714','NH919','NH963','NH983','NH1016','NH1017'};
flags = ltfatarghelper({},definput,varargin);
   
dataPath = 'mclachlan2023';
if flags.do_all
  subject=definput.flags.subject(2:end); 
else
  subject={flags.subject};
end

for sub=1:length(subject)

    data(sub).id=subject{sub};
    data(sub).HRTF=amt_load(dataPath,[subject{sub} '_hrtf_Nd=0.sofa']);

    if flags.do_static
          % load tracker data
        temp=amt_load(dataPath,[subject{sub} '_s_tracker.mat']);
        data(sub).T=temp.T;
          % load localisation data
        temp=amt_load(dataPath,[subject{sub} '_s_loca.mat']); %(:,:,1)=flat, (:,:,2)=full, (:,:,3)=VBAP 				
        data(sub).m=temp.m_s;
    elseif flags.do_dynamic
          % load tracker data
        temp=amt_load(dataPath,[subject{sub} '_d_tracker.mat']);
        data(sub).T=temp.T;
          % load localisation data
        temp=amt_load(dataPath,[subject{sub} '_d_loca.mat']); %(:,:,1)=flat, (:,:,2)=full, (:,:,3)=fixed, (:,:,4)=VBAP
				data(sub).m(:,:,1) = temp.m_d(:,:,1); %flat
				data(sub).m(:,:,2) = temp.m_d(:,:,2); %full
				data(sub).m(:,:,3) = temp.m_d(:,:,4); %vbap
				data(sub).m(:,:,4) = temp.m_d(:,:,3); %fixed        
    else
      error('No flag provided.')
    end
end


end
