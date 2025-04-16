function status = amt_mex(varargin)
%AMT_MEX   Compile Mex/Oct interfaces
%   Usage:  amt_mex;
%           amt_mex(flags);
%
%   AMT_MEX compiles AMT-related binaries on your system.
%
%   Requirements
%   ------------
%
%   1) Mex compiler working in your Matlab/Octave environment. Type help mex to check whether
%      and which compiler is available in your environment.
%
%   2) GCC installed on your OS.
%      On Windows, GCC can be installed from <https://gcc.gnu.org>.
%      On Linux, GCC is most probably available within your distribution.
%
%   Details
%   -------
%
%   The action of AMT_MEX is determined by one of the following flags:
%
%     'compile'  Compile stuff. This is the default.
%                In Matlab, all comp_.c and comp_.cpp files from theare
%                mex directory are compiled to system-dependent mex files.
%                In Octave, all comp_.cc files from the oct directory
%                are compiled to oct files. Then, the remaining files from
%                the mex directory are compiled to mex and moved to oct.
%                In both environments, other binaries are handled then.
%                On Windows, make.bat from the bin directory is executed.
%                On Linux, make is executed using the makefile file from the bin directory.
%
%     'clean'    Removes the compiled functions.
%                In Matlab, all system-dependent mex files from the mex
%                directory are removed.
%                In Octave, all oct, o, and mex files from the oct
%                directory are removed.
%                In both environments, other binaries are cleared by calling
%                clean and make clean on Windows and other systems, respectively,
%                in the bin directory.
%
%   See also: amt_start
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/core/amt_mex.php


%   #Author: Peter Soendergaard (2015)
%   #Author: Piotr Majdak (2024): refactorisation to catch errors and make the code more readable

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

[~, kv] = amt_configuration;
bp = [kv.path, '/'];

defnopos.flags.command={'compile','clean'};
[flags]=ltfatarghelper({},defnopos,varargin);


%% -------------- Handle cleaning --------------------------------
if flags.do_clean

  curdir=pwd; % Remember the current directory

  if isoctave
    amt_disp('* Cleaning the OCT directory: deleting *.oct, *.o, and *.mex files');
    deletefiles([bp,'oct'],'*.oct');
    deletefiles([bp,'oct'],'*.o');
    deletefiles([bp,'oct'],'*.mex');
  else
    oldstate = recycle('off'); % Delete files permanently (bypass trashcan on Windows/Mac but remember the old state
    amt_disp('* Cleaning the mex directory: deleting *.mex* files');
    deletefiles([bp,'mex'],['*.',mexext]);
  end

  cd([bp,'environments']);
  if ispc
    amt_disp('* Cleaning the environments directory: running "clean.bat"');
    [~, output]=system('clean');
  else
    amt_disp('* Cleaning the environments directory: running "make clean"');
    [~, output]=system('make clean');
  end
  amt_disp(output);

  if ~isoctave, recycle(oldstate); end
  cd(curdir); % Jump back to the original directory
end

%% -------------- compiling files in mex or oct --------------------------------

if flags.do_compile

  curdir=pwd; % Remember the current directory.
  
  if isoctave
      % We are in OCTAVE
    amt_disp('========= Compiling all comp_*.c|cpp files in the oct directory ==========');
    ext='oct';
    L=dir([bp,filesep,'oct',filesep,'comp_*.cc']);
    L=[L; dir([bp,filesep,'oct',filesep,'comp_*.cpp'])];
    filenames = arrayfun(@(lEl) lEl.name,L,'UniformOutput',0); % Get the list of files.
    status = local_compile_octave(bp,ext,filenames);
    if status>0, warning('Error: Not all files in the oct directory were compiled, some AMT functionality will NOT be available.'); end
      % Compile MEXs for all missing OCTs
    Lmex=dir([bp,filesep,'mex',filesep,'comp_*.c']);
    mexnamesstrip = arrayfun(@(lEl) lEl.name(1:end-2),Lmex,'UniformOutput',0);
    octnamesstrip = cellfun(@(lEl) lEl(1:end-3),filenames,'UniformOutput',0);
    mexdiffstrip = setdiff(mexnamesstrip,octnamesstrip);
    mexdiff = cellfun(@(lEl) [lEl,'.c'],mexdiffstrip,'UniformOutput',0);
    if ~isempty(mexdiff)
      amt_disp('========= Compiling missing interfaces in the mex directory ==========')
      status = local_compile_octave(bp,'mex',mexdiff) + status;
      if status > 0, warning('Error: Not all files in the mex directory were compiled, some AMT functionality will NOT be available. Scroll up and check the messages.'); end
      amt_disp('========= Moving compiled *.mex files to the oct directory ==========');
      status = ~movefile([bp,filesep,'mex',filesep,'*.mex'],[bp,filesep,'oct'],'f') + status; 
      if status > 0
        warning(['Error: Compilation sucessful, but mex files were not '...
                 'moved from the mex to the oct directory. Check your write permissions.']);
      end
    end
  else
      % We are in MATLAB
    amt_disp(['========= Compiling all comp_*.c|cpp files in the mex directory ==========']);
    ext='mex';
    L=dir([bp,filesep,'mex',filesep,'comp_*.c']);
    L=[L; dir([bp,filesep,'mex',filesep,'comp_*.cpp'])];
    filenames = arrayfun(@(lEl) lEl.name,L,'UniformOutput',0); % Get the list of files.
    status = local_compile_matlab(bp,ext,filenames);
    if status > 0, warning('Not all files in the mex directory were compiled, some AMT functionality will NOT be available. Scroll up and check the messages.'); end
  end

  % Compile the interfaces in directory ENVIRONMENTS
  amt_disp('========= Compiling environments interfaces: make ==========');
  cd([bp,'environments']);
  [status_make, output]=system('make');
  amt_disp(output);
  if status_make > 0, warning('Not all files in environments directory were compiled, some AMT functionality will NOT be available. Scroll up and check the messages.'); end
  status = status + status_make; 

  cd(curdir); % Jump back to the original directory.
end

function deletefiles(base,files)

  L=dir([base,filesep,files]);
  for ii=1:numel(L)
      s=[base,filesep,L(ii).name];
      delete(s);
  end

%% Compile when in MATLAB
function status=local_compile_matlab(bp,ext,filenames)

  status=0; % Assume no errors
  cd([bp,'mex']);
  warnStruct = warning; % save the warning structure for later restore
    
  for ii=1:numel(filenames)
      filename = filenames{ii};
      dotPos = strfind(filename,'.');
      objname  = [filename(1:dotPos(end)),ext];
      objdirinfo = dir(objname);

      % Make-like behaviour: build only the files where the src file is
      % newer than the object file, or the object file is missing.
      L = dir(filename);
      if isempty(objdirinfo) || (objdirinfo.datenum<L(1).datenum)
        amt_disp(['* Compiling ', filename]);
        try
          mex('-silent','-I.','-I../src',filename);
        catch ME
          warning(ME.message);
          status = status+1;
        end         
        warning('off'); % surpress warning after the first appearence
      end      
  end
  warning(warnStruct); % restore warnings


%% Compile when in OCTAVE
function status=local_compile_octave(bp,ext,filenames)

  status=0; % Assume no errors1

  if strcmpi(ext(1:3),'oct')
      cd([bp,'oct']);
  else
      cd([bp,'mex']);
  end

  warnStruct = warning;
    
  for ii=1:numel(filenames)
      filename = filenames{ii};
      dotPos = strfind(filename,'.');
      objname  = [filename(1:dotPos(end)),ext];
      objdirinfo = dir(objname);

      % Make-like behaviour: build only the files where the src file is
      % newer than the object file, or the object file is missing.
      L = dir(filename);
      if isempty(objdirinfo) || (objdirinfo.datenum<L(1).datenum)
        amt_disp(['* Compiling ', filename]);
        if ~strcmpi(ext(1:3),'oct')
          try
            mkoctfile('-mex','-I.','-I../src',filename);
          catch ME
            warning(ME.message);
            status = status+1;
          end         
        else
          try
            mkoctfile('-I.','-I../src',filename);
          catch ME
            warning(ME.message);
            status = status+1;
          end         
        end
        warning('off'); % surpress warning after the first appearence
      end
  end
  warning(warnStruct); % restore warnings











