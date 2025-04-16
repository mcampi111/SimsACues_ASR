function definput = arg_bramslow2004(definput)
% default values for bramslow2004 model
% from the original file default_tb_opt_audmod.m
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_bramslow2004.php


definput.flags.disp = {'no_debug','debug'};
definput.flags.implementation =  {'MATLAB', 'PYTHON'};
definput.keyvals.NoChan     = 30;           % Number of channels (equally distributed on the ERB scale).
definput.keyvals.E_Beg      = 3;            % Lowest ERB rate considered (in Cams).
definput.keyvals.E_End      = 32;           % Highest ERB rate considered (in Cams).
definput.keyvals.Cal_dB     = 94;           % SPL of the time-domain input signal at full scale, i.e., $\pm 1$ or 0 dB FS.  
definput.keyvals.Cal_RMS    = false;        % audmod will calculate the RMS value if true
definput.keyvals.RMS        = 1;            % RMS value. - matches AMT standard
definput.flags.Coupler      = { 'freefield', 'IEC711_shaw1985', 'diffusefield_shaw1985', 'IEC711_mehrgardt1977', 'IEC303' }; % Recording coupler    
definput.flags.TransFact    = { 'ZWICKA0', 'ISO100N', 'ISO100M' }; % Transmission factor - static outer and middle ear correcction 
definput.keyvals.Binaural   = 0;            % 1 for binaural else 0 for monaural
definput.keyvals.In_FrmSize = 8192;         % input framesize (in samples)
definput.keyvals.Process    = 0;            % 0 = PSD averaging, 1 = frame-by-frame, n = avg n frames
definput.keyvals.AGLoss     = [0 0 0 0 0 0 0 0 0 0 0 0 0];% Hearing loss threshold db HL - default 0
definput.keyvals.AG_UCL     = [120 120 120 120 120 120 120 120 120 120 120 120 120];  % Uncomfortable level - dB HL

% default constants - not to be modified!
definput.keyvals.AG_f       = [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500];     % audiogram frequencies
definput.keyvals.RET4153    = [45.0  27.0 13.5 9.0 7.5 7.5 9.0 11.5 12.0 16.0 15.5 12.5 10.0];





