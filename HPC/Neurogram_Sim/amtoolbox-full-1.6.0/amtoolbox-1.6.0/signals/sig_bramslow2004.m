function [yy,fs] = sig_bramslow2004(type, time_total, time_step, gain_step_dB, f)
%function [yy,fs] = sig_bramslow2004(type, time_total, time_step, gain_step_dB, f)
%   This function generates signals for bramslow2004 AUDMOD model
%
%   Usage:
%       [yy,fs] = sig_bramslow2004(type, time_total, time_step, gain_step_dB, f)
%       output:
%           yy: output signal, column vector, starting RMS level is 0 dBFS
%           fs: sampling frequency, Hz
%       input:
%           type: 'sin', 'wn' (white noise), 'uen', 'uen2' (two variants of uniform exciting noise)
%           time_total: time, s
%           time_step: time per level step
%           gain_step_dB: level increase per level step (set to 0 for constant signal)
%           f: freuency, Hz (ignored for other types than 'sin'
%
%   #Author : Tayyib Arshad (2007): Original code
%   #Author : Lars Bramslow (2024): Integration into AMT
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_bramslow2004.php



switch type
    case 'sin'
        %   This function generates a sine wave. Can be adjusted to in- or decrease
        %   level for each frame. Developed for Audmod testbench.
        %   Level is +/- sqrt(2), e.g. 0 dBFS
        fs = 20000;                                         % Sample frequency
        t = 0:(1/fs):time_total-1/fs;                            % time vector
        In_FrmSize = ceil(time_step*fs);
        
        A = sqrt(2);                                    % Amplitude
        omega = 2*pi*f;                                 % Omega
        
        y = A*sin(omega*t);                             % Sine wave
        limit = ceil((length(y)/In_FrmSize));           % limit: number of frames in the generated sine wave
        a = 1;                                          % first element of first frame
        b = In_FrmSize;                                 % last element of first frame
        g = 0;                                          % Start gain
        
        for i = 1:1:limit
            
            if b > length(y)                            % Check if above size of sine wave
                b = length(y);
            end
            
            gain = 10.^(g/20);                          % Convert dB to gain
            yy (a:b)= y(a:b).*gain;                     % Aply gain
            a = a+In_FrmSize;                           % move frame
            b = b+In_FrmSize;                           % move frame
            g = g+gain_step_dB;                              % next gain in dB
            
        end
        
    case 'wn'
        
        fs = 44100;                                         % Sample frequency
        t = 0:(1/fs):time_total-1/fs;                            % time vector
        In_FrmSize = ceil(time_step*fs);
        
        y = randn(length(t),1);                         % generate directly
        limit = ceil((length(y)/In_FrmSize));           % limit: number of frames in the generated sine wave
        a = 1;                                          % first element of first frame
        b = In_FrmSize;                                 % last element of first frame
        g = 0;                                          % Start gain
        
        for i = 1:1:limit
            
            if b > length(y)                            % Check if above size of sine wave
                b = length(y);
            end
            
            gain = 10.^(g/20);                          % Convert dB to gain
            yy (a:b)= y(a:b).*gain;                     % Aply gain
            a = a+In_FrmSize;                           % move frame
            b = b+In_FrmSize;                           % move frame
            g = g+gain_step_dB;                              % next gain in dB
            
        end
        
    case 'uen'
        fs = 20000;                                     % Sample frequency
        t = 0:(1/fs):time_total-1/fs;                   % time vector
        In_FrmSize = ceil(time_step*fs);
        
        [y,fs] = amt_load('bramslow2004','steady_UEN.wav');               
        y = y/std(y);                                   % Norm to 0 dB FS
        limit = ceil((length(y)/In_FrmSize));           % limit: number of frames in the generated sine wave
        a = 1;                                          % first element of first frame
        b = In_FrmSize;                                 % last element of first frame
        g = 0;                                          % Start gain
        
        for i = 1:1:limit
            
            if b > length(y)                            % Check if above saze of sine wave
                b = length(y);
            end
            
            gain = 10.^(g/20);                          % Convert dB to gain
            yy (a:b)= y(a:b).*gain;                     % Aply gain
            a = a+In_FrmSize;                           % move frame
            b = b+In_FrmSize;                           % move frame
            g = g+gain_step_dB;                              % next gain in dB
            
        end
        
    case 'uen2'
        fs = 20000;
        In_FrmSize = ceil(time_step*fs);
        
        [y,fs] = amt_load('bramslow2004','steady_UEN2.wav');             
        y = y/std(y);                                           % Norm to 0 dB FS
        In_FrmSize = min(In_FrmSize, length(y));
        nrframes = ceil((time_total*fs/In_FrmSize));           % limit: number of frames in the generated sine wave
        a = 1;                                          % first element of first frame
        b = In_FrmSize;                                 % last element of first frame
        g = 0;                                          % Start gain
        
        for i = 1:1:nrframes
            
            gain = 10.^(g/20);                          % Convert dB to gain
            yy (a:b)= y(1:In_FrmSize).*gain;                     % Aply gain
            a = a+In_FrmSize;                           % move frame
            b = b+In_FrmSize;                           % move frame
            g = g+gain_step_dB;                              % next gain in dB
            
        end
        
    otherwise
        error('Unknown signal type');
end

% transpose (channels in columns)
yy = yy';
