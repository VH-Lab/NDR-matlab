function str = known_readers()
% KNOWN_READERS - return known reader types for NDR-MATLAB
% 
% STR = KNOWN_READERS
%
% Return all known reader file types for NDR readers
%
% Example:
%  str = ndr.known_readers()
%


j = ndr.fun.ndrresource('ndr_reader_types.json');

str = cat(1,j.type);

