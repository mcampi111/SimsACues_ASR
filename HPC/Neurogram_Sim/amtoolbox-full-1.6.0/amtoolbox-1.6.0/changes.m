%Changes Release history of the AMT
%
%   Version 1.6.0
%   =============
%
%   General and core functions:
%    - *New**: FrAMBI, a framework for auditory modeling based on Bayesian inference, added. 
%    - Support for LTFAT 2.6.0 added (including the speed up).
%    - Issue #186: amt_disp: debug flag for display clarified.
%    - Issue #255: amt_disp behaviour for volatile messages clarified. See help of amt_disp. 
%    - Issue #286: amt_extern: in Octave 8.2 on Windows crashed. 
%    - Issue #287: amt_cache in Octave crashed when blanks in file name. 
%    - Issue #302: amt_start('silent') was not silent.
%    - Issue #313: Search engines did not access latest documentation version. 
%    - Issue #314: amt_start('install') failed if compiler not installed.
%    - amt_load: Fix for downloading text files (encoding set to 'raw') and displaying improved (Issue #334).
%    - amt_disp: support for string arrays added (which are output of sprintf). 
%    - arg_amt_configuration: Load of the version number improved to be robust regardless the type of EOL. 
%    - mat2doc improvements:
%
%      - Stripping of the Matlab output improved to preserve formating of table columns.
%      - The title of each function is now divided in two lines. Use ':raw-html:br />' to divide a line in RestructuredText.
%      - Key phrases such "Input parameters", "Usage" or "See also" require now a colon at the end. Otherwise these phrases cannot be used elsewhere in text.
%      - Issue #178: References were parsed with ':'.
%
%    
%   Common functions: 
%    - *New**: cart2horpolar: Convert Cartesian coordinates to the horizontal-polar coordinate system.
%    - Issue #192: itd2angle_lookuptable fixed for 'lindemann1986' model.
%    - Issue #311 and #327: fade improved, now AMT compliant and works with multiple channels.
%    - Issue #315 and #329: localizationerror: Major rework of the documentation, 'sirpMacpherson2000' renamed to 'sirp' (but still kept for compatibility).
%    - Issue #320: nalrp: provided correct help text and included to the documentation.
%    - Issue #321: standardaudiogram improved the documentation and included to the documentation.
%    - Issue #322: 
%
%      - fc2erb integrated in f2erbrate because it actually calculated the ERB rate according to glasberg1990. 
%      - f2erbrate can now calculate the ERB rate (in Cams) for both models (glasberg1990 and moore1983).
%      - f2erb calculates the ERB (in Hz) according to glasberg1990.
%      - erb2fc integrated in erbrate2f because it actually calculated the frequency based on the ERB rate according to glasberg1990. 
%      - erbrate2f can now calculate the frequency for both models (glasberg1990 and moore1983).
%
%
%   Models:
%    - *New**: bramslow2004: Loudness model (AUDMOD) with many model stages.
%    - *New**:eurich2024: Efficient monaural and binaural model for audio quality assessemnt (eMoBi-Q).
%    - *New**: felsheim2024: Adaptive leaky-integrate and firing probability (aLIFP) model of an electrically stimulated nerve fiber.
%    - *New**: paulick2024: Computational auditory signal processing and perception (CASP) model.
%    - *New**: lyon2024: Cascade of asymmetric resonators with fast-acting compression with two capacitors (CARFAC v2).
%    - Issue #208: moore1997: Output structure and documentation updated. Note that this implementation is not complete.
%    - Issue #244: ziegelwanger2013: SOFA structure expansion added.
%    - Issue #248 and #311: moore2016: Major ode review. Level definition fixed, a demo added, plot and the stage moore2016_cochlea removed, but this model still needs much work (see Issue #342). 
%    - Issue #255: 
% 
%      - verhulst2015: Default display set to no_debug, display of volatile messages fixed.
%      - verhulst2018: Default display set to no_debug, display of volatile messages fixed, naming of local function fixed.
%      - bruce2018: Default display set to no_debug, display of volatile messages fixed. 
%      - zilany2007: no_debug and debug flags added to be compatible with other models. 
%      - zilany2014: no_debug and debug flags added to display various amount of information. 
%    - Issue #312: reijniers2014: Bug fixed.
%    - baumgartner2017: Identifier added for the outdated warning, now it is disabled by exp_baumgartner2017. Function still obolete, not shown online. 
%    - king2019: default parameter dependency on those from auditoryfilterbank and ihcenvelope removed.
%
%   Experiments: 
%    - *New**: exp_bramslow2004: Reproduction of figures from Bramslow (2024) using the model from Bramslow (2004). 
%    - *New**: exp_eurich2024: Reproduction of Fig. 2a from Eurich et al. (2024). Uses eurich2024. 
%    - *New**: exp_felsheim2024: Reproduction of figures from Felsheim and Dietz (2024). 
%    - *New**: exp_paulick2024: Reproduction of Figures from Palick et al. (2024). Uses paulick2024. 
%    - *New**: exp_lyon2024: Reproduction of Figures from Lyon et al. (2024). Uses lyon2024. 
%    - Issue #255: Display of information improved in many exp_ functions. 
%    - Issue #334: exp_lavandier2022('fig5') did not run. 
%    - Issue #307: exp_osses2022: Small improvements.
%    - Issue #306: exp_osses2022: Bug fix in assigning variables. 
%    - Issue #127: exp_relanoiborra: Normalisation of x axis fixed.
%    - Issue #110: exp_rejniers: dependency from 'horizontal-polar' removed.
%    - exp_baumgartner2017: Tons of warnings removed. Function still obolete, not shown online. 
%
%   Data:
%    - *New**: data_heeringa2024: AN responses of gerbils, including the corresponding plot function. 
%    - *New**: data_mclachlan2023: Responses from a dynamic sound-localization experiment (basic). 
%    - *New**: data_mclachlan2024: Responses from a dynamic sound-localization experiment (many repetitions). 
%    - Issue #215: data_majdak2013: fixed and documentation rewrote. 
%    - Issue #244: data_ziegelwanger2013 when 'redo': bug fix. 
%    - Issue #293: data_langendijk2002 uses now cache data for P3 and P6.
%
%   Demos:
%    - *New**: demo_may2011 integrated in the online documentation. 
%    - *New**: demo_moore2016 implemented (very simple, not complete yet) and integrated in the online documentation. 
%    - *New**: demo_felsheim2024: Demo of the adaptive leaky-integrate and firing probability (aLIFP) model of an electrically stimulated nerve fiber.
%    - *New**: demo_paulick2024: Demo of the computational auditory signal processing and perception (CASP) model
%    - *New**: demo_lyon2024: Demo of the CARFAC v2 model. 
%    - Issue #255: demo_hohmann2002: Volatile display of information added.
%    - Issue #347: demo_mckenzie2022 returned error.
%    - Issue #348: demo_baumgartner2014_blockprocessing returned error.
%    - Issue #349: demo_barumerli2023 returns error: 'wrapTo360' not found (Octave).
%
%   Plot:
%    - *New**: plot_heeringa2024 Plots the waveform and peri-stimulus histograms, used by data_heeringa2024.
%    - *New**: plot_felsheim2024 Plots the results of felsheim2024.
%    - plot_moore2016: Removed because it just plotted two lines. 
%
%   Signals: 
%    - *New**: sig_tone generates a single-frequency tone, i.e., a sine with an arbitrary phase.
%    - *New**: sig_pulsetrain generates a pulse train (optionally modulated with an envelope).
%    - Issue #271: sig_vanderheijden1999 cleaned up, unnecessary functionality removed. 
%    - Issue #324 and #338: sig_kolarik2010 cleaned up, unnecessary functionality removed. Caution: the input parameter number changed!
%    - Issue #325 and #337: sig_marquardt2009 cleaned up, unnecessary functionality removed. 
%    - Issue #326: sig_sondhi_guttman1966 removed as not used and not compliant.
%
%
%   Version 1.5.0
%   =================
%   
%   General and core functions:
%    - amt_start: 
%
%      - (Issue #246): Check of the Deep Neural Network package stored in the AMT configuration. 
%      - (Issue #256): Start-up time improvement by factor three. A complete re-write was required with code parts separation by toolbox installation and toolbox starts. A special starter for the LTFAT (overloading ltfatstart.m) added, needing only a few 100 ms even on Octave. The starter is versioned, with the current support for LTFAT 2.4.0 (October 2018) and LTFAT 2.5.0 (May 2022). For other LTFAT versions, the LTFAT's default starter is used. 
%      - (Issue #250): Dependency of amt_subdir removed.
%      - Octave compatibility improved: io package is obligatory now, handling of packages simplified.
%      - Octave compatibility: nan package can be optionally loaded, nanmean and nanstd can be used in Octave now. 
%    
%    - arg_amt_configuration: 
%
%      - (Issue #246): Support for Deep Neural Network package configuration.
%      - (Issue #251): Textread replaced by fread because obsolete.
%    
%    - Website:
%
%      - (Issue #253): Better layout of Demos by visually linking a figure, it's caption, and it's legend.
%      - (Issue #234): All ° symbols replaced by deg to be parsed in figures correctly.
%      - Figures better layouted, now using a table which combines the code, figure, and code output.
%      - Distance between the options and their description increased.
%    
%    - amt_load: 
%
%      - Bug fix for loading files with a blank in the file name. 
%      - (Issue #272): Time out extended to 10 seconds and the ghosting .html files are removed after the download.
%     
%    - amt_extern: Support of empty outputs added.
%    - CHANGES (Issue #258): "Description" removed from the documentation.
%    - amt_subdir (Issue #250): Removed because of two licenses required and dependencies have been removed. 
%    - amt_info (Issue #264): Dependence of amt_subdir removed and expanded to work on other files than models only.
%    - amt_cache: Bug fix, disp replaced by amt_disp, doc improved.
%    - amt_mex: Error on cleaning removed (clean.bat added in /environments).
%    - mat2doc (Issue #273): Linking to ghosting figures removed. 
%
%   Models:
%    - verhulst2015: Adapted to use amt_extern.
%    - eurich2022: Doc fixes, arg_eurich adapted to be AMT compliant.
%    - auditoryfilterbank_singlefc.cc (Issue #259): Now compiles under Octave on Linux. 
%    - llado2022: llado2022_weightsanalysis removed because not a model stage, many fixes (code and docs).
%    - decheveigne2023 (Issue #262): New model implementation and new argument function arg_decheveigne2023.
%    - relanoiborra2019: 
%
%      - (Issue #277): Removed dependency on Image Processing Toolbox.
%      - (Issue #139): Automatic pre-panning added to remove the parameter N in the model, see N_prepanning in the default parameters. 
%
%   Experiments: 
%    - exp_engel2022 (Issue #245): Code updated to match the publication year. Changes include auxdata, cache, and the documentation.
%    - exp_engel2021 (Issue #249): Moved to legacy. 
%    - exp_eurich2022: Doc fixes. Code improvements. Status improved to verified.
%    - exp_llado2022: Check of Deep Neural Network Toolbox added, cached data if not available, auxdata in two versions now: with and without NNET Toolbox required.
%    - exp_laback2023:
%
%      - (Issue #263): Fig. 5 is plotted in four separate panels now. 
%      - (Issue #247): Last row of Fig. 5 seems to be completly wrong, other rows not quite correct. exp_laback2023 refactored for better debugging, but the issue moved to later version. 
%   
%   Demos and others: 
%    - demo_llado2022 (Issue #246): Checks of Deep Neural Network package improved; use cache if package not available; adapted for Octave compatibility. 
%    - plot_llado2022: Adapted for Octave compatibility.
%    - demo_mckenzie2021 (Issue #239): Documentation improved, auxdata adapted to match the publication year . 
%    - plot_tabuchi2013 (Issue #224): Integrated in exp_tabuchi2013 because it was used only once and only there. plot_tabuchi2013 stays available in legacy for a while. 
%
%    
%
%   Version 1.4.0
%   =============
%
%   Core functions:
%    - NEW: mat2doc.py directly integrated in the AMT (see /mat2doc/readme.txt)
%    - NEW: upload.py script in /mat2doc/php to automatically adapt the documentation PHP files
%    - amt_load: functions loading HRTFs use amt_load now. SOFAload and /hrtf are obsolete (Issue #231)
%    - amt_load: support for CSV files, which are read by tableread
%    - amt_extern: AMT can be run in a directory containing blanks now (Issue #233)
%    - amt_version: AMT version is stored at a single place only and used by mat2doc and amt_configuration (Issue #219)
%    - amt_configuration: display in silence mode fixed (Issue #226)
%
%   Models:
%    - NEW: eurich2022: Binaural detection model based on interaural coherence
%    - NEW: laback2023: Contextual lateralization based on interaural level differences
%    - NEW: smalt2014: Medial olivocochlear reflex in auditory nerve responses
%    - king2019: updated documentation
%   
%   Demos:
%    - NEW: demo_dau1997 (Issue #189)
%
%   Experiments:
%    - NEW: exp_decheveigne2023
%    - NEW: exp_laback2023
%    - NEW: exp_eurich2022
%    - exp_osses2022: use of amt_disp instead of sprintf (Issue #180)
%    - exp_osses2022: local functions called have prefix local (Issue #183)
%    - exp_barumerli2021: moved to legacy (Issue #232)
%    - exp_bauremrli2022: moved to legacy (Issue #232)
%    - exp_majdak2013: added, but no figure reproduced on the website yet (Curve Fitting Toolbox required). 
%
%   Model stages:
%    - NEW: ashida2016_LSOmodelCOC
%    - FIX: king2019 avoids NaN channels after scaling if there are empty channels
%    - NEW: various model stages previewing the functionality of decheveigne2023 model: decheveigne2023_spikeach, decheveigne2023_spikecch, decheveigne2023_spikeisih, decheveigne2023_spikejitter, decheveigne2023_spikepoisson, decheveigne2023_spikepsth, decheveigne2023_spikerefractory,  decheveigne2023_spiketopulse, decheveigne2023_spiketrain, decheveigne2023_spikevs
%
%   Signals:
%    - NEW: sig_laback2023: generates stimuli used in exp_laback2023
%    - NEW: sig_kolarik2010: Tone masked by a diotic inner-band and two antiphasic flanking-band noises
%    - NEW: sig_marquardt2009: Tone masked by a constant-ITD inner-band and two antiphasic flanking-band noises
%    - NEW: sig_vanderheijden1999: Tone masked by a constant-ITD inner-band noise
%    - king2019 avoids NaN channels after scaling if there are empty channels (Issue #235)
%
%   Data: 
%    - data_pausch2022: clean up (not completed yet)
%   
%   Version 1.3.0
%   =============================
%   General:
%    - license and copyright updated
%    - SOFA 2.1 support
%
%   Core functions:
%    - amt_start: do not require certificates when downloading toolboxes
%    - EXTENSION: amt_load: supports SOFA format
%
%   Models:
%    - NEW: bischof2023
%    - NEW: tabuchi2016
%    - lyon2011: ihc stage fixed
%    - UPDATE: barumerli2023
%
%   Modelstages:
%    - NEW: bischof2023_filterbank
%    - NEW: tabuchi2016_estimatethreshold
%    - UPDATE: mclachlan2021_preproc
%
%   Experiments:
%    - NEW: exp_bischof2023
%    - NEW: exp_tabuchi2016
%    - UPDATE: exp_barumerli2023
%    - NEW: exp_mchlachlan2021
%    - NEW: exp_majdak2013
%
%   Plot:
%    - NEW: plot_bischof2023
%
%   Signals:
%    - NEW: sig_bischof2023
%    - NEW: sig_tabuchi2016
%
%   Data:
%    - NEW: data_bischof2023
%    - UPDATE: data_majdak2013: additional data for plotting Figure 6 from Majdak et al. (2013)
%   
%   Other fixes: 
%    - baumgartner2014_pmv2ppp: output optimized when 'print' used
%    - exp_relanoiborra2019 : removed dependency from Matlab's Communication Systems toolbox
%    - demo_llado2022 : removed dependency from Matlab's Communication Systems toolbox
%
%   Version 1.2.0
%   =============================
%   Core functions:
%    - FIX: amt_start does not change current directory anymore
%    - FIX: amt_start('install') error caught when no compiler present
%    - FIX: amt_stop fully restores settings prior to amt_start
%    - FIX: amt_emuexp typos and char parsing
%
%   Common functions:
%     - itdestimator: more robust 'levelthr' method: set ITD to NaN if no threshold found.
%
%   Data:
%    - NEW: data_klingel2022
%    - NEW: data_pausch2022
%
%   Demos:
%    - FIX: demo_bruce2018_adaptiveredocking
%
%   Experiments:
%    - NEW: exp_klingel2022
%    - NEW: exp_pausch2022
%    - FIX: exp_baumgartner2021 Fig2, Fig3, Tab3
%    - exp_baumgartner2021 restructured (renaming of local functions)
%    - exp_breebaart2001 runs now more robustly under Linux
%    - FIX: exp_lavandier2022 Fig5
%
%   Models:
%     - NEW: barumerli2022: (renamed from deprecated barumerli2021) minor updates (new thirdparty function randvmf, removed dependency from Computer Vision Toolbox)
%     - mckenzie2022: (renamed from deprecated mckenzie2021) experiment and auxdata updated
%     - NEW: pausch2022
%     - relanoiborra2019: default minspl changed from -34 to -33.9794 dB (dbspl(2e-7,[],100)) to yield minlvl_lin=2e-7 in the adaptation loops (to better match publication)
%     - ziegelwanger2014: model option 5 added: estimate TOAs by using the maximum on LP-filtered IRs.
%
%   Documentation:
%     - major cleanup
%     - baumgartner2017 (and related files) removed because replaced by the actually published baumgartner2021
%
%   Version 1.1.0 (December 2021)
%   =============================
%
%   Core functionality:
%     - removed all appearances of global SPL offset modifications (ltfatsetdefaults).
%     - amt_configuration: added downloadpath to enhance search in previous versions functionality
%     - amt_start: added version-dependent removal of ssh certificate
%     - amt_load: restructured download display
%
%   Signal-processing functionality:
%     - FIX: adaptloop bug fix with signal scaling.
%     - NEW: minspl for adaptloop, which is minlvl in dB (minlvl still can be used for backwards compatibility).
%
%   Common functions:
%     - adaptloop: new parameter minspl, which is minlvl in dB. minlvl as linear amplitude can still be used.
%     - ihcenvelope: flag minlvl changed to be ihc_minlvl to be clearly associated with ihcenvelope. No backwards compatibility provided.
%     - ihcenvelope: flag ihctype renamed to ihc_type.
%     - NEW: f2erbrate: ERB rate for a frequency according to Moore and Glasberg (1983)
%     - NEW: erbrate2f: frequency from the ERB rate according to Moore and Glasberg (1983)
%     - NEW: bmld: binaural masking level difference according to Culling et al. (2005)
%
%   Data:
%     - NEW: data_brimijoin2013
%     - NEW: data_macpherson2003
%     - NEW: data_vliegen2004
%
%   Signals:
%     - NEW: sig_dizon2004
%     - NEW: sig_hofman1998
%     - NEW: sig_macpherson2003
%     - NEW: sig_schroeder1970
%
%   Plot:
%     - NEW: plot_llado2022
%   
%   Demos:
%     - NEW: demo_llado2022
%     - demo_adaptloop: minor improvements
%     - demo_mclachlan2021: minor changes
%     - demo_bruce2018: better parameters showing better the results
%
%   Experiments:
%     - NEW: exp_lavandier2022
%     - NEW: exp_llado2022
%     - exp_baumgartner2015binweight: Changes of the SPL offset removed (output looks like Fig. 5 from Baumgartner and Majdak, 2015)
%     - exp_osses2022: adapted to the revised manuscript version.
%     - exp_bruce2018: adapted to the changes in bruce2018.
%     - exp_li2020: adjusted sequence of Figures so they correspond to publication
%     - exp_baumgartner2021: minor adjustments
%
%   Models and Modelstages:
%     - NEW: lavandier2022
%     - NEW: leclere2015
%     - NEW: prudhomme2020
%     - NEW: vicente2020
%     - NEW: vicente2020_betterearsnrframe
%     - NEW: vicente2020_buadvantage
%     - NEW: vicente2020_internalnoise
%     - NEW: vicente2020nh
%     - NEW: llado2022
%     - carney2015: new flag 'ic_hwr' (and 'no_ic_hwr') to optionally disable the halve-way rectification of the outputs
%     - bruce2018: new flag 'specificSRautoTiming' to provide spontanous rates but calculate timing information for the auditory nerve fibers (used by exp_osses2022)
%     - zilany2014: improvements in displaying
%     - verhulst2018: 
%       - calculation of AN, CN, and IC can be disabled if unused
%       - detailed output provided only when requested (faster computation but causes backwards compatibility issues)
%       - major documentation improvement
%     - jelfs2011: 
%       - fixed erbspace and do_xcorr
%       - new option to calculate auditory filtering via auditoryfilterbank_singlefc
%     - mclachlan2021: 
%       - mclachlan2021_metrics: removed
%       - mclachlan2021_preproc: added
%
%   Version 1.0.0 (May 2021)
%   ==============================
%   Core functionality:
%     - core functions (amt.m) moved to the directory 'core'
%     - all auxdata, cache, and hrtf moved from sofaacoustics.org to amtoolbox.org
%     - NEW: automated toolbox download, new banner, new display style, availability check for matlab toolboxes and octave packages
%     - NEW: amt_stop: removes paths associated to current AMT session and deletes persistent variables in the AMT core functions
%     - NEW: amt_subdir: performs recursive search in subdirectories
%     - NEW: amt_extern: interface to external environments such as Python
%     - NEW: amt_configuration: provides configuration of the current AMT session, sets amt_cache, amt_auxdatapath, amt_auxdataurl, and amt_flags
%     - NEW: amt_info: information on the authorship, license, and technical requirements of a model
%     - emuexp renamed to amt_emuexp
%     - NEW: incremental version search in amt_cache and amt_load: search in older AMT versions for files if not found in current AMT version
%     - amt_disp: debug flag included, progress flag removed.
%     - amt version: module display removed
%     - lock of persistent variables added to the core functions
%
%   Signal-processing functionality:
%     - signal level convention switched to SI with 20 mu Pa as reference for SPL calculation, i.e., RMS of corresponds to the SPL of 94 dB
%     - first dimension is time when calling a model
%
%   Common functions (was 'general' previously):
%     - siiweightings renamed to f2siiweightings
%     - setdbspl renamed to scaletodbspl
%     - bmdistance and greenwood integrated in f2bmdistance
%     - NEW: erb2fc
%     - NEW: f2erb
%     - NEW: fc2erb
%     - NEW: phon2sone
%     - NEW: sone2phon
%     - NEW: gammachirp
%     - NEW: erbest
%     - NEW: fade
%     - NEW: infamplitudeclip
%     - NEW: interpolation
%
%   Data:
%     - NEW: data_lyon2011
%     - NEW: data_li2020
%
%   Plot:
%     - NEW: plot_bruce2018
%     - NEW: plot_mckenzie2021
%     - NEW: plot_moore2016
%
%   Demos:
%     - NEW: demo_lyon2011
%     - NEW: demo_lyon2011_compressivefunction
%     - NEW: demo_lyon2011_impulseresponses
%     - NEW: demo_bruce2018
%     - NEW: demo_bruce2018_auditorynerveresponse
%     - NEW: demo_carney2015
%     - NEW: demo_ewert2000
%     - NEW: demo_king2019
%     - NEW: demo_verhulst2015
%     - NEW: demo_verhulst2018
%     - NEW: demo_hauth2020
%     - NEW: demo_chen2011
%     - NEW: demo_mckenzie2021
%     - NEW: demo_baumgartner2021
%     - NEW: demo_mclachlan2021
%
%   Experiments:
%     - bug fix: exp_gammatone
%     - NEW: exp_engel2021
%     - NEW: exp_bruce2018
%     - NEW: exp_osses2022
%     - NEW: exp_relanoiborra2019
%     - NEW: exp_verhulst2018
%     - NEW: exp_chen2011
%     - NEW: exp_mckenzie2021
%     - NEW: exp_osses2021
%     - NEW: exp_barumerli2021
%     - NEW: exp_baumgartner2021
%     - NEW: exp_li2020
%
%   Models and Modelstages:
%     - NEW: lyon2011
%     - NEW: verhulst2015
%     - NEW: verhulst2018
%     - NEW: bruce2018
%     - NEW: carney2015
%     - NEW: king2019
%     - NEW: relanoiborra2019
%     - NEW: hauth2020
%     - NEW: osses2021
%     - NEW: mckenzie2021
%     - NEW: chen2011
%     - NEW: moore2016
%     - NEW: baumgartner2021
%     - NEW: li2020
%     - NEW: barumerli2021
%
%
%   Version 0.10.0 (May 2020)
%   ==============================
%   
%   - baumgartner2020: sound-externalization model provided
%   - reijnier2014: ideal-observer spherical sound-localization model based on Bayesian statistics provided
%   - exp_reijniers2014: figures from conference proceedings Barumerli et al. (2020, AES and FA) evaluating reijniers2014 added.
%
%   Version 0.9.9 (September 2017)
%   ==============================
% 
%   - data_baumgartner2017 provided
%   - data_baumgartner2017looming provided)
%   - kelavas2015 improved (appears in the code and documentation now)
%   - bug #78 fixed: hohmann2002_process did not work for multiband input signals.
%
%   Version 0.9.8 (12.7.2017)
%   =========================
% 
%   Compatibility breaks:
%     - amt -> amt_*
%         - Use amt_start to start the AMT
%         - Legacy files provided but will be removed in the future. 
%         - amthelp --> amt_version
%     - gfb -> hohmann2002. Legacy files provided. See note #11 for more details.
%     - zilany2007humanized --> zilany2007. Legacy file provided.
%     - drnl -> lopezpoveda2001. Legacy file provided.
%     - modfilterbankepsm --> ewert2000. No legacy file. 
%     - HRTFs: only SOFA files allowed now.
%     - Functions creating/modifying signals have the prefix sig now:
%         - Legacy files provided but will be removed in the future.
%        	- irns --> sig_yost1996
%        	- whitenoiseburst --> sig_whitenoiseburst
%        	- transposedtone --> sig_transposedtone
%       	- perfectsweep --> sig_linsweep
%        	- notchednoise --> sig_notchednoise
%        	- bmsin --> sig_lindemann1986
%        	- simulatedimpulseresponse --> sig_joergensen2011
%       	- itdsin --> sig_itdsin
%       	- ildsin --> sig_ildsin
%       	- itdildsin --> sig_itdildsin
%       	- competingtalkers -> sig_competingtalkers
%       	- breebaart2001siggen --> sig_breebaart2001
%       	- bincorrnoise --> sig_bincorrnoise
%       	- bandpassnoisefreq --> sig_bandpassnoise
%     - Model stages in modelstages have the format modelXX_stageYY now:
%         - modelXXstageYY --> modelXX_stageYY
%         - ffGn --> zilany2014_ffGn
%         - breebaart2001preproc --> breebaart2001_preproc
%         - No legacy files provided. Adapt your code if directly calling model stages from your code. 
% 
%   New
%     - baumgartner2017: sound externalization model
%     - baumgartner2016: level-dependent sagittal-plane sound localization model for NH and HI listeners
%     - hohmann2002: the gfb framework of Gammatone filterbank integrated as hohmann2002 framework
%     - kelvasa2015: sound localization in cochlear-implant listeners
%     - emuexp: emulation of experiments using interative runs like 3-AFC
%     - breebaart2001_centralproc: decision stage from Breebaart et al. (2001). 
%     - exp_breebaart2001: reproduces results from Breebaart et al. (2001) based on emuexp
%     - model initiative: interface to the model initiative (Dietz et al. 2016)
% 
% 
%   Structural changes:
%     - baumgartner2014 decomposed into model stages
%     - exp_spille2013 merged into exp_dietz2011
%     - directories re-structured:
%         - main scripts of a model go to: model. They are called nameyear
%         - scripts with model stages (model scripts other than the main one) go to: modelstages. They are called nameyear_postfix
%         - scripts not being part of a specific model go to: general. They do not (!) start with model name.
%         - scripts generating audio signals go to: signals. They are called sig_nameyear or sig_functionality
%         - scripts returning measured data go to: data. They are called data_nameyear
%         - scripts with default parameters of other scripts go to: defaults. They are called arg_callingfunction
%         - files being compiled to mex files go to: mex. In order to be compiled, they must have the prefix comp
%         - files being compiled to oct files go to: oct
%         - other files requiring compilation/installation go to: bin. Their compilation must be considered in make.bat (Windows) and Makefile (Linux/MacOS).
%         - HRTFs go to hrtfs. They are in SOFA and will be downloaded on the fly. 
%         - Lagecy files providing backwards compatibility fo to: legacy
%         - binaural, monaural, speech, filters removed
% 
%   Other updates:
%     - dietz2011: minor bug fixes
%     - data_joergensen2011: completion of data
%     - exp_baumgartner2014: new figures, compatibility improved
%     - demo_hohmann2002: new figures
%     - installation simplified (amt_mex does all the installation now)
% 
%   Version 0.9.7 (10.6.2015)
%   =========================
% 
%   New:
%     - Caching of data: see amt_cache and the cache directory.
%     - Automatic download of auxiliary data. See amt_load and the auxdata directory.
%     - Control for messages output in the command line. See amt_disp.
%     - SOFA files for HRTFs: requires SOFA API, see SOFAload.
%     - Models: zilany2014, joergensen2011, joergensen2013, georganti2013
%     - Signals: sig_joergensen2011
%     - Clean documentation (no errors, no warnings).
%     - makefile for Linux, compiling of cpp files
% 
%   Structure changes:
%     - arg functions moved to arg directory, comp functions moved to mex, directory comp removed
%     - plot functions renamed to plot and moved to plot directory
%     - amt_start and amt_mex improved
%     - readme file for sourceforge added
%     - reference directory removed (it was a directory with original contributions to the AMT)
% 
%   Other changes:
%     - interpolation for various polar-angle samplings  
%     - added new experiment in exp_baumgartner2014: fig5_baumgartner2015aro
%     - stability improvements in baumgartner2014
%     - minor bugfix in demo_baumgartner2013 and doc update in baumgartner2014
%     - exp_lindemann1986: fig 14b disabled: it takes ages and is wrong anyway...
%     - added reference for verhulst2012
%     - wierstorf2013: additional files for HRTF handling removed, load the itd-to-angle look-up table with data_wierstorf2013.m now. 
%     - hrtf/enzner2008 removed (enzner2008 data are in auxdata now)
%     - langendijk2002: data and HRTFs removed from repository (are required data)
%     - changed the order of announcements on amt_start
%     - jelfs2011: removed dependency on read_hrir
%     - plotjelfs2011 moved to demo_jelfs2011.m (plotjelfs2011 was actually a demo).
%     - progress output supressed in the documentation
%     - amt_disp introduced for displaying information depending on the start-up condition of the AMT.
%     - enzner2008 and exp_enzner2008 split in the model and experiment part.
%     - exp_georganti2013 works for me. Documentation is missing yet.
%     - may2011 documentation integrated
%     - 2014 version of may2011 added. demo_may2011 works but documentation invalid yet.
%     - extractsp: stability improvement
%     - minor documentation and stability updates, new function baumgartner2014parametrization and functionalities in localizationerror added.
%     - Fixed imag ILD in dietz2011
%     - Added function to load some simulated monaural room impulses responses.
%     - documentation updates and use of SOFA's remote load functionality in data_baumgartner2014.
%     - major style overhaul of the Joergsen 2011 and 2013 models. Experiments included etc. Does not yet pass mat2doc, and sound files are missing.
%     - localizationerror: new performance measures added
%     - data_majdak2010 and ...2013ctc: Angles forced to be real valued.
% 
% 
%   Version 0.9.6
%   =============
% 
%   New: 
%     - Gammatone validation provided, including exp_gammatone, demo_gammatone, exp_hohmann2002, and demo_hohmann2002
%     - Wierstorf et al. (2013) provided, including wierstorf2013, exp_wierstorf2013, and integration with the SFS toolbox
% 
%   Fixes:
%     - data_goode1994: more details provided
%     - jelfs2011 works now with SOFA HRTFs stored in hrtf/jelfs2011/, e.g., kemar.sofa
%     - hohmann2007 naming resolved. hohmann2007 renamed to herzke2007, the primary model is called hohmann2002 now
%     - localizationerror: missing error types added
%     - exp_spille2013: uses lowpass f_inst
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/changes.php



