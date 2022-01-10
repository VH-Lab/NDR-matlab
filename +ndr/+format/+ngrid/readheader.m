function h = vhsb_readheader(fo)
% ndr.format.ngrid.readheader - read an NGRID header
%
% H = ndr.format.ngrid.readheader(FILE_OBJ_OR_FNAME, ...)
%
% Reads the header portion of the vlt.file.fileobj or filename FILE_OBJ_OR_FNAME.
% At the conclusion of reading, the FILEOBJ or file is closed.
%
% This function returns a structure with the following fields (default in parentheses):
%
% -----------------------------------------------------------------------------------------
% version (1)                       | 32-bit integer describing version. Only 1 is allowed.
% machine_format ('little-endian')  | The machine format. The only value allowed is
%                                   |    'little_endian'.
% A_data_size (64)                  | 32-bit integer describing the size (in bytes) of each 
%                                   |    data point in the X series.
% A_data_type (4)                   | 8-bit unsigned integer describing whether X type is char (1), uint (2), int (3), or float (4)
% A_dim ([1 1])                     | 64-bit unsigned integer describing the rows, columns, etc of each Y datum
% A_usescale (0)                    | Character 0/1 should we scale what is read in Y using parameters below?
% A_scale (1)                       | 64-bit float scale factor
% A_offset (0)                      | 64-bit float offset factor common to all A info
%                                   | 
% headersize (1300)                 | The full header size in bytes
% filesize (variable)               | The size of the file in bytes

% skip 200 bytes for future

skip = 200; 

d = dir(vlt.file.filename_value(fo));

if isempty(d),
	error(['Could not find file ' vlt.file.filename_value(fo) '.']);
end;

fo = fopen(fo,'r','ieee-le');

headersize = 1300;

try,
	fseek(fo, skip,'bof');

	version = fread(fo, 1, 'uint32');

	machine_format = char(fread(fo, 256, 'char'));

	A_dim = fread(fo, 100, 'uint64')';
	A_dim = A_dim(A_dim>0);

	A_data_size = fread(fo, 1, 'uint32');
	A_data_type = fread(fo, 1, 'uint16');

	A_usescale = fread(fo, 1, 'uint8');

	A_scale  = fread(fo, 1, 'float64');
	A_offset = fread(fo, 1, 'float64');

	use_coords = fread(fo, 1, 'uint8');

catch,
	fclose(fo);
	error(['Error reading file ' vlt.file.filename_value(fo) ': ' ferror(fo) '.']);
end;

fclose(fo);

machine_format = vlt.string.line_n(machine_format(:)',1);

filesize = d.bytes;

h = vlt.data.workspace2struct;

h = rmfield(h,{'fo','d'});

