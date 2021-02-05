function j = ndrresource(resourceName)
% NDRRESOURCE - read an NDR resource file
%
% J = ndr.fun.ndrresource(RESOURCENAME)
%
% Reads the JSON resource file RESOURCENAME from the NDR resource directory.
% Returns a Matlab structure that is output by JSONDECODE.
% 
% See also: ndr.fun.ndrpath, JSONDECODE
%

p = ndr.fun.ndrpath;

filename = [p filesep 'resource' filesep resourceName];

if ~exist(filename,'file')
	error(['File ' filename ' does not exist.']);
end;

s = '';

try,
	s = ndr.file.textfile2char(filename);
catch,
	error(['Error reading file ' filename '; ' lasterr]);
end;

j = [];
try,
	j = jsondecode(s);
catch,
	error(['Could not decode JSON file ' filename '; ' lasterr]);
end;

