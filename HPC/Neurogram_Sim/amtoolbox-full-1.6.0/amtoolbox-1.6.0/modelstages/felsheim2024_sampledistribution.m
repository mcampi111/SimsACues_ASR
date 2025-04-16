function samples = felsheim2024_sampledistribution(dists, num_samples)
%felsheim2024_sampledistribution Samples distributions from the aLIFP model
% 
%   Usage: samples = felsheim2024_sampledistribution(spike_struct, num_samples)
% 
%   Input parameters:
%       dists:       Structure array describing the spike distributions as returned by the 
%                    aLIFP model FELSHEIM2024.
% 
%       num_samples: Number of samples to be drawn from each distribution.
% 
%   Output parameters:
%       samples:    Time points of the spikes samples from the distributions
% 
%   FELSHEIM2024_SAMPLEDISTRIBUTION(..) samples each distribution (in dists*) 
%   num_samples times. The interdependencies between facilitation and refractory 
%   periods of subsequent pulses is not considered. Therefore, sampling from 
%   the distribution is only meaningful for a large number of
%   samples. A discussion on this can be found in Felsheim et al. (2024). 
% 
%   See also: felsheim2024 exp_felsheim2024 demo_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/felsheim2024_sampledistribution.php


%   #Author: Rebecca C. Felsheim (2024): original implementation
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

    samples = zeros(num_samples * length(dists),1);
    last_ind = 1;
    
    for s_ind = 1:length(dists)
        draw1 = rand(num_samples,1);
    
        cum_weights = [-eps; cumsum(dists(s_ind).weights) * dists(s_ind).total_probability];
    
        for c_ind = 1:(length(cum_weights) - 1)
            nd = sum(draw1 > cum_weights(c_ind) & draw1 <= cum_weights(c_ind + 1));
    
            curr_samples = randn(nd,1) * dists(s_ind).sigma(c_ind) + dists(s_ind).mu(c_ind);
            samples(last_ind:last_ind + length(curr_samples) - 1) = curr_samples;
            last_ind = last_ind + length(curr_samples);
        
        end
    
    end
    
    samples = samples(1:(last_ind - 1));

end


