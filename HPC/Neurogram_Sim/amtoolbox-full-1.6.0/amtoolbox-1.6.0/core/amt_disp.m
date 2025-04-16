function amt_disp(msg,flag)
%amt_disp Overload of the function 'disp'
%   Usage: amt_disp(X);
%     amt_disp(X,'volatile');
%     amt_disp(X,'documentation');
%     amt_disp();
%
%   AMT_DISP(X); can be used to show message X in the command
%   window. The output of AMT_DISP depends on the start-up
%   configuration of the AMT. X can be a character vector. X can also be
%   a string array, in which case the strings will be concatated without 
%   any delimiter. 
%  
%   When the AMT is started in the default mode (verbose), AMT_DISP 
%   will display behaving as the Matlab/Octave funtion disp(), however, 
%   the output will not appear in the web documentation. When the AMT is 
%   started in the silent mode, AMT_DISP will never display. 
%   See amt_start for further explanation on the start-up configurations. 
%
%   AMT_DISP(X,'volatile'); can be used as volatile progress indicator.
%   Any subsequent call of the AMT_DISP will delete the previous volatile
%   message. This way a changing progress can be clearly shown even in loops.
%   As the default messages, the volatile messages will not appear in the 
%   web documentation case. Before the first usage of volatile
%   call AMT_DISP(''); to indicate that volatile displays will follow.
%   After the last usage, call AMT_DISP(); to delete the last 
%   volatile message and continue in a normal mode, see the followig example:
%
%     amt_disp(''); % start of volatile display
%     for ii=1:20
%       amt_disp(['Trial #' int2str(ii) ' of 20...'],'volatile'); pause(0.1);
%     end
%     amt_disp(); % make the progress completely disappear
%
%   If the last volatile message should persist, use AMT_DISP([]);  
%   after the last volatile message. 
%
%   AMT_DISP(X,'documentation'); can be used for information interesting
%   to be displayed in the web documentation. 
%
%   AMT_DISP(X,'silent'); does not output at all. This is one of the 
%   available modes of the AMT. 
%  
%   AMT_DISP(X,'no_debug'); does neither output at all. 
%   AMT_DISP(X,'debug'); does output and combined with no_debug, it
%   can be used to implement a function in which the user defines the 
%   level of information to be displayed by passing a flag. For example,:
% 
%      definput.flags.disp = {'no_debug','debug'};
%      [flags,kv]=ltfatarghelper({},definput,varargin);
%      ...
%      amt_disp('Displayed only when flag debug provided',flags.disp);
%
%   Note that all functions in the AMT need to call AMT_DISP to print
%   to the command windows. Other functions like fprint or disp will 
%   be replaced by AMT_DISP during the integration process. 
%
%   See also: amt_start
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/core/amt_disp.php


%   #Author: Piotr Majdak (2016): original implementation
%   #Author: Piotr Majdak (2017): flag 'volatile' added
%   #Author: Piotr Majdak (2024): support for string arrays added

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


mlock;
persistent CachedMsg;
flags=amt_flags;

  % if no message provided: delete previous volatile, clear the buffer and terminate
if nargin==0
  if flags.do_verbose
    if ~isempty(CachedMsg)
        reversemsg = repmat(sprintf('\b'), 1, length(CachedMsg));
        fprintf(reversemsg);
    end
  end
  clear CachedMsg; 
  return; 
end
  % if empty string message provided: clear the volatile buffer and terminate
if isempty(msg) && ischar(msg)
  clear CachedMsg; 
  return; 
end
  % if empty vector provided: clear the volatile buffer, print EOL and terminate
if isempty(msg)
  if flags.do_verbose, fprintf('\n'); end 
  clear CachedMsg; 
  return; 
end
  % if string with blanks only provided: clear the volatile buffer, print EOL and terminate
if ischar(msg)
    if sum(msg==' ')==length(msg)
      if flags.do_verbose, fprintf('\n'); end 
      clear CachedMsg; 
      return; 
    end
elseif isstring(msg)
  msg=strjoin(msg,''); % convert a string array into a character vector
end

if exist('flag','var')
  if ~strcmp(flag,'documentation') && ~strcmp(flag,'volatile') && ~strcmp(flag,'progress') && ~strcmp(flag,'silent') && ~strcmp(flag,'debug') && ~strcmp(flag,'verbose') && ~strcmp(flag,'no_debug')
    error(['AMT_DISP: Unsupported flag ' flag]);
  end
else
  flag=''; % no flag --> we show the progress when being live only (no documentation mode)
end

%% AMT is in the default verbose mode --> print all messages
if flags.do_verbose
  switch flag
    case 'volatile'
      if ~isempty(CachedMsg)
        reversemsg = repmat(sprintf('\b'), 1, length(CachedMsg));
        fprintf(reversemsg);
      end
      fprintf(strrep(msg,'\','\\'));
      CachedMsg=msg;
    case {'silent', 'no_debug'}
      % do nothing
    case 'progress'
      warning('PROGRESS flag is deprecated. Use amt_disp without a flag for the same behavior');
      if ~isempty(CachedMsg)
        reversemsg = repmat(sprintf('\b'), 1, length(CachedMsg));
        fprintf(reversemsg);
        CachedMsg=[];
      end
      disp(msg);
    case {'', 'debug', 'verbose', 'documentation'}
      if ~isempty(CachedMsg)
        reversemsg = repmat(sprintf('\b'), 1, length(CachedMsg));
        fprintf(reversemsg);
        CachedMsg=[];
      end
      disp(msg);
%     case 'documentation'
%       disp(msg);
  end
end

%% AMT is in the documentation mode: Compile messages for the web documentation, print only messages flagged as 'documentation'
if flags.do_documentation
  switch flag
    case {'', 'volatile'}
          % do nothing
    case 'progress'
      warning('PROGRESS flag is deprecated. Use amt_disp() without flag for the same behavior');
          % do nothing
    case 'documentation'
      disp(msg); 
  end
end

%% AMT is in the silent mode: do nothing
if flags.do_silent
  % do nothing
end


