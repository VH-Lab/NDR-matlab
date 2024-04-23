function header = read_SEV_header(dirname, varargin)
% READ_SEV_HEADER - read the header and channel information for a TDT directory of files
%
% HEADER = READ_SEV_HEADER(DIRNAME)
%
% 
%


if ~isfolder(dirname),
	error(['Expected a directory for ' dirname '.']);
end;


	% mimicked from SEV2mat.m by TDT

CHANNEL   = 0;
EVENTNAME = '';
DEVICE    = '';
TANK      = '';
BLOCK     = '';
T1        = 0;
T2        = 0;
RANGES    = [];
VERBOSE   = 0;
JUSTNAMES = 0;
FS        = 0;

VALID_PARS = {'CHANNEL','EVENTNAME','DEVICE','TANK','BLOCK','T1','T2' ...
    'RANGES','VERBOSE','JUSTNAMES','FS'};

% parse varargin
for ii = 1:2:length(varargin),
    if ~ismember(upper(varargin{ii}), VALID_PARS)
        error('%s is not a valid parameter. See help SEV2mat.', upper(varargin{ii}));
    end
    eval([upper(varargin{ii}) '=varargin{ii+1};']);
end

if any([~isempty(DEVICE) ~isempty(TANK) ~isempty(BLOCK)])
    if any([isempty(DEVICE) isempty(TANK) isempty(BLOCK)])
        error('DEVICE, TANK and BLOCK must all be specified');
    else
        dirname = sprintf('\\\\%s\\data\\%s\\%s\\', DEVICE, TANK, BLOCK);
    end
end;

data = [];
sample_info = []; 

ALLOWED_FORMATS = {'single','int32','int16','int8','double','int64'};

JUSTNAMES = 0;

file_list = dir([dirname filesep '*.sev']);

% parse log files
if JUSTNAMES == 0
	sample_info = ndr.format.tdt.read_SEV_logs(dirname,'VERBOSE',VERBOSE);
end

for ii=1:numel(file_list),

	[pathstr, name, ext] = fileparts(file_list(ii).name);

	% find channel number
	matches = regexp(name, '_[Cc]h[0-9]*', 'match');
	if ~isempty(matches)
		sss = matches{end};
		file_list(ii).chan = str2double(sss(4:end));
	end

	% find starting hour
	matches = regexp(name, '-[0-9]*h', 'match');
	if ~isempty(matches)
		sss = matches{end};
		file_list(ii).hour = str2double(sss(2:end-1));
	else
		file_list(ii).hour = 0;
	end

	% check file size
	file_list(ii).data_size = file_list(ii).bytes - 40;

	path = [dirname filesep file_list(ii).name];
	fid = fopen(path, 'rb');
	if fid < 0
		error([path ' not opened'])
		return
	end

	% create and fill streamHeader struct
	streamHeader = [];

	streamHeader.fileSizeBytes   = fread(fid,1,'uint64');
	streamHeader.fileType        = char(fread(fid,3,'char')');
	streamHeader.fileVersion     = fread(fid,1,'char');

	% event name of stream
	s = regexp(name, '_', 'split');
	ind = cellfun(@isempty,s); s = s(~ind); % remove any empty cells, like if name is 'Raw_'
	if length(s) > 1
		nm = strcat(s{end-1}, '____'); nm = nm(1:4);
		streamHeader.eventName = nm;
	else
		streamHeader.eventName = name;
	end

	if streamHeader.fileVersion < 4

		% prior to v3, OpenEx and RS4 were not setting this properly
		% (one of them was flipping it)
		if streamHeader.fileVersion == 3
			streamHeader.eventName  = char(fread(fid,4,'char')');
		else
			oldEventName  = char(fread(fid,4,'char')');

			% if name from file is way off, then don't use it.
			flippedName = fliplr(oldEventName);
			if strcmp(streamHeader.eventName, oldEventName) == 1 || ...
				strcmp(streamHeader.eventName, flippedName) == 1
			else
				streamHeader.eventName  = oldEventName;
			end
			%streamHeader.eventName  = fliplr(char(fread(fid,4,'char')'));
		end
		%else
		%    streamHeader.eventName  = fliplr(char(fread(fid,4,'char')'));
		%end

		% current channel of stream
		file_list(ii).chan = fread(fid, 1, 'uint16'); % SDV modification, taking this out of streamHeader
		% total number of channels in the stream
		streamHeader.totalNumChannels  = fread(fid, 1, 'uint16');
		% number of bytes per sample
		streamHeader.sampleWidthBytes  = fread(fid, 1, 'uint16');
		reserved                 = fread(fid, 1, 'uint16');

		% data format of stream in lower four bits
		dform = fread(fid, 1, 'uint8');
		streamHeader.dForm      = ALLOWED_FORMATS{bitand(dform,7)+1};

		% used to compute actual sampling rate
		decimate   = fread(fid, 1, 'uint8'); % SDV taking this out of the header that is returned
		rate       = fread(fid, 1, 'uint16'); % SDV taking this out of the header that is returned
	else
		error([file_list(ii).name ' has unknown version ' num2str(streamHeader.fileVersion)]);
	end

	% compute sampling rate
	if streamHeader.fileVersion > 0
		%streamHeader.fs = 2^(streamHeader.rate)*25000000/2^12/streamHeader.decimate;
		streamHeader.fs = 2^(rate - 12) * 25000000 / decimate;
	else
		% make some assumptions if we don't have a real header
		streamHeader.dForm = 'single';
		streamHeader.fs = 24414.0625;
		s = regexp(file_list(ii).name, '_', 'split');
		streamHeader.eventName = s{end-1};
		streamHeader.channelNum = str2double(regexp(s{end},  '\d+', 'match'));
		file_list(ii).chan = streamHeader.channelNum;
		warning('%s has empty header; assuming %s ch %d format %s\nupgrade to OpenEx v2.18 or above\n', ...
			file_list(ii).name, streamHeader.eventName, ...
			streamHeader.channelNum, streamHeader.dForm);
	end

	if FS > 0
		streamHeader.fs = FS;
	end

	% add log info if it exists
	if JUSTNAMES == 0
		file_list(ii).start_sample = 1;
		file_list(ii).gaps = [];
		file_list(ii).gap_text = '';
		for jj = 1:length(sample_info)
			if strcmp(streamHeader.eventName, sample_info(jj).name)
				if file_list(ii).hour == sample_info(jj).hour
					file_list(ii).start_sample = sample_info(jj).start_sample;
					file_list(ii).gaps = sample_info(jj).gaps;
					file_list(ii).gap_text = sample_info(jj).gap_text;
				end
			end
		end
	end

	% check variable name (workaround for makeValidName support in older Matlab)
	% varname = matlab.lang.makeValidName(streamHeader.eventName); % newer matlab supports this instead
	varname = streamHeader.eventName;
	prepend_x = 0;
	for jj = 1:numel(varname)
		% replace bad field characters with '_'
		if ~isletter(varname(jj)) && isnan(str2double(varname(jj)))
			varname(jj) = '_';
		end

		% can't start field name with an underscore or number
		if jj == 1 && (varname(jj) == '_' || ~isnan(str2double(varname(jj))))
			prepend_x = 1;
		end
	end

	if prepend_x
		varname = ['x' varname];
	end

	%fprintf('%s   %s\n', varname, matlab.lang.makeValidName(streamHeader.eventName))

	if ~isvarname(streamHeader.eventName)
		warning('%s is not a valid Matlab variable name, changing to %s', streamHeader.eventName, varname);
	end

	func = str2func(streamHeader.dForm);
	tempvar = func(zeros(1,1));
	w = whos('tempvar');
	file_list(ii).itemSize = w.bytes;
	file_list(ii).npts = file_list(ii).data_size / file_list(ii).itemSize;
	file_list(ii).fs = streamHeader.fs;
	file_list(ii).dForm = streamHeader.dForm;
	file_list(ii).eventName = streamHeader.eventName;
	file_list(ii).varName = varname;
	fclose(fid);

end; % loop over file_list

header = file_list;
