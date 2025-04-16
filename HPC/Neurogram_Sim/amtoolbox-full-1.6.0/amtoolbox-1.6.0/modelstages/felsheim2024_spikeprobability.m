function values = felsheim2024_spikeprobability(dists, max_time, fs, mode)
%felsheim2024_spikeprobability Instantaneous spike probability from the aLIFP-model distributions
% 
%   Usage:  values = felsheim2024_spikeprobability(dists);
%           values = felsheim2024_spikeprobability(dists, max_time);
%           values = felsheim2024_spikeprobability(dists, max_time, fs);
%           values = felsheim2024_spikeprobability(dists, max_time, fs, mode);
% 
% 
%   Input parameters: 
%       dists:     Structure array describing the spike distributions as returned by the 
%                  aLIFP model FELSHEIM2024.
% 
%       max_time:  Optional maximum point in time (in s) for which the instantaneous spike 
%                  probability will be obtained. Default: The largest mean of the Gaussian 
%                  mixtures plus 5-fold largest standard deviation of the Gaussian mixtures. 
% 
%       fs:        Optional sampling frequency of the instantaneous spike probability.
%                  Default: 1 MHz.
% 
%       mode:      Optional flag for speeding up the calculations:
%
%                  - 'accurate': Evalute each Gaussian distribution for the whole time of 
%                    interest. This is more accurate, but might take a long to calculate. Default.
% 
%                  - 'fast': Distributions are only evaluated up to six times their 
%                    standard deviation. This can reduce the computational time massively, 
%                    but might be slightly  less accurate.
%  
%   FELSHEIM2024_SPIKEPROBABILITY(..) obtains the instantaneous spike probability in each sampled time
%   point by evaluating the Gaussian mixtures described by the structure dists. 
% 
%   See also: felsheim2024 exp_felsheim2024 demo_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/felsheim2024_spikeprobability.php


%   #Author: Rebecca C. Felsheim (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


    
    int_max_time =  max([dists(end).mu]) + 5 * max([dists(end).sigma]);
    if nargin < 2
        max_time = int_max_time;
    end
    if nargin < 3
        fs = 1e6;
    end

    if nargin < 4
        mode = 'accurate';
    end
	
	if strcmp(mode,'fast'), do_fast = 1; else do_fast=0; end
    
    int_max_time = max(int_max_time, max_time);
    time = 0:(1/fs):int_max_time;
    start = 1;
    stop = length(time);
    values = zeros(size(time));
    for curr_struct = dists
        if do_fast
            start = round(max(0, max(curr_struct.mu) - 6 * max(curr_struct.sigma)) * fs + 1);
            stop = min(length(time),round((max(curr_struct.mu) + 6 * max(curr_struct.sigma)) * fs + 1));
        end
        
        y = zeros(size(time(start:stop)));

        for ind = 1:length(curr_struct.mu)
            v = normpdf(time(start:stop), curr_struct.mu(ind), curr_struct.sigma(ind)) * curr_struct.weights(ind);
            y = y + v;
        end

        y(isnan(y)) = 0;
        if sum(y) > 0
            y = y / sum(y);
        end
        values(start:stop) = values(start:stop) + y * curr_struct.total_probability;
    end

    t_ind = time <= max_time;
    values = values(t_ind);
end
