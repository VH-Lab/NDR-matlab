function b = write(fo, A, coords, varargin)
% ndr.file.fun.ngrid.write - write an n-dimensional n-dimensional grid of data
%
% B = ndr.file.fun.ngrid.write(FO, A, COORDS,...)
%
% Write data from a matrix A to an ngrid binary file.
%
% Inputs:
%    FO is the file description to write to; it can be a 
%         filename or an object of type FILEOBJ
%    A is a MxNxOxPx...matrix to be written
%    COORDS can be empty or it can be a vector with the values of the 
%         1-dimension coordinates, followed by the values of the 2-dimension
%         coordinates, and so on.
%         
% Outputs: 
%    B is 1 if the file was written successfully, 0 otherwise
% 
% The function accepts parameters that modify the default functionality
% as name/value pairs.
%
% Parameter (default)                           | Description
% ------------------------------------------------------------------------------
% use_filelock (1)                              | Lock the file with CHECKOUT_LOCK_FILE
% use_coords (isempty(COORDS))                  | Will we store the coordinates of the grid?
% A_data_size (64)                              | The resolution (in bits) for A
% A_data_type ('float')                         | The data type to be written for A ('char','uint','int','float')
% A_usescale (0)                                | Scale the A data before writing to disk (and after reading)?
% A_scale (1)                                   | The A scale factor to use to write samples to disk
% A_offset (0)                                  | The A offset to use (Adisk = A/A_scale + A_offset)
%
% See also: NAMEVALUEPAIR 
%
% Example: 
%    A = randn(5,4,3);
%    b=ndr.format.ngrid.write('myfile.bin',A); 
%    if b==1, disp('succeeded.'); end;
%    C = ndr.format.ngrid.read('myfile.bin');
%    A==C
% 

use_filelock = 1;
A_data_size = 64;
A_data_type = 'float';
A_usescale = 0;
A_scale = 1;
A_offset = 0;
A_dim = size(A);

assign(varargin{:});

if nargin<3,
	use_coords = 0;
	coords = [];
else,
	use_coords = ~isempty(coords);
end;


if A_usescale,
	A = A/A_scale + A_offset;
end;

switch lower(A_data_type),
	case 'char',
		A_data_type = 1;
	case 'uint',
		A_data_type = 2;
	case 'int',
		A_data_type = 3;
	case 'float',
		A_data_type = 4;
	otherwise,
		error(['Unknown datatype ' A_data_type '.']);
end;

if use_coords,
	if numel(coords)~=sum(A_dim),
		error(['The number of datapoints in the COORDS input must equal the total number of coordinate points on '...
			' the axes. Example: If A is 2x3, COORDS should be [x1 x2 y1 y2 y3].']);
	end;
end;

parameters = vlt.data.workspace2struct;
parameters = rmfield(parameters,{'A','use_filelock','varargin','fo'});

if use_filelock,
	lock_fname = [filename_value(fo) '-lock'];
	fid = vlt.file.checkout_lock_file(lock_fname);
	if fid<0,
		error(['Could not get lock for file ' lock_fname '.']);
	end;
end;

h = ndr.format.ngrid.writeheader(fo,parameters);

 % ndr.format.ngrid.write_headerwill close the file

fo = fopen(fo,'r+','ieee-le');

b = 1;

fseek(fo,h.headersize,'bof');

 % if necessary, write coordinates

if use_coords,
	count = fwrite(fo, coords(:), 'float64'); 

	if count~=numel(coords), 
		b = 0;
	end;
end;

 % write A

if A_usescale,
	A = A/A_scale + A_offset;
end;

count = fwrite(fo,A(:), ndr.format.ngrid.sampletype2matlabfwritestring(A_data_type, A_data_size));

if count~=numel(A),
	b = 0;
end;

if use_filelock,
	fclose(fid);
	delete(lock_fname);
end;

