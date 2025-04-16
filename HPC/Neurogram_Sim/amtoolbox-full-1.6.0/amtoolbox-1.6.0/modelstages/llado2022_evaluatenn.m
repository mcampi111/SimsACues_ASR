function [y_est] = llado2022_evaluatenn(x_test,NN_pretrained)
%LLADO2022_EVALUATENN Evaluate the neural network
%   Usage: [y_est] = llado2022_evaluatenn(x_test,NN_pretrained)
%
%   Input parameters:
%     x_test             : Features of the test subset
%     NN_pretrained      : Pretrained network
%     hiddenLayerSize    : Size of the hidden layer
%
%   Output parameters:
%     y_est              : Estimated data
%
%   LLADO2022_EVALUATENN gives the estimation uncertainty of the neural
%   network
%
%   See also: llado2022 exp_llado2022 demo_llado2022
%
%   References:
%     Lladó, Pedro, Hyvärinen, Petteri, and Pulkki, Ville. Auditory
%     model-based estimation of the effect of head-worn devices on frontal
%     horizontal localisation. Acta Acust., 6:1, 2022.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/modelstages/llado2022_evaluatenn.php



%   #Requirement: NNET
%   #StatusDoc: Good
%   #StatusCode: Perfect
%   #Verification: Verified
%   #Requirements: MATLAB M - Communication Systems
%   #Author: Pedro Llado (2022)
%   #Author: Petteri Hyvärinen (2022)
%   #Author: Ville Pulkki (2022)
%   #Author: Piotr Majdak (2023): if Deep Learning Toolbox not available, load data from cache or throw an error

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

for iter = 1:NN_pretrained.nIter
    net_dir = NN_pretrained.preTrained_dir(1,end,iter).net;
    net_uncertainty = NN_pretrained.preTrained_uncertainty(1,end,iter).net;

    y_hat_dir(iter,:) = net_dir(x_test);
    y_hat_uncertainty(iter,:) = net_uncertainty(x_test);

end

clipPos = find(y_hat_dir < -90);
y_hat_dir(clipPos) = -90;
clipPos = find(y_hat_dir > 90);
y_hat_dir(clipPos) = 90;

y_est(:,1) = mean(y_hat_dir);
y_est(:,2) = mean(y_hat_uncertainty);
end


