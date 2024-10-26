function [data] = read_abf(filename, header, channel_type, channel_numbers, t0, t1)
% READ_ABF - read from an Axon Instruments ABF file
%
% [DATA] = READ_ABF(FILENAME, HEADER, CHANNEL_TYPE, CHANNEL_NUMBERS, T0, T1)
%
% Reads data from an Axon Instruments ABF file
%
% Inputs:
%   FILENAME - the filename to read
%   HEADER - the header data for the file; if empty, it will be read
%   CHANNEL_TYPE - the type of channel to read. It can be
%      'ai'   - analog input
%      'time' - time
%   CHANNEL_NUMBERS - an array of channel numbers to read (e.g., [1 2 3])
%   T0 - time to begin reading; can be -Inf to indicate the beginning of the record
%   T1 - time to end reading; can be Inf to indicate the end of the record
%

if isempty(header),
	header = ndr.format.axon.read_abf_header(filename);
end;

if (isinf(t0) & t0<0) | (t0<0),
	t0 = 0;
end;

MaxTime = diff(header.recTime)-header.si*1e-6;

if (t1>MaxTime)
	t1 = MaxTime;
end;

switch lower(channel_type),
	case 'time',
		if ~isfield(header,'sweepLengthInPts'),
			data = [t0:header.si*1e-6:t1];
		else,
			data = [];
			for i=1:numel(header.sweepStartInPts),
				dt = header.si*1e-6;
				startTime = header.sweepStartInPts(i)*dt;
				endTime = startTime + (header.sweepLengthInPts-1) * dt;
				data = cat(2,data,startTime:dt:endTime);
			end;
			data = data(find(data>=t0 & data<=t1+0.5*header.si*1e-6));
		end;
	case {'ai','analog_in'},
		channel_names = header.recChNames(channel_numbers);
		[channel_num_sorted,channel_num_sorted_idx] = sort(channel_numbers);
		data = abfload2(filename,'start',t0,'stop',t1+1e-6*header.si,'channels',channel_names,...
			'doDispInfo',false);
		if size(data,3)>1, % sweeps are different, it seems to read in the whole thing and ignore the times
			times = ndr.format.axon.read_abf(filename, header, 'time', 1, -inf, inf);
			data2 = [];
			for i=1:size(data,3),
				data2 = cat(1,data2,data(:,:,i));
			end;
			data = data2;
			data = data(find(times>=t0 & times<=t1+0.5*header.si*1e-6));
		end;
		data(:,channel_num_sorted_idx) = data;
	otherwise,
		error(['unknown channel type to ABF ' channel_type])
end;


