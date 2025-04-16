function [sLoud, lLoud, mLoud] = moore2016(insig)
%moore2016 Binaural loudness model
%   Usage: [sLoud, lLoud, mLoud] = moore2016(insig)
%
%   Input parameters:
%     insig : Binaural audio signal (in Pa) sampled at the rate of 32 kHz. 
%             Size: (*samples ear*). 
%             Optionally, insig can be a column vector, 
%             which will be then interpreted as a diotic signal. 
%                   
%
%   Output parameters:
%     sLoud : Column vector with the time-varying short-term loudness (in sone). 
%             Size: time (in ms).
%     lLoud : Column vector with the time-varying long-term loudness (in sone). 
%             Size: time (in ms).
%     mLoud : Maximal long-term loudness (in sone).
%
%   MOORE2016(..) calculates loudness according to the model described by Moore et 
%   al. (2016), but with the modified time constants described by Moore et al. (2018). 
%   Under the hood, the signal insig is filtered by an outer and middle ear filter, then 
%   the short-term spectra and excitation patterns are calculated, as well as a compressive nonlinearity 
%   and a smoothing over time are applied. The short-term loudness is calculated as the sum 
%   of the ear-specific short-term loudness. The ear-specific long-term loudness 
%   is calculated based on the short-term loudness and the binaural long-term loudness
%   is calculated as the sum of the ear-specific long-term loudness. 
%
%
%   The original code was written for ANSI S3.4-2007, 
%   based on Moore et al. (1997) and Glasberg and Moore (2006) and ISO 532-2 (2017), based 
%   on Moore and Glasberg (2007).
%
%   *Note:* Most of the parameters are hard coded and the model structure is not optimal yet because
%   the implementation is not complete yet.
%
%   See also: f2erb moore2016_monauralinstspecloudness
%             moore2016_agcnextframe moore2016_longtermloudness moore2016_binauralloudness
%             moore2016_spectrum moore2016_excitationpattern 
%             moore2016_shorttermspecloudness
%
%   References:
%     B. C. J. Moore, M. Jervis, L. Harries, and J. Schlittenlacher. Testing
%     and refining a loudness model for time-varying sounds incorporating
%     binaural inhibition. The Journal of the Acoustical Society of America,
%     143(3):1504--1513, 03 2018.
%     
%     B. R. Glasberg and B. C. J. Moore. A Model of Loudness Applicable to
%     Time-Varying Sounds. J. Audio Eng. Soc, 50(5):331--342, 2002.
%     
%     B. C. J. Moore, B. R. Glasberg, and T. Baer. A Model for the Prediction
%     of Thresholds, Loudness, and Partial Loudness. J. Audio Eng. Soc,
%     45(4):224--240, 1997.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/models/moore2016.php


%   #StatusDoc: OK
%   #StatusCode: OK
%   #Verification: Unknown
%   #Requirements: M-Signal
%   #Author: Josef Schlittenlacher (2018): Original implementation provided for the AMT.
%   #Author: Clara Hollomey (2021): Integration in the AMT. 
%   #Author: Michael Mihocic (2024): Unit of output parameters fixed.
%   #Author: Piotr Majdak (2024): Code and documentation rework for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


  % defaults
Fs = 32000;
dBMax = dbspl(1);

  %calculate the outer/middleear filtering
data = amt_load('moore2016', 'ff_32000.mat');
vecCoefficients = data.vecCoefficients;
out(:,1) = conv( vecCoefficients, insig(:,1) );
if size(insig,2)==2
    out(:,2) = conv( vecCoefficients, insig(:,2) );
else
    out(:,2) = out(:,1);
end
insig2 = out((1025):(end-1024),:);

  %calculate the short term loudness
[instSpecLoudL, instSpecLoudR] = moore2016_monauralinstspecloudness( insig2, Fs, dBMax );

  %remove NANs (only necessary because the first value tends to be one, at least in Octave)
instSpecLoudL(find(isnan(instSpecLoudL ))) = 0;
instSpecLoudR(find(isnan(instSpecLoudR ))) = 0;

sSpecLoudL  = moore2016_shorttermspecloudness( instSpecLoudL );
sSpecLoudRight = moore2016_shorttermspecloudness( instSpecLoudR );

sLoudL  = zeros( size( sSpecLoudL, 1 ), 1 );
sLoudR = zeros( size( sSpecLoudRight, 1 ), 1 );

  %calculate the binaural loudness
for i = 1:size( sSpecLoudL, 1 )
    [~, sLoudL(i), sLoudR(i)] = moore2016_binauralloudness( sSpecLoudL(i,:), sSpecLoudRight(i,:) );
end
  %calculate the long term loudness
lLoudL   = moore2016_longtermloudness( sLoudL );
lLoudR  = moore2016_longtermloudness( sLoudR );
  % output
lLoud = lLoudL + lLoudR;
mLoud = max(lLoud);
sLoud = sLoudL + sLoudR;

