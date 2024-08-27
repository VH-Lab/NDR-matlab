function [data] = read(filename, header, channel_type, channel_numbers, t0, t1)
% READ - read from a BJG file
%
% [DATA] = READ(FILENAME, HEADER, CHANNEL_TYPE, CHANNEL_NUMBERS, T0, T1)
%
% Reads data from an BJG file, which are all float32 / single data channels
%
% Inputs:
%   FILENAME - the filename to read
%   HEADER - the header data for the file; if empty, it will be read
%   CHANNEL_TYPE - the channel type to read, can be 'time' or 'ai' (analog input)
%   CHANNEL_NUMBERS - an array of channel numbers to read (e.g., [1 2 3])
%   T0 - time to begin reading; can be -Inf to indicate the beginning of the record
%   T1 - time to end reading; can be Inf to indicate the end of the record
%

if isempty(header),
	header = ndr.format.bjg.read_bjg_header(filename);
end;

T0 = header.local_t0;
T1 = header.local_t1;

if (isinf(t0) & t0<0) | (t0<0),
	t0 = T0;
end;

if (t1>header.local_t1)
	t1 = T1;
end;

S = ndr.time.fun.times2samples([t0 t1],[T0 T1],header.sample_rate);

if strcmp(channel_type,'time') | strcmp(channel_type,'ti'),
	data = t0:1/header.sample_rate:t1;
else,
	data = ndr.format.binarymatrix.read(filename, header.num_channels, channel_numbers, S(1), S(2), ...
		'headerSkip',header.header_size,'byteOrder','ieee-le','dataType','single');
end;


