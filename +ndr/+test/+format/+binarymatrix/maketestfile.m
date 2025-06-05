function maketestfile()
% MAKETESTFILE - make a binary matrix test file
%
% maketestfile() 
%
% Creates a binary file with uint32 numbers from 1..100. The data are
% written using little-endian formatting ('ieee-le').
%
% The file is placed at ndr.test.format.binarymatrix.testfile.bin.
%

filepath = fileparts(mfilename('fullpath'));

filename = fullfile(filepath,'testfile.bin');

A = uint32(1:100);

fid = fopen(filename,'w','ieee-le');

if fid<0
	error(['Could not open ' filename '.']);
end

n = fwrite(fid,A,'uint32');

fclose(fid);

if n~=numel(A)
	error(['Could not write full information to file ' filename '.']);
end


