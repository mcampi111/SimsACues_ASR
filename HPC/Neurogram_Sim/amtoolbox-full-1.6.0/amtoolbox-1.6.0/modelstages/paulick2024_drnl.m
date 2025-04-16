function out = paulick2024_drnl(x,CF,fs,subj,model)
%paulick2024_drnl Nonlinear peripheral processing (DRNL)
%
%   Usage: out = paulick2024_drnl(x, CF, fs, subj, model);
%
%   Input parameters:
%     insig : Audio signal. 
%     CF    : Center frequency (in Hz) of the auditory filter to be processed.
%     fs    : Sampling frequency (in Hz).
%     subj  : String describing the type of simulated subject:
%
%             - 'NH': Normal hearing. 
%
%             - 'HIx': Hearing impaired, without cochlear compression.
% 
%     model : String selecting the parametrization of the model: 
%
%             - 'paulick2024': Current version, as described in Paulick et al. (2024). 
%
%             - 'jepsen2008': Previous version, as described in Jepsen et al. (2008). 
%
%
%   Output parameters:
%     out   : Processed signal representing the velocity at the basilar membrane. 
%
%   See also: paulick2024 demo_paulick2024 exp_paulick2024
%
%   References:
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/paulick2024_drnl.php


%   #Author: Lily Paulick (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% calculate filter parameters 

% Initialize the parameter structures
linDRNLpar  = struct('parname',{},'vals',{}); % initialize linear paramater vector
nlinDRNLpar = struct('parname',{},'vals',{}); % initialize nonlinear paramater vector

linDRNLpar(1).parname = 'CF_lin';  linDRNLpar(2).parname = 'nGTfilt_lin';
linDRNLpar(3).parname = 'BW_lin';  linDRNLpar(4).parname = 'g';
linDRNLpar(5).parname = 'LP_lin_cutoff';  linDRNLpar(6).parname = 'nLPfilt_lin';

nlinDRNLpar(1).parname = 'CF_nlin';  nlinDRNLpar(2).parname = 'nGTfilt_nlin';
nlinDRNLpar(3).parname = 'BW_nlin';  nlinDRNLpar(4).parname = 'a';
nlinDRNLpar(5).parname = 'b';  nlinDRNLpar(6).parname = 'c';
nlinDRNLpar(7).parname = 'LP_nlin_cutoff';  nlinDRNLpar(8).parname = 'nLPfilt_nlin';

% Common parameters not subject to immediate change by HI
if strcmp(model,'jepsen2008')
    linDRNLpar(2).vals = 3;  % number of cascaded gammatone filters 
    linDRNLpar(6).vals = 4;  % no. of cascaded LP filters
    nlinDRNLpar(2).vals = 3; % number of cascaded gammatone filters
    nlinDRNLpar(8).vals = 3; % no. of cascaded LP filters in nlin path
elseif strcmp(model,'paulick2024')
    linDRNLpar(2).vals = 2;  % number of cascaded gammatone filters
    linDRNLpar(6).vals = 4;  % no. of cascaded LP filters
    nlinDRNLpar(2).vals = 2; % number of cascaded gammatone filters
    nlinDRNLpar(8).vals = 1; % no. of cascaded LP filters in nlin path
end

linDRNLpar(1).vals = 10^(-0.06762+1.01679*log10(CF)); % Hz, CF_lin,
linDRNLpar(3).vals = 10^(.03728+.75*log10(CF)); % Hz, BW_lin.
linDRNLpar(5).vals = 10^(-0.06762+1.01*log10(CF)); % Hz, LP_lin cutoff
nlinDRNLpar(1).vals = 10^(-0.05252+1.01650*log10(CF)); % Hz, CF_nlin
nlinDRNLpar(3).vals = 10^(-0.03193+.77*log10(CF)); % Hz, BW_nlin
nlinDRNLpar(7).vals = 10^(-0.05252+1.01650*log10(CF)); % LP_nlincutoff

switch subj
    case 'NH' % Model for normal-hearing CASP
        linDRNLpar(4).vals = 10^(4.20405 -.47909*log10(CF)); % g
        if CF<=1000
            nlinDRNLpar(4).vals = 10^(1.40298+.81916*log10(CF)); % a,
            nlinDRNLpar(5).vals = 10^(1.61912-.81867*log10(CF)); % b [(m/s)^(1-c)]
        else
            nlinDRNLpar(4).vals = 10^(1.40298+.81916*log10(1500)); % a,
            nlinDRNLpar(5).vals = 10^(1.61912-.81867*log10(1500)); % b [(m/s)^(1-c)]
        end
        nlinDRNLpar(6).vals = 10^(-.60206); % c, compression coeff
        
    case 'HIx' % Example HI listener with no compression
        linDRNLpar(4).vals = 10^(4.20405 -.47909*log10(CF)); % g
        nlinDRNLpar(4).vals = 0; % a,
        nlinDRNLpar(5).vals = 10^(1.61912-.81867*log10(CF)); % b [(m/s)^(1-c)]
        nlinDRNLpar(6).vals = .25; % c, compression coeff
end

%% COMPUTATION

% make sure input signal x is a row, this is necessary for the non-linear part
x = x(:).';

[GTlin_b,GTlin_a] = gammatone(linDRNLpar(1).vals,fs,linDRNLpar(2).vals,linDRNLpar(3).vals/audfiltbw(linDRNLpar(1).vals),'classic'); %get GT filter coeffs
[LPlin_b,LPlin_a] = butter(2,linDRNLpar(5).vals/(fs/2)); % get LP filter coeffs

[GTnlin_b,GTnlin_a] = gammatone(nlinDRNLpar(1).vals,fs,nlinDRNLpar(2).vals,nlinDRNLpar(3).vals/audfiltbw(nlinDRNLpar(1).vals),'classic'); %get GT filter coeffs
[LPnlin_b,LPnlin_a] = butter(2,nlinDRNLpar(7).vals/(fs/2)); % get LP filter coeffs

% ------------- linear part -------------- %
y_lin = x.*linDRNLpar(4).vals; % Apply linear gain
y_lin = filter(GTlin_b,GTlin_a,y_lin); % Gammatone filtering

for n = 1:linDRNLpar(6).vals % LP filtering
    y_lin = filter(LPlin_b,LPlin_a,y_lin);       
end
% --------- end of linear part ----------- %

% ----------- non-linear part ------------ %
y_nlin = x;
y_nlin = filter(GTnlin_b,GTnlin_a,y_nlin); % GT filtering before

% Broken stick nonlinearity
a = nlinDRNLpar(4).vals;
b = nlinDRNLpar(5).vals;
c = nlinDRNLpar(6).vals;

y_decide = [a*abs(y_nlin); b*(abs(y_nlin)).^c];
y_nlin = sign(y_nlin).* min(y_decide);

y_nlin = filter(GTnlin_b,GTnlin_a,y_nlin); % GT filtering after

for n = 1:nlinDRNLpar(8).vals % then LP filtering
    y_nlin = filter(LPnlin_b,LPnlin_a,y_nlin);           
end
% -------- end of non-linear part -------- %

out = (y_lin + y_nlin); % add linear & non-linear part

end 
% -------------------------------------------------------------------------

%% EOF


