function [data, total_samples, s0, s1] = read(filename_or_fileobj, num_channels, channel_indexes, s0, s1, options)

% READ - read a binary matrix file
%
% [DATA, TOTAL_SAMPLES, S0, S1] = READ(FILENAME_OR_FILEOBJ, NUM_CHANNELS, CHANNEL_INDEXES, S0, S1)
%
% Attempts to read binary data from a binary stream (can be a FILENAME or a FILEOBJ) from a
% binary matrix file. A binary matrix file is comprised of a vector of channels. Each sample
% consists of one value for each channel in the vector, followed by the next sample, etc.
%
% Inputs:
% ------
% NUM_CHANNELS - the number of channels that comprise the sample vector.
% CHANNEL_INDEXES - the index number of the channels to return. For example, 
%   CHANNEL_INDEXES = [ 1 2 3] indicates that the data should only be returned from the first,
%   second, and third channels in the matrix. Note that these channels may correspond to
%   different physical channels, depending upon how the data was recorded. CHANNEL_INDEXES refer
%   to indexes of the channels within the file.
% S0 - the sample number at which to start reading (number starting from 1). Can be -inf to indicate the start.
% S1 - the sample number at which to stop reading (number starting from 1). Can be inf to indicate the end.
%
% Outputs:
% -------
% DATA is an SxC matrix with samples in each row. For example, DATA(:,c) are all the samples requested
%   from channel CHANNEL_INDEXES(c).
% TOTAL_SAMPLES - the number of total vector samples in the file.
% S0 - the sample number (from 1) where the reading started.
% S1 - the sample number (from 1) where the reading stopped.
% 
% One may add optional arguments in the form of name/value pairs or inupt argument assignments.
% --------------------------------------------------------------------------------------------
% | Parameter (default)              | Description                                           |
% |--------------------------------- |-------------------------------------------------------|
% | dataType ('double')              | The data type of each value in the matrix.            |
% | byteOrder ('ieee-le')            | The byte order of the data (can be 'ieee-be' also)    |
% | force_single_channel_read (false)| Force the program to read channels 1 by 1 (may be     |
% |                                  |   slower but sometimes helpful for debugging)         |
% | headerSkip (0)                   | Number of header bytes to skip.                       |
% |----------------------------------|-------------------------------------------------------|
%

arguments
	filename_or_fileobj
	num_channels (1,1) uint32 {mustBeInteger, mustBePositive}
	channel_indexes uint32 {mustBeInteger, mustBePositive, mustBeVector}
	s0 double {mustBeNonempty} 
	s1 double {mustBeNonempty}
	options.dataType char {mustBeTextScalar, mustBeNonempty} = 'double'
	options.byteOrder char {mustBeTextScalar, mustBeNonempty} = 'ieee-le'
	options.force_single_channel_read (1,1) logical = false;
	options.headerSkip (1,1) uint64 = 0;
end % arguments

if max(channel_indexes)>num_channels
	error(['CHANNEL_INDEX out of range..must be 1..' int2str(num_channels)]);
end

if ~any(strcmp({'ieee-le','ieee-be'},options.byteOrder))
	error(['Byte order must be ieee-le or ieee-be. No other values accepted. Got: ' options.byteOrder]);
end

if isinf(s0) & (s0 < 0)
	s0 = 1;
end

if ischar(filename_or_fileobj)
	b = isfile(filename_or_fileobj);
	if ~b
		error(['No file found with name ' filename_or_fileobj '.']);
	end
	d = dir(filename_or_fileobj);
elseif isa(filename_or_fileobj,'fileobj')
	d = dir(filename_or_fileobj.fullpathfilename);
end


bytes_per_value = 0;

switch options.dataType
	case 'double'
		bytes_per_value = 8;
	case 'single'
		bytes_per_value = 4;
    case 'uint16'
        bytes_per_value = 2;
	otherwise
		[match_start,match_end] = regexp(options.dataType,'\d+','forceCellOutput');
		if numel(match_start)>1 | numel(match_start)==0
			error(['Expected dataType to have a single number; instead, found ' options.dataType]);
		end
		bits = str2num(options.dataType(match_start{1}:match_end{1}));
		bytes_per_value = bits / 8;
end

total_samples = (d.bytes-double(options.headerSkip)) / (num_channels * bytes_per_value);

if isinf(s1) & (s1>0)
	s1 = total_samples;
end

bytes_per_sample = bytes_per_value * num_channels;

channel_indexes = channel_indexes(:); % force column

[chan_sort,chan_sort_indexes] = sort(channel_indexes);

consecutive_channels_requested = numel(channel_indexes)==1|isequal(diff(double(chan_sort)),ones(numel(chan_sort)-1,1));

fid = fopen(filename_or_fileobj,'r',options.byteOrder);

if ~options.force_single_channel_read & consecutive_channels_requested
	channels_to_skip_before_reading = chan_sort(1) - 1;
	channels_to_skip_after_reading = num_channels - chan_sort(end);

	skip_point = double(options.headerSkip) + ...
		(s0-1)*bytes_per_sample + ... % skip to the sample ...
		channels_to_skip_before_reading*bytes_per_value; % skip any unrequested channels

	skip_after_each_read = channels_to_skip_after_reading*bytes_per_value + ... % skip remaining channels in this sample
		channels_to_skip_before_reading*bytes_per_value; % plus any to be skipped in the next sample

	fseek(fid,skip_point,'bof');
	data = fread(fid, numel(channel_indexes)*(s1-s0+1), [int2str(numel(channel_indexes)) '*' options.dataType],...
		skip_after_each_read);

	data = reshape(data, numel(channel_indexes), numel(data)/numel(channel_indexes))'; % 1 channel per column
	if ~isequal(chan_sort,channel_indexes)
		data(:,chan_sort_indexes) = data; % re-sort
	end
else
	data = zeros(s1-s0+1,numel(channel_indexes));
	for c=1:numel(channel_indexes)
		channels_to_skip_before_reading = channel_indexes(c) - 1;
		channels_to_skip_after_reading = num_channels - channel_indexes(c);

		skip_point = double(options.headerSkip) + ...
			(s0-1)*bytes_per_sample + ... % skip to the sample ...
			channels_to_skip_before_reading*bytes_per_value; % skip any unrequested channels

		skip_after_each_read = channels_to_skip_after_reading*bytes_per_value + ... % skip remaining channels in this sample
			channels_to_skip_before_reading*bytes_per_value; % plus any to be skipped in the next sample

		fseek(fid,skip_point,'bof');

		data(:,c) = fread(fid,s1-s0+1,options.dataType,skip_after_each_read);
	end
end

fclose(fid);

data = feval(options.dataType,data); % cast to correct output precision
