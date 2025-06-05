function data = read_SEV_channel(dirname, header, channeltype, channel, s0, s1)
% READ_SEV_CHANNEL - read data from an SEV channel
%
% DATA = READ_SEV_CHANNEL(DIRNAME, HEADER, CHANNELTYPE, CHANNEL, S0, S1)
%
% Read data from a single channel CHANNEL from the SEV directory DIRNAME.
% 
% CHANNELTYPE must be 'time' (to read sample times) or 'analog_in' or 'ai' to read
% analog input data. 
%

if isempty(header)
	header = ndr.format.tdt.read_SEV_header(dirname);
end

header_chan = [header.chan];

indexes = find(header_chan==channel);

if isempty(indexes)
	error(['Channel ' int2str(channel) ' not found in ' dirname '.']);
end

header = header(indexes);

[header_hours,header_hours_index] = sort([header.hour]);

sample_boundaries = 1;
for i=1:numel(header_hours_index)
	sample_boundaries(end+1) = header(header_hours_index(i)).npts;
end

cumulative_boundaries = cumsum(sample_boundaries);

s0_ = max(1,s0); % make sure not out of range on low end
s0_ = min(s0_,cumulative_boundaries(end)-1); % make sure not out of range on high end

s1_ = min(cumulative_boundaries(end)-1,s1); % make sure not out of range on high end
s1_ = max(1,s1_); % make sure not out of range on low end

block_0 = find(histcounts(s0_,[cumulative_boundaries Inf]));
block_1 = find(histcounts(s1_,[cumulative_boundaries Inf]));

if any(strcmp(channeltype,{'time','t'}))
	data = ((s0_-1):(s1_-1))./header(header_hours_index(block_0)).fs;
	return;
elseif ~any(strcmp(channeltype,{'analog_in','ai'}))
	error(['Unknown channeltype ' channeltype '.']);
end


data = NaN(s1_-s0_+1,1);
counter = 0;

for block = block_0:block_1
	if block==block_0
		s0__ = (s0_ - cumulative_boundaries(block)) + 1;
	else
		s0__ = 1;
	end

	if block==block_1
		s1__ = s1_ - cumulative_boundaries(block) + 1;
	else
		s1__ = cumulative_boundaries(block)-1;
	end

	filename = [dirname filesep header(header_hours_index(block)).name];
	fid = fopen(filename,'r','ieee-le');
	if fid<0
		error(['Could not open file ' filename '.']);
	end
	fseek(fid, 40+(s0__-1)*header(header_hours_index(block)).itemSize, 'bof');
	d_here = fread(fid, s1__ - s0__ + 1, ['*' header(header_hours_index(block)).dForm]);
	fclose(fid);
	data((counter+1):counter+ (s1__-s0__+1)) = d_here(:);
	counter = counter + (s1__-s0__+1);
end

