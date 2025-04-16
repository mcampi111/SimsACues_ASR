function g = nalrp(htl,fhtl,f)
%nalrp Hearing-aid gains according to the NAL-RP prescription procedure
%
%   Usage: g = nalrp(htl,fhtl,f);
%
%   Input parameters:
%       htl:   Audiogram (in dB HL). Usually obtained from STANDARDAUDIOGRAM
%       fhtl:  Audiogram frequencies (in Hz). Usually [250 500 1000 1500 2000 3000 4000 6000].
%       f:     Vector with targetted frequencies (in Hz).
%
%   Output parameters:
%       g:     Prescribed real-ear insertion gains (REIGs, in dB) at frequencies f. Size the same as f.
%
%   NALRP(..) returns gains as prescribed by the National Acoustics Laboratory (NAL)
%   in their revised profound (RP) prescription procedure. 
%   The prescribed gains will be interpolated on the log-frequency scale to
%   match frequencies in f. Note that NALRP does not account for the conduction loss.
% 
%
%   See also: standardaudiogram bramslow2004
%
%   References:
%     H. Dillon. Hearing Aids. Thieme;Boomerang Press, New York; Sydney, 2
%     edition, 2012.
%     
%     D. Byrne and H. Dillon. The National Acoustic Laboratories' (NAL) new
%     procedure for selecting the gain and frequency response of a hearing
%     aid. Ear and Hearing, 7:257--265, 1986.
%     
%     D. Byrne, A. Parkinson, and P. Newall. Modified Hearing Aid Selection
%     Procedures for Severe/Profound Hearing Losses. In The Vanderbilt
%     Hearing-Aid Report II, pages 295--300. York Press, 1991.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/nalrp.php


%   #Author: Arne Leijon (2006) tested
%   #Author: Giso Grimm (2007) modified
%   #Author: Arne Leijon (2024): aproved for inclusion in AMT   
%   #Author: Lars Bramslow (2024): adapted for AMT
%   #Author: Piotr Majdak (2024): adapted for the AMT 1.6

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

  f=f(:);%must be column vector
  htl = htl(:);
  fhtl = fhtl(:);

  fPrescr=[250 500 1000 1500 2000 3000 4000 6000]';
  ifP500=2;ifP1000=3;ifP2000=5;%indices into fPrescr
  gainZero=[-17 -8 1 1 -1 -2 -2 -2]';%NAL speech-equalizing REIG for HTL=0
  gainFactor=0.31;%times hearing loss, at each freq
  gainFactorM=0.15;%times 3-freq average hearing loss
  gainFactorP=0.20;%times 3-freq average part exceeding 60 dB HL
  
  %gain increases as 46% of HTL below 60, and 66% above 60 dB HL
  hSevere2000=[95 100 105 110 115 120]';%severe loss at 2000 Hz
  gSevere=[4 3 0 -1 -2 -2 -2 -2 ;...%Byrne et al(1991), Fig 9.
           6 4 0 -2 -3 -3 -3 -3 ;...
           8 5 0 -3 -5 -5 -5 -5;...
           11 7 0 -3 -6 -6 -6 -6;...
           13 8 0 -4 -8 -8 -8 -8;...
           15 9 0 -5 -9 -9 -9 -9];
  %corrections for high loss at 2000 Hz

  %extrapolate
  fhtl=[1;fhtl;20000];
  %extrapolate
  htl=[htl(1);htl;htl(end)];

  hLoss=interp1(log(fhtl),htl,log(fPrescr));
  hLoss3FA=mean(hLoss([ifP500,ifP1000,ifP2000]));%500, 1000, 2000 Hz
  gPrescr=gainFactor*hLoss+gainFactorM*hLoss3FA+gainZero;%NAL-R original

  if hLoss3FA>60%NAL-RP correction for severe loss
    gPrescr=gPrescr+gainFactorP*(hLoss3FA-60);
  end
  if hLoss(ifP2000)>=95%add extra NAL-RP correction
    gPrescr=gPrescr+(interp1(hSevere2000,gSevere,hLoss(ifP2000)))';
  end
  gPrescr=max(0,gPrescr);%no negative REIG

  fPrescr=[realmin;50;fPrescr;10000;100000];%extend for extrapolation
  gPrescr=[0;0;gPrescr;0;0];%extend for extrapolation
  g=interp1(log(fPrescr),gPrescr,log(f));%single column vector

