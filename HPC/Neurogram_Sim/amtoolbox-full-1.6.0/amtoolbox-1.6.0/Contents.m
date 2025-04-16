%Online documentation
%
%
%   General
%   -------
%   
%   This is the most-complete and up-to-date description of the AMT. This documentation is directly included in the M-files and it is auto-generated for this website. Because of the automatic generation, the appearance on the website may suffer some details. Note that the current status of the models can be found in the section `Models <https://test.amtoolbox.org/models.php at this website.
%   
%   
%   New to the AMT? 
%   ---------------
%   
%   Download the AMT full package <https://test.amtoolbox.org/download.php, which provides all third-party toolboxes, and install the AMT with amt_start('install')`. This command also downloads the third-party toolboxes (if missing) and triggers compilation of the binaries. 
%
%   To stop the session, use amt_stop which removes the temporary search paths and resets the configuration. 
%
%   To again start to work with the AMT, use amt_start. 
%   
%   Important files in the AMT base path:
%     AMT_START            - Start the AMT and load the third-party toolboxes available on the system.
%     CHANGES              - Release history through out the AMT versions 
%   
%
%   Requirements to run the AMT 1.x
%   -------------------------------
%   
%   Matlab 2018b (or more recent) or Octave 8.2 (or more recent). Note that because of a bug in Octave 8.2.0 (or older) on Windows, Octave for Windows needs to be installed in a directory path without blanks. Further, there are some model-specific requirements:
%   
%   + Some models require third-party toolboxes. The AMT assumes that the user provides the paths to the toolboxes via the Matlab/Octave search paths. In addition to that, amt_start('install'); automatically downloads and installs all third-party toolboxes to the AMT's directory thirdparty. 
%
%   + Many models require compiled binaries. We provide pre-compiled binaries within the AMT full package, however, compilation on your system may still be required. To this end, the AMT needs to access the GNU Compiler Collection (GCC). The availability can be checked by executing system('gcc --version'); in Matlab or Octave. To compile the AMT binaries, execute amt_mex. This is also done automatically with amt_start('install').
%
%   + The models VERHULST2012, VERHULST2015, and VERHULST2018 require Python <https://www.python.org/ (version >= 2.6) with the packages numpy and scipy. The availability of Python (and its version) can be checked with system('python -V')`. This information is also displayed by AMT_START.
%
%   + Some models may require system-dependent toolboxes. On Matlab, many models require the Signal Processing and the Statistics Toolbox. On Octave, a few packages may be required. The information on available packages is displayed by amt_start. In order to see the requirements of a specific model, type amt_info('model'); with model being the model name to display the model-specific requirements. For more details, see AMT_INFO. 
%
%   For more detailed information on the requirements and steps for installation, see the section "Installation" of the `Download <download.php website. 
%   
%   License:
%   --------
%   
%   The AMT is a multiple*-licenses software: Most of the files are 
%   licensed under the GPL version 3.0, but some files are licensed differently.
%   Each file contains a separate license boilerplate showing the actual license.
%   For models being *not* under GPL3, the boilerplate is displayed on their first run. 
%   If no license message is displayed, the model is licensed under the GPL3. 
%   The information about the license of a model can be shown by AMT_INFO. 
%
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/Contents.php


%   #Author: Peter L. Soendergaard (2013). Original implementation. 
%   #Author: Piotr Majdak (2013). Continuous adaptations. 

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%     + On Linux, install the packages in the bash: ``sudo apt-get install python-scipy python-numpy``. 
%
%   

