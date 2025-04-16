function amt_stop
%AMT_STOP Removes the AMT-related paths and clears persistent variables
%
%   AMT_STOP restores the paths to their state prior to runnnig amt_start and clears the
%   memory of all persistent variables within the amt core functions. This 
%   function facilitates working with different AMT versions.
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/core/amt_stop.php


%   #Author: Clara Hollomey (2022)
%   #Author: Piotr Majdak (2023): name of the persistent variable adapted

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

global AMTuserpaths

if exist('arg_amt_configuration', 'file')

    [flags, kv] = amt_configuration;
    if isempty(flags)
        disp('No configuration available. AMT may already have been uninstalled.')
        return;
    else
        amt_configuration('amtrunning', 0);
    end
    
    %clear persistent variables from all core functions
    functions = dir([kv.path, filesep, 'core', filesep, 'amt_*']);

    for ii = 1:numel(functions)
%       try
      munlock(functions(ii).name);
%       catch
%       end
      clear(char(functions(ii).name));
    end
    
    %restore the paths
    try
      path(AMTuserpaths);
      clear('global', 'AMTuserpaths');
    catch
    end
    disp('AMT unloaded. Good bye...');
    
else
    disp('AMT not loaded - nothing to reset.')
end


