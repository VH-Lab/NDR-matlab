function header = header(filename)
%HEADER Reads the header info from the Dabrowska lab.
%
%   header = HEADER(filename) loads the variable named 'Pars' from the
%   MAT file specified by 'filename'.
%
%   Input Arguments:
%       filename - A character vector or string scalar specifying the path
%                  to the MAT file. The file must exist.
%
%   Output Arguments:
%       header   - The content of the 'Pars' variable loaded from the file.

% Input argument validation
arguments
    filename (1,:) char {mustBeFile}
end

% Check that the file is a .mat file
[~,~,ext] = fileparts(filename);
if ~strcmp(ext,'.mat')
    error('MATLAB:header:InvalidExtension', 'Expected file "%s" to have a ".mat" extension.', filename);
end

% Check that the file contains the correct variable 'Pars'
varNames = who('-file', filename);
if ~ismember('Pars', varNames)
    error('MATLAB:header:MissingVariable', 'File "%s" is missing the required variable "Pars".', filename);
end

% Load the 'Pars' variable from the file
load(filename,'Pars');

% Assign the loaded 'Pars' variable to the output
header = Pars;

end