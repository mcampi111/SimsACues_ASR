function V = paulick2024_ihc(vel,fs)
%paulick2024_ihc Inner hair cell processing
%   Usage: V = paulick2024_ihc(vel, fs);
%
%   Input parameters:
%     vel: The basilar-membrane velocity as 
%          obtained from PAULICK2024_DRNL.
%     fs : Sampling frequency (in Hz). 
%
%   Output parameters:
%     V: Receptor potential (in V) at the output of the inner hair cells. 
%
%   PAULICK2024_IHC(..) calculates the output of the inner hair cell transduction 
%   stage. This is done in three main stages: 
%
%   1. Scaling applied to BM velocity.
%
%   2. Physiologically fitted function to convert to conductance.
%
%   3. Electrical circuit analogy to obtain receptor potential.
%
%   See also: paulick2024 demo_paulick2024 exp_paulick2024
%
%   References:
%     L. Paulick, H. Relaño-Iborra, and T. Dau. The Computational Auditory
%     Signal Processing and Perception Model (CASP): A Revised Version.
%     bioRxiv, 2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/paulick2024_ihc.php


%   #Author: Lily Paulick (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

N = size(vel,1); %length of signal
Ts = 1/fs;
nchannels = size(vel,2); 

ster_disp = db2mag(-105)*vel;

% met channel
EP = 90E-3; Cm = 12.5e-12;

% fast/slow K+
Gkf = 19.8e-9; Gks = 19.8e-9;
Ekf = -71e-3; Eks = -78e-3;

% MET CHANNEL
Gmet_max = 30e-9; x0 = 20e-9; s0 = 16e-9; s1 = 35e-9;
factor1 = exp((x0-ster_disp)/s0);
factor0 = exp((x0-ster_disp)/s1);
G = Gmet_max./(1+factor0.*(1+factor1));

% Intracellular Potential
V_rest = -0.05703; 
V_now = V_rest;

%pre charge 
zero_sample = round(fs*50e-3);
dummy = zeros(zero_sample,1) + 3.3514e-09;
for i = 1:zero_sample
        Imet = dummy(i,:).*(V_now-EP);
        Ik = Gkf*(V_now-Ekf);
        Is = Gks*(V_now-Eks);
        V_now = V_now - squeeze((Imet + Ik + Is))*Ts/Cm;         
end
V_precharg = V_now;

V = zeros(N,nchannels);
for ii=1:N
    Imet = -G(ii,:).*(V_now-EP);
    Ik = -Gkf*(V_now-Ekf);
    Is = -Gks*(V_now-Eks);
        V_now = V_now + (Imet + Ik + Is)*Ts/Cm;
        V(ii,:)=V_now;
end

V = V - V_precharg;

end


