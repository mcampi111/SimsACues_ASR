function M = rodriguesrotation(vector, theta)
%RODRIGUESROTATION 
%
%   M = rodriguesrotation(vector)
%   
%
% Input parameters:
%   vector              vector in cartesian coordinates [x,y,z]
%   theta               (optional) angle in radiants 
%   
% Output paramenters
%   M                   rotation matrix 
%
%   This function applies Rodrigues' formula to generate a rotation matrix 
%   to rotate by theta along the provided vector. If angle is not provided, 
%   the amount of rotation is extracted from the vector's norm. For further reading, check 
%   Matrix notation section in https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
%
%   #Author: Roberto Barumerli (2022)
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/rodriguesrotation.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

    if ~exist('theta', 'var')
        theta = norm(vector);
    end
    
    % initialize rotation matrix as identity
    M =  eye(length(vector));

    % theta below numerical precision? If yes, return identity matrix
    % (i.e. no rotation)
    if (theta < 1e-9) 
        return
    end

    % normalize vector
    v = vector ./ norm(vector);
    v = v(:);

    % anti-asymmetric matrix 
    % https://mathworld.wolfram.com/RodriguesRotationFormula.html
    K = [ 0    -v(3)  v(2); ...
          v(3)  0    -v(1);...
         -v(2)  v(1)  0];

    % generate rotation matrix
    M = eye(length(v)) + sin(theta)*K + (1-cos(theta))*K^2; % Rodrigues' formula

    M = M';
end    


