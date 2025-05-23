function [data] = read(filename,channeltype,header)
%READ Loads and reconstructs time-series data from the Dabrowska lab.
%
%   data = READ(filename, channeltype) loads data specified by
%   'channeltype' from the MAT file given by 'filename' and reconstructs 
%   continuous 'time', 'input', or 'output' vectors based on the step 
%   information in header. Time is calculated relative to the earliest 
%   trigger time across all steps.
%
%   [time, input, output] = READ(filename, Name, Value) allows specifying
%   optional parameters using Name-Value pairs.
%
%   Input Arguments:
%       filename    - A character vector or string scalar specifying the path
%                  to the MAT file.
%       channeltype - A character vector or string scalar specifying the type
%                     of data to return. Valid options are:
%                       'time' or 't': Returns the time vector in seconds,
%                                       relative to the first trigger time.
%                       'analog_in' or 'ai': Returns the reconstructed input
%                                            data ('inputData').
%                       'analog_out' or 'ao': Returns the reconstructed output
%                                             data ('outputData').
%       header      - A structure containing the pre-loaded header.
%
%   Output Arguments:
%       data        - A numeric column vector containing the requested data:
%                     - If channeltype is 'time'/'t', contains time points (s).
%                     - If channeltype is 'analog_in'/'ai', contains input data.
%                     - If channeltype is 'analog_out'/'ao', contains output data.
%                     Values corresponding to time points outside the defined
%                     steps in 'analog_in'/'analog_out' data will be NaN.
%
% See also: NDR.FORMAT.DABROWSKA.HEADER, NDR.TIME.FUN.TIMES2SAMPLES

% Input argument validation
arguments
    filename (1,:) char {mustBeFile}
    channeltype (1,:) char {mustBeMember(channeltype,{'time','t','analog_in','ai','analog_out','ao'})} % Validate channeltype
    header struct = struct();
end

% Check that the file is a .mat file
[~,~,ext] = fileparts(filename);
if ~strcmp(ext,'.mat')
    error('MATLAB:read:InvalidExtension', ...
        'Expected file "%s" to have a ".mat" extension.', filename);
end

% Check that the file contains the correct variable 'Pars'
varNames = who('-file', filename);
varReq = {'Pars','inputData','outputData'}; % Required variables
checkVars = ismember(varReq, varNames);
if ~all(checkVars)
    missingVars = strjoin(varReq(~checkVars),', ');
    error('MATLAB:read:MissingVariables', ...
        'File "%s" is missing the variable(s): %s', filename, missingVars);
end

% Get header (if not provided)
if isempty(fieldnames(header))
    header = ndr.format.dabrowska.header(filename);
end

% Check that header has required fields
if ~isfield(header, 'triggerTime') || ~isfield(header,'stepsNo') || ...
        ~isfield(header,'duration') || ~isfield(header,'sampleRate')
    error('MATLAB:read:InvalidProvidedHeader', ...
        'Provided Header structure is missing required fields.');
end

% Get data from file
load(filename,'inputData','outputData');

% Get global t0 and t1 time of each step and entire epoch
t0_global_steps = datetime(header.triggerTime,'convertFrom','datenum')';
t1_global_steps = t0_global_steps + milliseconds(header.duration);
t0_global = min(t0_global_steps);
t1_global = max(t1_global_steps);

% Get local t0 and t1 time of each step and entire epoch
t0_local_steps = seconds(t0_global_steps - t0_global);
t1_local_steps = seconds(t1_global_steps - t0_global);
t0_local = min(t0_local_steps);
t1_local = max(t1_local_steps);

% Get indices corresponding to step trigger times
stepInd = zeros(header.stepsNo, 2);
stepInd(:,1) = ndr.time.fun.times2samples(t0_local_steps,[t0_local t1_local],...
    header.sampleRate);
stepInd(:,2) = ndr.time.fun.times2samples(t1_local_steps,[t0_local t1_local],...
    header.sampleRate);

% Reconstruct data
numSamples = stepInd(end,2);
data = nan(numSamples,1);
switch lower(channeltype) % Use lower for case-insensitivity
    case {'time','t'}
        % Create a continuous time vector for the entire duration of the 
        % epoch (dev_local_time)
        data(:) = linspace(t0_local,t1_local,numSamples);
    case {'analog_in','ai'}
        for i = 1:header.stepsNo
            ind = stepInd(i,1):stepInd(i,2)-1;
            data(ind) = inputData(:,i)';
        end
    case {'analog_out','ao'}
        data = nan(numSamples,1);
        for i = 1:header.stepsNo
            ind = stepInd(i,1):stepInd(i,2)-1;
            data(ind) = outputData(:,i)';
        end
    otherwise
         error('MATLAB:read:InvalidChannelType', ...
             '"%s" is not a valid channel type', channeltype);
end

end