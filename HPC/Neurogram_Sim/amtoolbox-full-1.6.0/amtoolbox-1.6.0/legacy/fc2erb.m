function erbrate = fc2erb(fc)
%fc2erb Calculate the ERB rate for an auditory filter according to Glasberg and Moore (1990)
%
%   Usage: erbrate = fc2erb(fc)
%
%   FC2ERB accepts a vector of center frequencies
%   fc as an input and converts them to their index
%   on the ERB scale in [cam].
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/legacy/fc2erb.php


%   #Author: Clara Hollomey (2021): original implementation
%   #Author: Piotr Majdak (2024): integrated in f2erbrate as the glasberg1990 model. 

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

warning(sprintf(['fc2erb has been integrated in erbrate2f.\n', ...
                 'It will be removed in the future...']));
	
erbrate = 21.366*log10(0.004368.*fc + 1);



