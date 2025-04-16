function [best_idx, BIC_diff, best_name] = frambi_test(metrics, names, do_disp)
%frambi_test Test and compare multiple model variants
%
%   Usage: [best_idx, BIC_diff] = frambi_test(metrics);
%          [best_idx, BIC_diff] = frambi_test(metrics, names);
%          [best_idx, BIC_diff, best_name] = frambi_test(metrics, names);
%          [...] = frambi_test(metrics, names, do_disp);
%
%   Input parameters:
%     metrics    : Cell array with each cell containing a structure with 
%                  the statistical results of the model variants as obtained  
%                  from FRAMBI_ESTIMATE:
%                  
%                  - loglik*: Log-likelihood of the estimation.
% 
%                  - BIC*: Bayesian information criterion of the estimation.
%                 
%     names     : Optional cell array containing names of each model variant. 
%                 Default: Index of the variant in metrics.
%
%     do_disp   : Optional binary flag to display the information 
%                 about the winning variant and its difference in BIC to the 
%                 second best variant. Default: True.
%
%   Output parameters:
%     best_idx  : Index of the model variant with the lowest BIC. 
%     BIC_diff  : Vector with BIC differences between the best variant and 
%                 all variants (including the best).
%     best_name : Name of the model with the lowest BIC value. 
%
%   FRAMBI_TEST(..) identifies the model variant with the lowest summed BIC, 
%   and optionally displays a statement about the winning variant. It returns 
%   the index and name of the best variant along with the BIC differences 
%   from the best variant to all variants (including the best variant).
%
%
%   See also: frambi_estimate exp_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_test.php


%   #Author: Roberto Barumerli (2023): Original implementation.
%   #Author: Roberto Barumerli (2024): Integration in the AMT. 
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% this function takes a cell matrix as an input
% the rows correspond to the subjects and the columns to the model variants
if ~exist("names", "var")
    names = string(1:size(metrics,2));
end
if ~exist("flag_print", "var")
    do_disp = true;
end

  % get all BICs
BICs = cellfun(@(x) x.BIC, metrics);

  % sum BICs over subjects 
BICs_group = sum(BICs, 1); 

  % find the model variant with lowest
[BIC_min, best_idx] = min(BICs_group);
BIC_diff = BICs_group-BIC_min;

  % return name or index
best_name = names{best_idx};   

  % display results
if do_disp
    amt_disp(sprintf('The model variant "%s" wins', best_name),'documentation');
    amt_disp(sprintf('  with a BIC difference of %.2f to the next best alternative.', ...
      min(BIC_diff(BIC_diff ~= 0))),'documentation');
end
