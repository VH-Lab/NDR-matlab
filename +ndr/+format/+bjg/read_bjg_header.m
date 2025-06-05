function h = read_bjg_header(filename)
% READ_BJG_READER - read header infromation from a BJG .bin file
%
% H = READ_BJG_HEADER(FILENAME)
%
% Reads header information from the BJG file FILENAME.
% 

header_length = 4096;

fid = fopen(filename,'r','ieee-le');

if fid<0
	error(['Could not read header of ' filename '.']);
end

hdr = fread(fid,header_length);

hdrc = char(hdr(:)');

newl = find(hdrc==sprintf('\n')); % get new lines

linedata = strsplit(hdrc,sprintf('\n'));

h.header_size = 4096;

d = dir(filename);
h.data_size = d(1).bytes - h.header_size;
h.bytes_per_sample = 4;

reading_header = true;
i = 1;

while reading_header
	if ~isempty(findstr(linedata{i},'BJG'))
		h.format = linedata{i};
	end
	if numel(find(linedata{i}==':'))==2 & numel(find(linedata{i}=='-'))==3
		h.datestamp = linedata{i};
	end
	if ~isempty(findstr(linedata{i},'Channels'))
		h.num_channels = sscanf(linedata{i},'%dChannels');
	end
	if ~isempty(findstr(linedata{i},'Samples/Second per Channel'))
		h.sample_rate = sscanf(linedata{i},'%fSamples/Second per Channel');
	end
	if strcmpi(linedata{i},'start')
		start_Count = i;
		i = i + 1;
		gotstop = false;
		channel_names = {};
		while ~gotstop
			if strcmpi(linedata{i},'stop')
				reading_header = false;
				gotstop = true;
			elseif i-start_Count>h.num_channels
				error(['Read too many channel names without stop.']);
			else
				channel_names{end+1} = linedata{i};
				i = i + 1;
			end
		end
		h.channel_names = channel_names(:);
	end
	i = i + 1;
	if i>numel(linedata)
		reading_header = false;
	end
end

h.samples = h.data_size / (h.num_channels * h.bytes_per_sample);
h.local_t0 = 0;
h.local_t1 = (1/h.sample_rate) * (h.samples-1);
h.duration = (1/h.sample_rate) * (h.samples);

