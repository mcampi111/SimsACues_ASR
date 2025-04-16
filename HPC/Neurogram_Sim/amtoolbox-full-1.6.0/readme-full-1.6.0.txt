This package contains the AMT 1.6.0 with:

- Pre-compiled MEX files for Windows (64 bit) and Linux (Ubuntu 20.04)
- Following third-party toolboxes:
  - LTFAT 2.6.0-win64
  - SOFA Toolbox for Matlab/Octave 2.2.0
  - SFS Matlab 2.5.0
  - Circular Statistics Toolbox
  - Binaural SH Toolbox
  - BADS Toolbox 1.1.2
  
Tested on:
- Windows 10 (64 bit), Matlab 2018b, Curve fitting toolbox 3.5.8, Optimization toolbox 8.2, Signal processing toolbox 8.1, Statistics and ML toolbox 11.4
- Windows 10 (64 bit), Octave 9.1.0. 
- Linux Ubuntu 20.04(LTS), Matlab 9.6.0 (2019a), Optimization toolbox 8.3, Signal processing toolbox 8.2, Parallel Computing Toolbox 7.0, Statistics and ML Toolbox 11.5
- Linux Ubuntu 20.04(LTS), Octave 9.2.0.
- and selected newer versions...

Run the following to test various functionalites:
- Simple: demo_absolutethreshold
- Load of auxiliary data from server: demo_chen2011
- Load of cached results from server: exp_breebaart2001('a_fig6');
- C-compiled functions: demo_zilany2014
- SOFA and HRTF support: demo_baumgartner2014
- Python support: demo_verhulst2012

Known issues: 
- On Windows 10 (64 bit), Octave 9.1.0, not all models are available. See Issue https://sourceforge.net/p/amtoolbox/bugs/355/

For more information on the AMT, see <https://amtoolbox.org>. 

The AMT Team
Acoustics Research Institute
Austrian Academy of Sciences