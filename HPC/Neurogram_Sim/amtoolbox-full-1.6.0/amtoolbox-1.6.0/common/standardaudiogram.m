function [ACout, fout, category] = standardaudiogram(atype, fspec)
%standardaudiogram Standard audiograms for various hearing-loss types
%   Usage: [ACout, fout, category] = standardaudiogram(type)
%          [ACout, fout, category] = standardaudiogram(type, fspec)
% 
%   Input parameters:
%     type : 'N0' to 'N7' or 'S1' to 'S3' according to Bisgaard et al. (2010)
%     fspec : optional specification of frequencies
%
%   Output parameters:
%     ACout    : Hearing loss (in dB HL) as air conduction loss
%     fout     : Corresponding output frequencies (in Hz)
%     category : 'Mild', 'Moderate' etc, see below
%
%   Standard audiograms according to Bisgaard et al. (2010), with 
%   the additional type 'N0' describing normal hearing. 
%
%   The N-types describe the groups of flat and moderately sloping listeners
%   along the following category*:
%
%   - N0*: Normal
%   - N1*: Very mild
%   - N2*: Mild         
%   - N3*: Moderate   
%   - N4*: Moderate/severe
%   - N5*: Severe'          
%   - N6*: Severe'          
%   - N7*: Profound'
%
%   The S-types describe the groups of steep sloping listeners
%   along the following category*:
%
%   - S1*: Very mild
%   - S2*: Mild            
%   - S3*: Moderate/severe
%   
%   STANDARDAUDIOGRAM(type, fspec) outputs the hearing loss interpolated
%   for fspec frequencies along the logarithmic frequency scale. 
%
%
%
%   References:
%     N. Bisgaard, M. S. M. G. Vlaming, and M. Dahlquist. Standard Audiograms
%     for the IEC 60118-15 Measurement Procedure. Trends in Amplification,
%     14(2):113--120, jun 2010.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/standardaudiogram.php


%   #Author: Lars Bramslow (2024): original implementation
%   #Author: Nicolai Bisgaard (2024): approved for inclusion in AMT
%   #Author: Piotr Majdak (2024): integration in the AMT

%   #StatusDoc:
%   #StatusCode:
%   #Verification:
%   #Requirements: M-Signal

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 
 

% standard audiogram frequencies in paper
F =                     [250  375  500  750 1000 1500 2000 3000 4000 6000];
% audiograms in paper
all_aud = {...
'N0' 'Normal'           [  0    0    0    0    0    0    0    0    0    0]; ...
'N1' 'Very mild'        [ 10   10   10   10   10   10   15   20   30   40]; ...
'N2' 'Mild'             [ 20   20   20   22.5 25   30   35   40   45   50]; ...
'N3' 'Moderate'         [ 35   35   35   35   40   45   50   55   60   65]; ...
'N4' 'Moderate/severe'  [ 55   55   55   55   55   60   65   70   75   80]; ...
'N5' 'Severe'           [ 65   67.5 70   72.5 75   80   80   80   80   80]; ...
'N6' 'Severe'           [ 75   77.5 80   82.5 85   90   90   95  100  100]; ...
'N7' 'Profound'         [ 90   92.5 95  100  105  105  105  105  105  105]; ...
'S1' 'Very mild'        [ 10   10   10   10   10   10   15   30   55   70]; ...
'S2' 'Mild'             [ 20   20   20  22.5  25   35   55   75   95   95]; ...
'S3' 'Moderate/severe'  [ 30   30   35  47.5  60   70   75   80   80   85] ...
};

fout = F;
% find row
irow = find(ismember(all_aud(:,1), atype));
if isempty(irow)
    error(['Audiogram ' atype ' not found']);
end
category = all_aud{irow, 2};
ACin = all_aud{irow, 3};
ACout = ACin;

% interpolate/extrapolate to other f
if nargin > 1
    ACout = interp1(log(F), ACin, log(fspec), 'linear','extrap');
    fout = fspec;
end
