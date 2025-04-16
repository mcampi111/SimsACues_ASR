function [definput] = arg_felsheim2024(definput)
%ARG_FELSHEIM2024 Provied the default paramters of the aLIFP model felsheim2024, if no others are given
%
%   Usage: [parameters] = arg_felsheim2024()
%          [parameters] = arg_felsheim2024(parameters)
%
%   Input parameters:
%       parameters: (optional) struct, may contain values for any of the model parameters. For any
%                   field not contained in parameters, the default values are used. 
%
%   Output parameters:
%       parameters: struct, containing all parameters necessary to run the aLIFP model
%
% See also: felsheim2024 exp_felsheim2024 demo_felsheim2024
%
%   References:
%     R. C. Felsheim and M. Dietz. An adaptive leaky integrate and firing
%     probability model of an electrically stimulated auditory nerve fiber.
%     Trends in Heaaring, 2024. submitted.
%     
%
% #Author: Rebecca C. Felsheim (2024): original implementation
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/defaults/arg_felsheim2024.php



    % time constant of the fiber
    definput.keyvals.leaky_integrator_tau = 1.2e-04;
    % membrane resistance
    definput.keyvals.membrane_resistance = 28.986;
    
    %mean and standard deviation of the threshold of the fiber
    definput.keyvals.threshold_mu = 10e-3; % arbitrarily chosen
    definput.keyvals.threshold_sigma = 4.319e-4; 

    % numeric model parameters
    definput.keyvals.max_threshold_components = 20;
    definput.keyvals.path_deletion_mean_eps = 1e-3 * definput.keyvals.threshold_mu;
    definput.keyvals.path_deletion_std_eps = 1e-3 * definput.keyvals.threshold_sigma;
    definput.keyvals.min_spike_probability = 0.001;
    definput.keyvals.lower_limit_std_b = 1/3;

    % minimum duration of the action potential initialization process
    definput.keyvals.varphi = 2.05e-05; 
    
    % coefficients required in the computation of the jitter and latency of the
    definput.keyvals.jitter_coeffs=[5.449e-4, 3.159e-4, 1.30e-04];
    definput.keyvals.latency_coeffs = [1.096e-4, 5.478e-04, 3.93e-04, 4.23e-04];
    

    definput.keyvals.refractoriness_p = 0.377; 
    definput.keyvals.refractoriness_q = 0.102; 
    definput.keyvals.refractoriness_trrp = 2.56e-3; 
    definput.keyvals.refractoriness_tarp = 0.37e-3;


    definput.keyvals.adaptation_tau = 0.27; 
    definput.keyvals.adaptation_c = 0.015;
    definput.keyvals.max_adapt =  1.7; 

    % coefficients for the active component of facilitation
    definput.keyvals.facilitation_coeffs = [0.1e-3, -1.4e-3, 0.45 , 900, 0.5];

end




