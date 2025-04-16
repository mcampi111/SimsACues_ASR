function varargout=amt_load(model,fn,variable)
%amt_load Load auxiliary data from the auxdata repository
%   Usage: data = amt_load(model, fn);
%          data = amt_load(model, fn, variable); 
%          [audio, fs] = amt_load(model, fn);
%          sofa = amt_load(model, fn);
%          table = amt_load(model, fn);
%          filename = amt_load(model, fn);
%
%   Input parameters:
%     model    : Directory within the auxdata repository.
%     fn       : Filename of the auxiliary data. The filename fn*
%                must be provided with the extension. The extension determines
%                the type of the output:
%
%                - .wav: Output as that from audioread: audio 
%                  will be the audio signal with the size of (*time x channels*), and 
%                  fs will be the sampling frequency (in Hz).
%
%                - .mat: Output as that from load: data will contain
%                  the structure loaded from the file fn. This extension also
%                  supports the optional string variable to load specific 
%                  variables only (see load for more details).
%
%                - .sofa: Output as that from SOFAload: sofa will be
%                  the SOFA structure (see SOFAload for more details).
%
%                - .csv: Output as that from tableread: table will be
%                  a matrix as interpreted by tableread. The usage of 
%                  this extension is dangerous as the actual output
%                  may depend on the Matlab/Octave version. Storing 
%                  auxdata as a .mat file is thus highly recommended.
%
%                - others: Does not load the local auxdata, but if fn*
%                  not found in the local repository, it will be downloaded 
%                  from the remote auxdata repository. The output filename 
%                  will be the absolute filename 
%                  to the local file stored in the local auxdata repository.
%
%     variable : Optional string with the name of the variable(s) to be loaded
%                in the format of the command load. This applies only to 
%                auxdata stored as .mat files. 
%
%   Output parameters:
%     data  : Structure with the loaded variables. 
%     audio : Audio signal with the size of (*time x channels*). 
%     fs    : Sampling frequency (in Hz) of audio.
%     sofa  : SOFA structure as output by SOFAload.
%     table : Table with a matrix loaded from a CSV file and interpreted by tableread. 
%     filename:  Absolute filename to the local file stored in the local auxdata repository.
%
%
%   AMT_LOAD(model, fn) loads the auxiliary data from the file fn. The data will loaded
%   from the directory model located in the local directory given by
%   AMT_AUXDATAPATH, which per default is the directory auxdata located 
%   in the AMT base path. 
%
%   If the file fn is not found in the local repository given by AMT_AUXDATAPATH, 
%   it will be downloaded from the remote (online) repository given 
%   by AMT_AUXDATAURL, which is
%   per default http://amtoolbox.org/amt-version/auxdata with version being
%   the latest AMT version. 
%
%   Note that the remote auxdata repository is versioned:
%   The search starts with the latest AMT version, but if not found, it then 
%   continues in previous versions, going back up to AMT 1.0.0. 
%   
%   AMT_LOAD(model, data, variable) loads just particular variables given 
%   in the string variable. This applies to fn with the extension .mat only. 
%
%
%   See also: amt_auxdatapath amt_auxdataurl
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/core/amt_load.php


%   #Author: Piotr Majdak (2015): Original implementation.
%   #Author: Clara Hollomey (2021): Various improvements.
%   #Author: Clara Hollomey (2023): SOFA support.
%   #Author: Piotr Majdak (2023): SOFA support fix, SOFA loaded from auxdata, CSV fixed.
%   #Author: Piotr Majdak (2024): Weboptions fixed to 'raw', displaying improved, major documentation upgrade.

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

[~,kv]=amt_configuration;

localPath=kv.auxdataPath;
localfn=fullfile(localPath,model,fn);
[~,~,ext] = fileparts(localfn);

% file not found? create directories, and download!
if ~exist(localfn,'file')
    % create dir if not existing
  if ~exist(fullfile(localPath,model),'dir')
    [success,msg]=mkdir(fullfile(localPath,model));
    if success~=1
      error(msg);
    end
  end
    % download
  amt_disp(['Model: ' model ', auxiliary data: ' fn ' downloading from ' kv.version{1} '...'],'volatile');
  webfn = [kv.auxdataURL '/' model '/' fn];
  webfn(strfind(webfn,'\'))='/';
  webfn=regexprep(webfn,' ','%20');

  if isoctave
    [~, stat]=urlwrite(webfn, localfn);
  else
    w=weboptions('ContentType','raw','Timeout',10);
    try
      websave(localfn,webfn,w);
      stat = 1;
    catch
      stat = 0;
    end
  end

  if ~stat
    for ii = 2:numel(kv.version)
      webfn = [kv.downloadURL kv.version{ii} '/auxdata/' model '/' fn];
      webfn(strfind(webfn,'\'))='/';
      webfn=regexprep(webfn,' ','%20');
      amt_disp(['Model: ' model ', auxiliary data: ' fn ' downloading from ' kv.version{ii} '...'],'volatile');     
      if isoctave
        [~,stat]=urlwrite(webfn,localfn);
      else
        try
          websave(localfn,webfn,w);
          stat = 1;
        catch
          stat = 0;
        end
      end

      if stat
        amt_disp(); % delete the progress
        break; % download successful
      end

      if ii == numel(kv.version)
        amt_disp([]); % keep the progress and throw an error       
        error(['Unable to download ' fn ' for the model ' model ...
          '. Looked for it in the following versions: ' ...
          strjoin(kv.version,', ') '.']);
      end
    end
  end

end
  % check if .html file has been stored by some Matlab bug
if exist([localfn '.html'],'file'), delete([localfn '.html']); end
  % load the content
switch lower(ext)
  case '.wav'
    [y,fs]=audioread(localfn);
    varargout{1}=y;
    varargout{2}=fs;
  case '.mat'
    if exist('variable','var')
        varargout{1}=load(localfn,variable);
    else
        varargout{1}=load(localfn);
    end
  case '.sofa'
     evalc('output=SOFAload(localfn)');
     varargout{1} = output;
  case '.csv'
     varargout{1}=table2array(readtable(localfn));
  otherwise
    varargout{1}=localfn;
end


