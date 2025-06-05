function p = ndrpath()
% ndr.fun.ndrpath - return the path to NDR, the Neuroscience Data Reader library in Matlab
%
% P = ndr.fun.ndrpath()
%
% Returns the full path to the ndr package in Matlab.
%
%

w = mfilename('fullpath');

if isempty(w)
	error(['Cannot determine path; cannot find function ndr.fun.ndr']);
end

try
	parent1 = fileparts(w);
	parent2 = fileparts(parent1);
	parent3 = fileparts(parent2);
catch
	error(['Cannot find third parent directory of ' w '.']);
end

p = parent3;


 
