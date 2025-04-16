function [obj_mon_norm, obj_bin_norm] = eurich2024_backend(features,nfilt)
%eurich2024_backend Backend stage of the eMoBi-Q model eurich2024
%   Usage: [d_mon, d_bin] = eurich2024_backend(features, nfilt)
%
%   Input parameters:
%     features:        A structure describing the model's features obtained
%                      from eurich2024:
% 
%                      - d_gamma: [m x n] matrix with gamma feature for m time frames and n frequency bands
%
%                      - d_ild: [m x n] matrix with ild feature for m time frames and n frequency bands
%
%                      - d_snr: [m x n] matrix with snr feature for m time frames and n frequency bands
%
%     nfilt:           Desired number of filters per ERB
%
%   
%   Output parameters:
%     d_mon:   vector containing dprime of monaural pathway, see Eq. 10 in Eurich et al. (2024)
%     d_bin:   vector containing dprime of binaural pathway, see Eq. 9 in Eurich et al. (2024)
%
%
%   See also: eurich2024 exp_eurich2024
%
%   References:
%     B. Eurich, S. D. Ewert, M. Dietz, and T. Biberger. A computationally
%     efficient model for combined assessment of monaural and binaural audio
%     quality. Journal of the Audio Engineering Society, 100(4):2381--2396,
%     June 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/eurich2024_backend.php


%   #Author: Bernhard Eurich (2024): original implementation
%   #Author: Piotr Majdak (2024): adaptation to AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


  % load model parameters
mpar = arg_eurich2024;
mpar.desired_filters_per_ERB = nfilt;

  % preallocate
obj_gamma_mult = zeros(size(features,1),size(features,2),16,size(features(1,1).data_gamma,2));
obj_ild_mult = obj_gamma_mult;

  % read the features 
for aa = 1:size(features,1)
    for bb = 1:size(features,2)       
        obj_gamma_mult(aa,bb,1:size(features(aa,bb).data_gamma,1),1:size(features(aa,bb).data_gamma,2)) = features(aa,bb).data_gamma;
        obj_ild_mult(aa,bb,1:size(features(aa,bb).data_ild,1),1:size(features(aa,bb).data_ild,2))       = features(aa,bb).data_ild;
        if size(features(aa,bb).data_mon,3) == 2
            obj_mon_mult(aa,bb,1:size(features(aa,bb).data_mon,1),1:size(features(aa,bb).data_mon,2))       = mean(features(aa,bb).data_mon,3);
        else
            obj_mon_mult(aa,bb,1:size(features(aa,bb).data_mon,1),1:size(features(aa,bb).data_mon,2))       = features(aa,bb).data_mon;
        end
    end
end


  % limiting ILDs to 10 dB (d')
if any(obj_ild_mult(:))
    obj_ild_mult = min(obj_ild_mult,2*mpar.ild_lim);
end

  % sparsing filter bands if requested
old_fc = features(1,1).mpar.center_frequencies_hz;

if mpar.desired_filters_per_ERB < features(1,1).mpar.GT_filters_per_ERBaud
    sFB_sparse = hohmann2002(features(1,1).mpar.fs,features(1,1).mpar.GT_lowest_center_frequency,...
        features(1,1).mpar.GT_fix_center_frequency,features(1,1).mpar.GT_highest_center_frequency, mpar.desired_filters_per_ERB,'bandwidth_factor',features(1,1).mpar.GT_bwfactor);
    new_fc = sFB_sparse.center_frequencies_hz;

    for aa = 1:length(new_fc)
        n=33;
        [val,idx(aa)]=min(abs(old_fc-new_fc(aa)));
        minVal(aa)=old_fc(idx(aa));
    end

elseif mpar.desired_filters_per_ERB == features(1,1).mpar.GT_filters_per_ERBaud
    new_fc = old_fc;
    idx = 1:size(obj_gamma_mult,4);
else
    error('You requested more filters than available!')
end

  % preallocate with NaN so that dimensions are preserved
obj_gamma_mult_sparse = NaN(size(obj_gamma_mult(:,:,:,idx)));
obj_ild_mult_sparse = NaN(size(obj_ild_mult(:,:,:,idx)));
obj_mon_mult_sparse = NaN(size(obj_mon_mult(:,:,:,idx)));


obj_gamma_mult_sparse(:,:,:,idx) = obj_gamma_mult(:,:,:,idx);
obj_ild_mult_sparse(:,:,:,idx) = obj_ild_mult(:,:,:,idx);
obj_mon_mult_sparse(:,:,:,idx) = obj_mon_mult(:,:,:,idx);


%% Evaluation

  % combination across frames and channels (Eq. 8)
for aa = 1:size(features,1)
    for bb = 1:size(features,2)       
        obj_gamma_temp = squeeze(obj_gamma_mult(aa,bb,:,idx));
        obj_gamma_temp = sqrt(sum(obj_gamma_temp.^2,2,'omitnan'));
        obj_gamma(aa,bb) = sqrt(sum(obj_gamma_temp.^2,'omitnan'));
        
        obj_ild_temp = squeeze(obj_ild_mult(aa,bb,:,idx));

        % if desired, only use ILDs for, e.g., frequency bands beyond the rolloff
        features(1).mpar.mso_rolloff = 1300; % delete after next model run
        [~,filters_below_rolloff] = find(features(1).mpar.center_frequencies_hz < features(1).mpar.mso_rolloff);
        obj_ild_temp(:,filters_below_rolloff) = 0;

        obj_ild_temp = sqrt(sum(obj_ild_temp.^2,2));
        obj_ild(aa,bb) = sqrt(sum(obj_ild_temp.^2,'omitnan'));
        obj_mon_temp = squeeze(mean(obj_mon_mult(aa,bb,:,idx),3,'omitnan'));
        obj_mon(aa,bb) = sqrt(sum(obj_mon_temp .^2));
    end
end
  % combine binaural features (Eq. 9)
weighted_ild = mpar.ild_weight.*obj_ild;
obj_bin = sqrt(obj_gamma.^2 + weighted_ild.^2);

%% Normalization

mon_min = mpar.mon_min;
mon_max = mpar.mon_max;
bin_min = mpar.bin_min;
bin_max = mpar.bin_max;

  % limit to pre-defined range, normalize to [1 0] (Eq. 10)
obj_mon_lim=min(max(10*log10(obj_mon)+10,mon_min),mon_max); 
obj_mon_norm = 1-((obj_mon_lim-mon_min)./(mon_max-mon_min));

obj_bin_lim = min(max(obj_bin,bin_min),bin_max); 
obj_bin_norm = 1-((obj_bin_lim-bin_min)./(bin_max-bin_min));


