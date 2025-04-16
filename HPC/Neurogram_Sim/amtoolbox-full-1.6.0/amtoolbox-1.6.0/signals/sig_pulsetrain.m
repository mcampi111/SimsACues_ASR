function [stim, num_pulses] = sig_pulsetrain(dur, pulse_rate, pulse, fs, env)
%sig_pulsetrain Generate a (modulated) pulse train
%
%   Usage: stim = sig_pulsetrain(dur, pulse_rate, pulse);
%          stim = sig_pulsetrain(dur, pulse_rate, pulse, fs);
%          stim = sig_pulsetrain(dur, pulse_rate, pulse, fs, env);
%          [stim, num_pulses] = sig_pulsetrain(..);
% 
%   Input parameters:
%       dur:         Duration (in s) of stim to be generated.
%       pulse_rate:  Rate of the pulses (in pulses per second, pps).
%       pulse:       Vector representing the temporal signature of a single pulse.
%       fs:          Optional sampling frequency (in Hz) of pulse and stim.
%                    Default: 1 MHz.
%       env:         Optional envelope to be imposed on the pulse train. 
%                    Must have the length equal to round(dur*fs). Default: 
%                    No envelope applied.
% 
%   Output parameters:
%       stim:       Vector containing the pulse train with the sampling frequency fs.
%                   The length of stim will be round(dur*fs).
%       num_pulses: Number of pulses required to create the pulse train.
% 
%   SIG_PULSETRAIN(..) generates a pulse train containing superimposed 
%   copies of the pulse signature pulse, copied at the rate of pulse_rate. 
%
%   If the optional envelope in env is provided, the pulse train stim is scaled with the 
%   amplitudes from env at the starting point of the pulse. Otherwise no scaling is done.
%
%   See also: exp_felsheim2024 demo_felsheim2024
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/signals/sig_pulsetrain.php


%   #Author: Rebecca Felsheim (2024): Original implementation.
%   #Author: Piotr Majdak (2024): Adaptations for AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

    if nargin < 4
        fs = 1e6;
    end

    stim_len = round(fs*dur);     

    if nargin < 5
        env = ones(stim_len, 1);
    end
    
    stim = zeros(stim_len, 1);
    ind = 1;
    num_pulses = 0;
    step = round(1/pulse_rate * fs);

    if step < length(pulse)
        error("The pulse shape is too long for the given stimulation rate!")
    end

    while (ind < stim_len)
        stim(ind:ind + length(pulse) - 1) = pulse * env(ind);
        ind = ind + step;
        num_pulses = num_pulses + 1;
    end

end
