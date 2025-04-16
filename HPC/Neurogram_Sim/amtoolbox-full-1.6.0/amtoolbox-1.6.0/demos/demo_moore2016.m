%demo_moore2016 Demo of the binaural loudness model
%
%   DEMO_MOORE2016 demonstrates how to compute and visualize 
%   the binaural loudness using the model Moore et al. (2016). 
%   This demonstration is very limited currently. It will be expanded
%   in the future. 
%
%   Figure 1: Loudness
% 
%      Long-term and short-term loudness (in sone). 
%
%   See also: moore2016
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/demos/demo_moore2016.php


%   #Author: Clara Hollomey (2021): Original implementation (for testing)
%   #Author: Piotr Majdak (2024): Reimplementation for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

fs = 32000;
s = sig_tone(1000, 0.1, fs);
s = fade(s,0.01,fs);
s = s * scaletodbspl(40);
[ShortTermLoudness, LongTermLoudness] = moore2016([s s]);
  % plot the results
figure;
plot( 0:(length(ShortTermLoudness)-1), ShortTermLoudness, 'b-' );
hold on;
plot( 0:(length(ShortTermLoudness)-1), LongTermLoudness, 'r-' );
xlabel('Time (in ms)');
ylabel('Loudness (in sone)');
legend('Short-term loudness','Long-term loudness' );
title('Loudness for a 40-dB tone'); 



