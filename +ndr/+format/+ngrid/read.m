function [A, coords] = read(fo, x0, x1, out_of_bounds_err)
% ndr.format.ngrid.read - read an ngrid file
%
% [A, COORDS] = ndr.format.read(FO)
%
% Read matrix A from ngrid file FO. FO can be
% a FILEOBJ or it can be the name of a file.
%
% Inputs:
%    FO is the file description to write to; it can be a 
%         filename or an object of type vlt.file.fileobj or ndr.file.fileobj
%         
% Outputs: 
%    A is the matrix that was read. At present, the whole matrix must be
%    read at once but this could be extended to read subsets of the matrix.
%
%    If coordinates were provided for the grid, then the coordinates are returned
%    in a cell array COORDS.
%
%    
% See also: ndr.format.ngrid.write

coords = [];

h = ndr.format.ngrid.readheader(fo);

 % ndr.format.ngrid.readheader will close the file

fo = fopen(fo,'r','ieee-le');

fseek(fo,h.headersize,'bof');  % go to the beginning of the data

if h.use_coords,
	% have to read the coordinates
	coords_data = fread(fo, sum(h.A_dim), 'float64');
	coords = {};
	dimsum = [0 cumsum(h.A_dim)];
	for i=1:numel(dimsum)-1,
		coords{i} = coords_data(dimsum(i)+1:dimsum(i+1));
	end;
end;

A = fread(fo, prod(h.A_dim), ndr.format.ngrid.sampletype2matlabfwritestring(h.A_data_type, h.A_data_size));

A = reshape(A,h.A_dim);

if h.A_usescale,
	A = double(A);
	A = (A - h.A_offset)*h.A_scale;
end;

fclose(fo);

