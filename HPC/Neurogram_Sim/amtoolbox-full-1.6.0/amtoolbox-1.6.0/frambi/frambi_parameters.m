function varargout = frambi_parameters(operation, params, names, values, varargin)  
%frambi_parameters Handles FrAMBI parameter configurations
%   Usage: 
%     varargout = frambi_parameters(operation, params, names, varargin);
%     new_params = frambi_parameters('init', params, names, new_value, new_fit, new_trans, new_bounds);
%     new_params = frambi_parameters('set', params, names, values, fit, trans, bounds);
%     new_params = frambi_parameters('assign', params, names, new_values);
%     values = frambi_parameters('get', params, names);
%     new_values = frambi_parameters('transform', params, names, values);
%
%   Input parameters:
%     operation : String specifying the operation to be performed:
%
%                 - 'init': Initializes a parameter structure with defaults. 
%
%                 - 'set': Set and/or add properties of parameter(s). 
%
%                 - 'assign': Assign value(s) to existing parameter(s).
%
%                 - 'get': Return value(s) of existing parameter(s).
%
%                 - 'transform': Apply transformation to the values by using
%                   the transformation type given by the parameter name(s).
%
%                 - 'itransform': Apply inverse transformation to the values by using
%                   the transformation type given by the parameter name(s).
%
%                 - 'isimplausible': Test if values are within parameters' 
%                   plausible boundaries. 
%
%                 - 'isoutofbounds': Test if values are within parameters' 
%                   (strict) boundaries. 
%
%     params : Structure with existing parameters to be manipulated. params can 
%              be an empty structure, i.e., struct. It can also be the structure with 
%              the agent state parameters, i.e., agent.state.parameters obtained from 
%              the definition of the agent, e.g., BARUMERLI2024_ITDLATERAL. 
%
%     names :  Cell array of strings representing the names of the parameters to be manipulated.
%
%     varargin : Further parameters depend on the operation. 
%
%   Output parameters:
%     varargout : The returned output depends on the operation. 
%     
%
%   FRAMBI_PARAMETERS(..) handles parameter configurations within FrAMBI in various ways. 
%   The following operations are implemented:
%
%   *Initialize parameter(s):**
%
%   new_params = FRAMBI_PARAMETERS('init', params, names, new_value, new_fit, new_trans, new_bounds)
%   initializes parameters in params defined by names. If names are 
%   not member of params, they will be created. The parameters will be 
%   initialized the optional new_value, new_fit, new_trans, and new_bounds*:  
%   
%   - params*: The structure with parameters.
%
%   - names*: Optional cell array with the names of the parameters to be initialized.
%     If a parameter does not exist in params, it will be created. 
%     Default: All parameters in params will be initialized. 
%
%   - new_value*: Optional value for each the parameters to be initialized. Default: 
%     NaN, for each of the initialized parameters.
%
%   - new_fit*: Optional binary flag stating that the initialized parameters needs
%     fitting. Default: False, for each of the initialized parameters. 
%
%   - new_trans*: Optional string defining the type of transformation in the 
%     fitting procedure for each of the initialized parameters. The following
%     strings are supported:
%
%     - 'log': Logarithmic transformation will be performed.
%
%     - 'logit': Logistic transformation will be performed.
%
%     - 'none': No transformation will be performed.
% 
%     Default: 'none', for each of the initialized parameters. 
%
%   - new_bounds*: Optional row vector defining the bounds in the fitting procedure 
%     for each of the initialized parameters. The following columns must be specified:
%
%     - 1*: The lower bound. 
%
%     - 2*: The plausible lower bound. See the parametrization of the optimizer for the correct interpretation. 
%
%     - 3*: The plausible upper bound. 
%
%     - 4*: The upper bound. 
%
%     Default: [-Inf -Inf Inf Inf], for each of the initialized parameters.
%
%   - new_params*: Updated structure with initialized parameters.
%
%   Examples:
% 
%       % Create parameters "p1" and "p2", both with the value of 5.
%     params = frambi_parameters('init', struct, {'p1','p2'}, 5);
%       % Initialize "p2" only to the value of 10 and log transform. 
%     params = frambi_parameters('init', params, {'p2'}, 10, true, 'log',[1, 2, 120, 150]);
%
%   *Set properties and/or add parameter(s):**
%
%   new_params = FRAMBI_PARAMETERS('set', params, names, values, fit, trans, bounds)
%   set the properties values, fit, trans, bounds of parameters specifed by
%   names. If names are not member of params, they will be created: 
%   
%   - params*: Structure with parameters.
%
%   - names*: Cell array with the names of the parameters to be set and/or created. The
%     returned structure new_params will contain these fields.
%
%   - values*: Column vector with the new values of the parameters.
%
%   - fit*: Optional column vector with the new boolean flags stating that a parameter needs
%     fitting. Default: False, for all parameters named by names. 
%
%   - trans*: Optional cell array with strings defining the type of transformation in the 
%     fitting procedure. The following strings are supported:
%
%     - 'log': Logarithmic transformation will be performed.
%
%     - 'logit': Logistic transformation will be performed.
%
%     - 'none': No transformation will be performed.
%
%     Default: 'none', for all parameters named by names.
%
%   - new_bounds*: Optional matrix defining the bounds of each parameter 
%     in the fitting procedure. The following columns must be specified:
%
%     - 1*: The lower bound. 
%
%     - 2*: The plausible lower bound. See the parametrization of the optimizer for the correct interpretation. 
%
%     - 3*: The plausible upper bound. 
%
%     - 4*: The upper bound. 
%
%     Default: [-Inf -Inf Inf Inf], for all parameters named by names.
%
%   - new_params*: Structure with updated parameters.
%
%   Examples: 
% 
%       % Create a new structure with the parameter "level".
%     params = frambi_parameters('set', struct, {'level'}, 100)
%       % Update the value of "level" and create a new parameter "elevation".
%     params2 = frambi_parameters('set', params, {'level', 'elevation'}, [45, -90])
%       % Add an additional parameter "azimuth" as a variable to be fitted logarithmically.
%     params3 = frambi_parameters('set', params2, {'azimuth'}, 100, true, {'log'}, [0, 1, 100, 200])
%
%
%   *Assign value(s):**
%
%   new_params = FRAMBI_PARAMETERS('assign', params, names, new_values)
%   assignes new_values to parameters with the names names in params. 
%   The values will be checked for being withing the boundaries of the corresponding
%   parameter:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Cell array with the names of the parameters to be have the values assigned.
%
%   - new_values*: Column vector with values to be assigned to each parameter
%     defined by names. Each value in new_values must be within the 
%     boundary of the corresponding parameter.
%
%   - new_params*: Structure with updated parameters.
%
%   Examples: 
% 
%       % Create a new structure with parameters "level" and "elevation":
%     params = frambi_parameters('set', struct, {'level', 'elevation'}, [45, -90]);
%     vec = frambi_parameters('get', params)'
%
%       % Modify only the "azimuth" to be 25:
%     params = frambi_parameters('assign', params, {'elevation'}, 25);
%     vec = frambi_parameters('get', params)'
%
%       % Modify both "level" and "elevation" to be 50 and 70, respectively:
%     params = frambi_parameters('assign', params, {'level', 'elevation'}, [50 70]);
%     vec = frambi_parameters('get', params)'
%
%   *Get value(s):**
%
%   values = FRAMBI_PARAMETERS('get', params, names)
%   reads out the values of parameters in params*:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Optional cell array with the names of the parameters to be read out.
%     Default: All parameters from params will be read out. 
%
%   - values*: Vector with values of the requested parameters.
%
%   Examples:
% 
%       % Create a new structure with parameters "level" and "elevation". 
%     params = frambi_parameters('set', struct, {'level', 'elevation'}, [45, -90]); 
%       % Read out all values 
%     values = frambi_parameters('get', params)'
%       % Read out "elevation" only
%     ele = frambi_parameters('get', params, {'elevation'})
%
%   *Transform value(s):**
%
%   new_values = FRAMBI_PARAMETERS('transform', params, names, values)
%   transforms values to new_values according to the transformation
%   defined by the parameters with the names names in params*:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Cell array with the names of the parameters to be transformed.
%
%   - values*: Matrix with the values (in columns) to be transformed for 
%     each parameter (in rows). The number of rows must correspond with the
%     the number of parameters defined in names. 
%
%   - new_values*: Matrix with the size of values with the transformed values.
%
%   Examples: 
% 
%       % Create a new structure with linear parameters "elevation" and logarithmic "level". 
%     params = frambi_parameters('init', struct, {'elevation'}); 
%     params = frambi_parameters('set', params, {'level'}, 100, true, {'log'}, [0, 1, 100, 200]);
%       % Transform the elevation for values from 1 to 15. 
%     loglevels = frambi_parameters('transform', params, {'level'}, [1:5]) 
%       % Transform both parameters for a single value
%     all = frambi_parameters('transform', params, {'level', 'elevation'}, [5; 5]) 
%       % Transform both parameters for three values
%     mtx = frambi_parameters('transform', params, {'level', 'elevation'}, [1 2 3; 4 5 6])
%
%   *Inverse transform value(s):**
%
%   new_values = FRAMBI_PARAMETERS('itransform', params, names, values)
%   transforms values to new_values according to the inverse transformation
%   defined by the parameters with the names names in params*:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Cell array with the names of the parameters to be transformed.
%
%   - values*: Matrix with the values (in columns) to be inversly transformed for 
%     each parameter (in rows). The number of rows must correspond with the
%     the number of parameters defined in names. 
%
%   - new_values*: Matrix with the size of values with the inversly transformed values.
%
%   Examples:
% 
%       % Create a new structure with linear parameters "elevation" and logarithmic "level". 
%     params = frambi_parameters('init', struct, {'elevation'}); 
%     params = frambi_parameters('set', params, {'level'}, 100, true, {'log'}, [0, 1, 100, 200]);
%       % Transform the elevation for values from 1 to 15. 
%     loglevels = frambi_parameters('itransform', params, {'level'}, [1:5]) 
%       % Inverse that transformation 
%     linlevels = frambi_parameters('itransform', params, {'level'}, loglevels)
%
%   *Test if outside plausible boundaries:**
%
%   [num viol msg] = FRAMBI_PARAMETERS('isimplausible', params, names, values)
%   checks whether values are within the plausible boundaries as defined 
%   by the parameters with the names names in params. If values is not 
%   provided, the parameters' values stored in params are used:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Cell array with the names of the parameters to be tested.
%
%   - values*: Optional column vector with values to be tested for 
%     each parameter (in rows). The number of rows must correspond with the
%     the number of parameters defined in names. Default: values stored 
%     in params. 
%
%   - num*: Number of violations. If 0, all tested parameters are within
%     the plausible boundaries.
%
%   - viol*: Row vector with details of violations per parameter in each row:
%  
%     - -1: The value was below the plausible bound. 
% 
%     - 0: The value was within the plausible bounds. 
%
%     - 1: The value was above the plausible bound. 
%
%   - msg*: String with a human-readable text line for each violation.
%
%   Examples: 
% 
%       % Create a new structure with linear parameter "elevation" and logarithmic "level". 
%     params = frambi_parameters('init', struct, {'elevation'}, 30, true, {'none'}, [-90, -45, 45, 90]); 
%     params = frambi_parameters('set', params, {'level'}, 50, true, {'log'}, [0, 5, 100, 160]);
%       % Test whether the stored values are within the plausible boundaries
%     good = frambi_parameters('isimplausible', params, {'level','elevation'})
%       % Test whether the provided values are within the plausible boundaries. Returns violations.
%     [bad viol msg] = frambi_parameters('isimplausible', params, {'level','elevation'},[-20 120])
%
%   *Test if outside (strict) boundaries:**
%
%   [num viol msg] = FRAMBI_PARAMETERS('isoutofbounds', params, names, values)
%   checks whether values are outside the boundaries as defined 
%   by the parameters with the names names in params. If values is not 
%   provided, the parameters' values stored in params are used:
%   
%   - params*: Structure with parameters. It must contain fields defined in names.
%
%   - names*: Cell array with the names of the parameters to be tested.
%
%   - values*: Optional column vector with values to be tested for 
%     each parameter (in rows). The number of rows must correspond with the
%     the number of parameters defined in names. Default: values stored 
%     in params. 
%
%   - num*: Number of violations. If 0, all tested parameters are within
%     the strict boundaries. 
%
%   - viol*: Row vector with details of violations per parameter in each row:
%  
%     - -1: The value was below the lower bound. 
% 
%     - 0: The value was within the strict bounds. 
%
%     - 1: The value was above the upper bound. 
%
%   - msg*: String with a human-readable text line for each violation.
%
%   Examples: 
% 
%       % Create a new structure with linear parameter "elevation" and logarithmic "level". 
%     params = frambi_parameters('init', struct, {'elevation'}, 30, true, {'none'}, [-90, -45, 45, 90]); 
%     params = frambi_parameters('set', params, {'level'}, 50, true, {'log'}, [0, 5, 100, 160]);
%       % Test whether the stored values are within the boundaries
%     good = frambi_parameters('isoutofbounds', params, {'level','elevation'})
%       % Test whether the provided values are within the boundaries. Returns violations.
%     [bad viol msg] = frambi_parameters('isoutofbounds', params, {'level','elevation'},[170 -100])
%
%   See also: exp_barumerli2024
%
%   References:
%     R. Barumerli and P. Majdak. FrAMBI: A Software Framework for Auditory
%     Modeling Based on Bayesian Inference. under review at Neuroinformatics,
%     2024.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/frambi/frambi_parameters.php


%   #Author: Roberto Barumerli (2023): Original implementation.
%   #Author: Roberto Barumerli (2024): Integration in the AMT. 
%   #Author: Michael Mihocic (2024): Documentation fixed.
%   #Author: Piotr Majdak (2024): Adaptations for the AMT 1.6.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

  % validate input
if isempty(params), params = struct(); end
pnames = fieldnames(params);

  % perform operation
switch operation

    case 'init' % Initializes parameters
      if ~exist('names','var'), names = fieldnames(params); end
      params_num = length(names);
      if ~exist('values','var'), values=NaN; end
      if isempty(varargin)
          flag_fit = false;
      else
          flag_fit = varargin{1}; 
      end            
      if length(varargin) < 2
          transformation = 'none';
      else
          transformation = varargin{2};
      end
      if length(varargin) < 3
          bounds = [-Inf, -Inf, +Inf, +Inf];       
      else
          bounds = varargin{3};
      end        
      for ii = 1:params_num
          params.(names{ii}).value = values;
          params.(names{ii}).fit = flag_fit;
          params.(names{ii}).transformation = transformation;
          params.(names{ii}).bounds = bounds;
      end
      varargout{1} = params;

    case 'set' % Add new or set existing parameters
      params_num = length(names);
      if ~isempty(varargin)
          flag_fit = varargin{1}; 
      else
          flag_fit = false(params_num, 1);
      end
      if length(varargin) < 3
          bounds = repmat([-Inf -Inf Inf Inf], params_num);
      else
          bounds = varargin{3};
      end
      if length(varargin) < 2
          transformation = repmat({'none'}, params_num, 1);
      else
          transformation = varargin{2};
      end
      for ii = 1:params_num
          params.(names{ii}).value = values(ii);
          params.(names{ii}).fit = flag_fit(ii);
          params.(names{ii}).transformation = transformation{ii,:};
          params.(names{ii}).bounds = bounds(ii, :);
      end
      varargout{1} = params;
      
    case 'assign' % change value for one or more parameters
      for ii = 1:length(names) 
        if ~ismember(pnames, names{ii})
          error(['Parameter ' names{ii} ' not found.']); 
        end
        bounds = params.(names{ii}).bounds;
        assert(values(ii) >= bounds(1) && values(ii) <= bounds(end), ...
              ['Value ' num2str(values(ii)) ' of ' names{ii} ' is outside its boundaries.']);
        params.(names{ii}).value = values(ii);
      end
      varargout{1} = params;
      
    case 'get' % get a vector with values of parameters
      if ~exist('names','var'), names = fieldnames(params); end
      values = zeros(size(names));
      for ii = 1:length(names)
        values(ii) = params.(names{ii}).value;
      end
      varargout{1} = values;
    case 'transform' % transform values and return result
      transformed_values = zeros(size(values));
      for ii = 1:length(names) 
        if ~ismember(pnames, names{ii})
          error(['Parameter ' names{ii} ' not found.']); 
        end
        switch params.(names{ii}).transformation
          case 'log'
              transformed_values(ii,:) = log(values(ii,:));
          case 'logit'
              transformed_values(ii,:) = log(values(ii,:)./(1-values(ii,:)));
          otherwise
              transformed_values(ii,:) = values(ii,:);
        end
      end
      varargout{1} = transformed_values;
      
    case 'itransform' % given a set of values, apply inverse transformation and return result
      itransformed_values = zeros(size(values));
      for ii = 1:size(names) 
        if ~ismember(pnames, names{ii})
          error(['Parameter ' names{ii} ' not found.']); 
        end
        switch params.(names{ii}).transformation
          case 'log'
              itransformed_values(ii,:) = exp(values(ii,:));
          case 'logit'
              itransformed_values(ii,:) = 1./(1 + exp(-values(ii,:)));  
          otherwise
              itransformed_values(ii,:) = values(ii,:);
        end
      end
      varargout{1} = itransformed_values;
      
    case 'isimplausible' % check if the provided values are outside the plausible boundaries
      viol = zeros(length(names),1);
      msg = [];
      for ii = 1:length(names)
        if ~ismember(pnames, names{ii})
          error(['Parameter ' names{ii} ' not found.']); 
        end
        if ~exist('values','var')
          value = params.(names{ii}).value;
        else
          value = values(ii); 
        end
        if value < params.(names{ii}).bounds(2)
          msg = [msg sprintf('\n%s: Value of %g is below the plausible lower bound of %g.', ...
                              names{ii}, value, params.(names{ii}).bounds(2))];
          viol(ii)=-1;                  
        elseif value > params.(names{ii}).bounds(3)
          msg = [msg sprintf('\n%s: Value of %g is above the plausible upper bound of %g.', ...
                              names{ii}, value, params.(names{ii}).bounds(3))];
          viol(ii)=1;                  
        end
      end
      varargout{1} = sum(abs(viol));
      varargout{2} = viol;
      varargout{3} = msg(min(1,length(msg))+1:end); % cut the first \n if msg non-empty
        
    case 'isoutofbounds' % check if the provided values are outside the boundaries
      viol = zeros(length(names),1);
      msg = [];
      for ii = 1:length(names)
        if ~ismember(pnames, names{ii})
          error(['Parameter ' names{ii} ' not found.']); 
        end
        if ~exist('values','var')
          value = params.(names{ii}).value;
        else
          value = values(ii); 
        end
        if value < params.(names{ii}).bounds(2)
          msg = [msg sprintf('\n%s: Value of %g is below the lower bound of %g.', ...
                              names{ii}, value, params.(names{ii}).bounds(1))];
          viol(ii)=-1;                  
        elseif value > params.(names{ii}).bounds(3)
          msg = [msg sprintf('\n%s: Value of %g is above the upper bound of %g.', ...
                              names{ii}, value, params.(names{ii}).bounds(4))];
          viol(ii)=1;                  
        end
      end
      varargout{1} = sum(abs(viol));
      varargout{2} = viol;
      varargout{3} = msg(min(1,length(msg))+1:end); % cut the first \n if msg non-empty
        
%     case 'assign_condition'
%         index = varargin{1,1};
%         assert(index <= size(values, 1))
%         for ii = 1:numel(names)
%             if ~strcmp(names{ii}, 'response')
%                 assert(ismember(names{ii}, pnames), 'Error in using data_matrix: parameter %s does not exist in the environment parameters',names{ii} )
%                 params.(names{ii}) = values(index, ii);
%             end
%         end
%         varargout{1} = params;
        
%     case 'sample' % generate a plausible parameter value
%       values = zeros(size(pnames));
%       for ii = 1:length(pnames) 
%         if ~params.(pnames{ii}).fit
%             values(ii) = params.(pnames{ii}).value;
%         else
%             bounds = params.(pnames{ii}).bounds;
%             LB = bounds(1);
%             PLB = bounds(2);
%             PUB = bounds(3);
%             UB = bounds(4);
%             found = false; 
% 
%             while ~found
%                 values(ii) = (PUB-PLB)/2 + randn(1,1).*(PUB-PLB)./3;
%                 if values(ii) > LB && values(ii) < UB
%                     found = true;
%                 end
%             end
%         end
%         varargout{1} = values;
%       end

%     case 'print' % print all parameter 
%         names = fieldnames(params);
% 
%         for ii = 1:size(names) 
%                 amt_disp(sprintf('%s: %.3f\n', names{ii}, params.(names{ii}).value));
%         end
    otherwise
        error('Operation unknown'); 
end


