function h = writeheader(fo, varargin)
% ndr.formats.ngrid.writehreader - write an ngrid binary reader
%
% H = ndr.formats.ngrid.writeheader(FILE_OBJ_OR_FNAME, 'PARAM1, VALUE1, ...)
%
% Writes or re-writes the header portion of the FILE_OBJ or filename
% FILE_OBJ_OR_FNAME according to the parameters provided.
%
% The file or file object is closed at the conclusion of writing the header.
%
% This function takes name/value pairs that override the default functionality:
% Parameter (default)               | Description 
% -----------------------------------------------------------------------------------------
% version (1)                       | 32-bit integer describing version. Only 1 is allowed.
% machine_format ('little-endian')  | The machine format. The only value allowed is
%                                   |    'little_endian'.
% A_dim ([1 1])                     | 64-bit unsigned integer describing the rows, columns, etc of each A datum; can be up to 1x100
% A_data_size (64)                  | 32-bit integer describing the size (in bits) of each 
%                                   |    sample in the A matrix
% A_data_type (4)                   | 8-bit unsigned integer describing whether A type is char (1), uint (2), int (3), or float (4)
% A_usescale (0)                    | Character 0/1 should we scale what is read in A using parameters below?
% A_scale (1)                       | 64-bit float scale factor
% A_offset (0)                      | 64-bit float offset factor common to all A info
% use_coords (0)                    | 8-bit unsigned integer describing whether we will write coordinates for the pixels in the grid

% skip 200 bytes for future

skip = 200; 

version = 1;             % uint32 version number

machine_format = 'little-endian';  %

A_dim = [1 1];

A_data_size = 64;        % Y_data_size
A_data_type = [4];   % char, uint, int, float

A_usescale = 0;          % perform an input/output scale for Y? Output will be 64-bit float if so

A_scale = 1;             % 64-bit float scale factor
A_offset = 0;            % 64-bit float offset factor common to all Y info

headersize = 1300; % calculated as 1283 but give a few bytes of room

vlt.data.assign(varargin{:});

h = vlt.data.workspace2struct;
h = rmfield(h,{'fo','varargin'});
if isfield(h,'ans'),
	h = rmfield(h,'ans');
end;

 % open file for writing, set machine-type to little-endian

fo = fopen(fo,'w','ieee-le');

fseek(fo, 0, 'bof');

id = ['This is a ngrid file, http://github.com/VH-Lab/NDR-matlab' sprintf('\n')];

fwrite(fo, [id(:); repmat(sprintf('\0'),skip-numel(id),1)], 'char');

fseek(fo, skip, 'bof');

fwrite(fo, version, 'uint32');

fwrite(fo, [machine_format(:)' sprintf('\n') repmat(sprintf('\0'), 1, 256-(numel(machine_format)+1))], 'char');

A_dim = [A_dim(:) ; repmat(0, 100-numel(A_dim), 1) ];

fwrite(fo, A_dim(:), 'uint64');

fwrite(fo, A_data_size, 'uint32');
fwrite(fo, A_data_type, 'uint16');

fwrite(fo, A_usescale, 'uint8');
fwrite(fo, A_scale, 'float64');
fwrite(fo, A_offset, 'float64');

fwrite(fo,use_coords,'uint8');

where_we_are = ftell(fo);
left_to_go = 1300 - where_we_are;
fwrite(fo,repmat(sprintf('\0'),left_to_go,1),'char');

fclose(fo);
