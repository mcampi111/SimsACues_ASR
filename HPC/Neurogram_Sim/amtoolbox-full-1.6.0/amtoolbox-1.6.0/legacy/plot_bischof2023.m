function [FIG,RESULTS_struct] = plot_bischof2023(RESULTS_struct, flags)
%PLOT_BISCHOF2023 plot results from Bischof et al. 2023
%   Usage: [FIG,RESULTS_struct] = plot_bischof2023(RESULTS_struct, flags)
%
%
%   Input parameters:
%        RESULTS_struct    : structure with all predicted SNRs, BMLDs and
%                            better ear SNRs for the experiment reported in
%                            Bischof et al. (2023)
%
%   Output parameters:
%       FIG             :  structure with all figure handles of the
%                          reproduced Figures
%       RESULTS_struct  :  structure with all predicted SNRs, BMLDs and
%                          better ear SNRs for the experiment reported in
%                          Bischof et al. (2023)
%
%
%   PLOT_BISCHOF2023
%   reproduces all figures of the paper related to the model and the
%   underlying experiment (Figure 3, Figure 4, Figure 7 & Figure 8) based on
%   the model predictions from bischof2023 and returns a structure containing
%   all figure handles and the results structure containing the model
%   predictions as well as the experimental data for further analysis
%
%
%   See also: bischof2023_filterbank data_bischof2023 exp_bischof2023
%
%
%   References:
%     N. Bischof, P. Aublin, and B. Seeber. Fast processing models effects of
%     reflections on binaural unmasking. Acta Acustica, 2023.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/legacy/plot_bischof2023.php


%   #Author: Norbert F. Bischof (2023)
%   #Author: Pierre G. Aublin
%   #Author: Bernhard Seeber (2023)
%   #Author: Joonas Guevara (2023): Plotting integrated in exp_bischof2023

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose.

error(['This funcion is deprecated and will be removed in the future. ' 10 ...
    'See exp_bischof2023 for the previous functionality.'])




