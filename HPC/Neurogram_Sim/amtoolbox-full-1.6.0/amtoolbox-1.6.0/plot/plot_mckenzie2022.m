function plot_mckenzie2022(spectralDifference,testDirections)
%PLOT_MCKENZIE2022 Heatmap of spherical data plotted on a rectangular plot
%
%   Usage:
%     plot_mckenzie2022(data, directions);
%
%   Input parameters:
%     data          : vector to be plotted
%     directions    : directions [az el] in degrees
%
%   This function generates a heatmap of a large spherical set of points 
%   plotted on a rectangular plot. 
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/plot/plot_mckenzie2022.php


%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #Requirements: MATLAB M-Stats M-Curvefit
%   #Author: Thomas McKenzie (2022): initial implementation
%   #Author: Cal Armstrong (2022): initial implementation
%   #Author: Lauren Ward (2022): initial implementation
%   #Author: Damian Murphy (2022): initial implementation
%   #Author: Gavin Kearney (2022): initial implementation
%   #Author: Piotr Majdak (2023): documentation and structure adaptations

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

az= testDirections(:,1); 
el= testDirections(:,2);

xlin = linspace(min(az),max(az),180*2);
ylin = linspace(min(el),max(el),90*2);
[X,Y] = meshgrid(xlin,ylin);

Z = griddata(az,el,spectralDifference,X,Y,'cubic');

surf(X,Y,Z,'EdgeColor','none')
xlabel('Azimuth (deg)'); ylabel('Elevation (deg)');
set(gca, 'XDir', 'reverse', 'YTick', -75:75:75, 'XTick', -150:75:150);
xlim([-180 180]); ylim([-90 90]); view ([0 90]);
colormap(flipud(parula)); set(gcf, 'Color', 'w');
axis tight; box on; pbaspect([2 1 1]);
c2 = colorbar; c2.Label.String = 'PBC (sones)';
end


