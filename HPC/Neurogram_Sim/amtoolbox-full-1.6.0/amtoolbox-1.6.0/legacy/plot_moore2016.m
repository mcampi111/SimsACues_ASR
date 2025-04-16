function plot_moore2016(ShortTermLoudness, LongTermLoudness,varargin)
%PLOT_MOORE2016 plots from Moore et al. 2016
%
%   Usage:
%     plot_moore2016(ShortTermLoudness, LongTermLoudness)
%
%   Input parameters:
%     ShortTermLoudness   : as calculated by Moore2016 [sone]
%     LongTermLoudness    : as calculated by Moore2016  [sone]
%
%
%   This function plots the long term- and short term loudness (in Sone).
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/legacy/plot_moore2016.php


%   #StatusDoc: OK
%   #StatusCode: Submitted
%   #Verification: Unknown
%   #Requirements: M-Signal
%   #Author: Josef Schlittenlacher (2018): original code
%   #Author: Clara Hollomey (2021): integration in the AMT
%   #Author: Piotr Majdak (2024): removed because a simple plot of two lines.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%filenameSound = 'testSound';
%filenameFilter = 'default';
%dBMax = 100; 

warning(sprintf(['This function plots just two simple lines.\n', ...
                 'It will be removed in the future...']));
	

figure;
plot( 0:(length(ShortTermLoudness)-1), ShortTermLoudness, 'b-' );
hold on;
plot( 0:(length(LongTermLoudness)-1), LongTermLoudness, 'r-' );
xlabel( 'time [ms]');
ylabel( 'Loudness [sone]');
legend( 'Short-term loudness','Long-term loudness' );


