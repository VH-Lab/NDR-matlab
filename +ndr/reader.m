classdef reader

	properties (GetAccess=public, SetAccess=protected)
		ndr_reader_base      % the ndr reader base object, that actually reads the files
	end;

	methods
		function ndr_reader_obj = reader(ndr_reader_type)
			% NDR - create a new Neuroscience Data Reader object
			%
			% NDR_READER_OBJ = ndr.reader(NDR_READER_TYPE)
			%
			% Creates an Neuroscence Data Reader object of the indicated type.
			% Some valid types include 'IntanRHD', 'CedSpike2', 'SpikeGadgets', 'Blackrock'.
			%
				j = ndr.fun.ndrresource('ndr_reader_types.json');
				match = 0;
				for i=1:numel(j),
                    if any(strcmpi(ndr_reader_type, j(i).type)),
                    	match = i;
                        break;
                    end;
				end;
				if match==0,
					error(['Do not know how to make a reader of type ''' ndr_reader_type '''.']);
				end;
				ndr_reader_obj.ndr_reader_base = feval(j(match).classname);
		end; % reader()

		function [data, time] = read(ndr_reader_obj, epochstreams, channelstring, varargin)
			% READ - read data from an ndr.reader object
			%
			% CHANNELSTRING can be multiple things.
			%   For most readers, it should be a string of NDR channel names, e.g. 'ai1-3+b2-4'.
			%   Intan reader accepts both the NDR channel names, e.g. 'ai1-3+b2-4', and device channel names, e.g. 'A021+A022'.
			%   Neo reader stands as an exception - it expects device channel names, but as a cell array, e.g. { 'A-000', 'A-001' }.
			% 
			% [DATA, TIME] = READ(NDR_READER_OBJ, EPOCHSTREAMS, CHANNELSTRING, ...)
			%
			% This function takes additional arguments in the form of name/value pairs.
			% -------------------------------------------------------------------------
			% | Parameter (default)       | Description                               |
			% |---------------------------|-------------------------------------------|
			% | t0 (-Inf)                 | Time to start reading (in units of        |
			% |                           |     epochclock). Use -Inf to start from   |
			% |                           |     earliest sample available.            |
			% | t1 (Inf)                  | Time to stop reading (in units of         |
			% |                           |    epochclock). Use Inf to stop at the    |
			% |                           |    last sample available.                 |
			% | epoch_select (1)          | The epoch within EPOCHSTREAMS to select.  |
			% |                           |    Usually, there is only 1 epoch per file|
			% |                           |    but some file formats support more than|
			% |                           |    1 epoch per file.                      |
			% | useSamples (0)            | Use sample numbers instead of time        |
			% | s0 (NaN)                  | Sample number to start reading, if        |
			% |                           |    useSamples is 1. First sample is 1.    |
			% | s1 (NaN)                  | Sample number to stop reading, if         |
			% |                           |    useSamples is 1. Last sample is Inf.   |
			% -------------------------------------------------------------------------
			%
			%
				t0 = -Inf;
				t1 = Inf;
				epoch_select = 1;
				useSamples = 0;
				s0 = NaN;
				s1 = NaN;

				ndr.data.assign(varargin{:});

				if strcmp(class(ndr_reader_obj.ndr_reader_base), 'ndr.reader.neo'),
					channelprefix = {};
					channelnumber = channelstring;
				else,
					[channelprefix, channelnumber] = ndr.string.channelstring2channels(channelstring);
				end;

				channelstruct = daqchannels2internalchannels(ndr_reader_obj.ndr_reader_base, ...
					channelprefix, channelnumber, epochstreams, epoch_select);

				[b,errormsg] =  ndr_reader_obj.ndr_reader_base.canbereadtogether(channelstruct);

				if b,
					switch (channelstruct(1).ndr_type),
						case {'analog_input','analog_output','analog_in','analog_out','ai','ao'},
							if ~useSamples, % must compute the samples to be read
								s0 = round(1+t0*channelstruct(1).samplerate);
								s1 = round(1+t1*channelstruct(1).samplerate);
							end;
							data = ndr_reader_obj.readchannels_epochsamples(channelstruct(1).internal_type, ...
                                [channelstruct.internal_number],epochstreams,epoch_select,s0,s1);
							time = ndr_reader_obj.readchannels_epochsamples('time',...
								[channelstruct.internal_number],epochstreams,epoch_select,s0,s1); % how to read this in general??
						otherwise, % readevents
							[data,time] = ndr_reader_obj.readevents_epochsamples({channelstruct.internal_type},...
								channelstruct.internal_number,epochstreams,epoch_select,t0,t1);
					end;
				else, % we can't do it, report an error
					error(['Specified channels in channelstring (' ...
						channelstring ...
						') cannot be read in a single function call. Please split channel reading by similar channel types. ' ...
						errormsg]);
				end;
		end; % read() 

		function ec = epochclock(ndr_reader_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the ndr.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Return the clock types available for this epoch as a cell array
			% of ndr.time.clocktype objects (or sub-class members).
			%
			% This function calls the method of the ndr_reader_base class.
			% 
			% If EPOCH_SELECT is not provided, it is assumed to be 1.
			%
			% See also: ndr.time.clocktype
			%       
				if nargin<3,
					epoch_select = 1;
				end;
				ec = ndr_reader_obj.ndr_reader_base.epochclock(epochstreams, epoch_select);
		end % epochclock

		function t0t1 = t0_t1(ndr_reader_obj, epochstreams, epoch_select)
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Return the beginning (t0) and end (t1) times of the epoch defined by EPOCHSTREAMS and EPOCH_SELECT.
			%
			% This function calls the method of the ndr_reader_base class.
			%
			% If EPOCH_SELECT is not provided, it is assumed to be 1.
			%
			% See also: ndr.time.clocktype, ndr.reader.base/epochclock
			%
				if nargin<3,
					epoch_select = 1;
				end;
				t0t1 = ndr_reader_obj.ndr_reader_base.t0_t1(epochstreams, epoch_select);
		end % t0_t1()

		function channels = getchannelsepoch(ndr_reader_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - List the channels that are available on this device for a given epoch
			%
			% CHANNELS = GETCHANNELSEPOCH(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the channel list of acquired channels in this epoch.
			% EPOCHSTREAMS should be a cell array of files or streams that comprise this epoch.
			% EPOCH_SELECT indicates the epoch within the EPOCHSTREAMS files to select. The vast
			%   majority of systems only allow one EPOCH per file, so EPOCH_SELECT is usually 1.
			%   It defaults to 1 if it is not given.
			%
			%
			% CHANNELS is a structure list of all channels with fields:
			% -------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data stored in the channel
			%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
			%
			%
			%
				if nargin<3,
					epoch_select = 1; % most devices have only a single epoch per file
				end;
				channels = ndr_reader_obj.ndr_reader_base.getchannelsepoch(epochstreams, epoch_select);
		end; % getchannelsepoch()

		function data = readchannels_epochsamples(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
			%  FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%
				data = ndr_reader_obj.ndr_reader_base.readchannels_epochsamples(channeltype, channel, epochstreams, epoch_select, s0, s1);
		end % readchannels_epochsamples()

		function [timestamps, data] = readevents_epochsamples(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
			%
			%  Returns TIMESTAMPS and DATA corresponding to event or marker channels. If the number of CHANNEL entries is 1, then TIMESTAMPS
			%  is a column vector of type double, and DATA is also a column of a type that depends on the type of event that is read. 
			%  If the number of CHANNEL entries is more than 1, then TIMESTAMPS and DATA are both columns of cell arrays, with 1 column
			%  per channel.
			%  
			%  CHANNELTYPE is a cell array of strings, describing the type of each channel to read, such as
			%      'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for each timestamp
			%      'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the data associated with the marker (type double)
			%      'text' - TIMESTAMPS mark the occurence of each event; DATA is a cell array of character arrays, 1 per event
			%      'dep' - Create events from a digital channel with positive transitions. TIMESTAMPS mark the occurence of each event and
			%              DATA entries will be a 1
			%      'dimp' - Create events from a digital channel by finding impulses that exhibit positive then negative transitions. TIMESTAMPS
			%               mark the occurrence of each event, and DATA indicates whether the event is a positive transition (1) or negative (-1)
			%               transition.
			%      'den' - Create events from a digital channel with negative transitions. TIMESTAMPS mark the occurrence of each event and
			%              DATA entries will be a -1.
			%      'dimn' - Create events from a digital channel by finding impulses that exhibit negative then positive transitions. TIMESTAMPS
			%               mark the occurence of each event, and DATA indicates whether the event is a negative transition (1) or a positive
			%               transition (-1).
			%
			%  CHANNEL is a vector with the identity(ies) of the channel(s) to be read.
			%
			%  EPOCHSTREAMS is a cell array of full path file names or remote 
			%  access streams that comprise the epoch of data
			%
			%  EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			%  if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			%
				  % Step 1: check to see if the user is requesting a "native" type of event (event,marker,text) or a "derived" type of event
				  %     (like dep, den, dimp, dimn, which are derived from the data of sampled digital channels)
				  %      If the user does request a derived event type, then compute it
 
				if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
					timestamps = {};
					data = {};
					for i=1:numel(channel),
						% optimization speed opportunity
						srd = ndr_reader_obj.samplerate(epochfiles,{'di'}, channel(i));
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndr_reader_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						time_here = ndr_reader_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						if any(strcmp(channeltype{i},{'dep','dimp'})), % look for 0 to 1 transitions
							transitions_on_samples = find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
							if strcmp(channeltype{i},'dimp'),
								transitions_off_samples = 1+ find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
							else,
								transitions_off_samples = [];
							end;
						elseif any(strcmp(channeltype{i},{'den','dimn'})), % look for 1 to 0 transitions
							transitions_on_samples = find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
							if strcmp(channeltype{i},'dimp'),
								transitions_off_samples = 1+ find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
							else,
								transitions_off_samples = [];
							end;
						end;
						timestamps{i} = [ndr.data.colvec(time_here(transitions_on_samples)); ndr.data.colvec(time_here(transitions_off_samples)) ]; 
						data{i} = [ones(numel(transitions_on_samples),1); -ones(numel(transitions_off_samples),1) ];
						if ~isempty(transitions_off_samples),
							[dummy,order] = sort(timestamps{i}(:,1));
							timestamps{i} = timestamps{i}(order,:);
							data{i} = data{i}(order,:); % sort by on/off
						end;
					end;

					if numel(channel)==1,
						timestamps = timestamps{1};
						data = data{1};
					end;
				else,
					% if the user doesn't want a derived channel, we need to read it from the file natively (using the class's reader function)
					[timestamps, data] = ndr_reader_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochstreams, epoch_select, t0, t1); % abstract class
				end;
		end; % readevents_epochsamples()

		function [timestamps, data] = readevents_epochsamples_native(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  CHANNELTYPE is a cell array of strings, describing the type of each channel to read, such as
			%      'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for each timestamp
			%      'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the data associated with the marker (type double)
			%      'text' - TIMESTAMPS mark the occurence of each event; DATA is a cell array of character arrays, 1 per event
			%  One cannot use the event types that are derived from digital data ('dep','dimp','den','dimn') with 
			%      READEVENTS_EPOCHSAMPLES_NATIVE. Use READEVENTS_EPOCHSAMPLES instead.
			%
			%  CHANNEL is a vector with the identity(ies) of the channel(s) to be read.
			%
			%  EPOCHSTREAMS is a cell array of full path file names or remote 
			%  access streams that comprise the epoch of data
			%
			%  EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			%  if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
				[timestamps,data] = ndr_reader_obj.ndr_reader_base.readevents_epochsamples_native(channeltype, channel, epochstreams, epoch_select, t0, t1);
		end; % readevents_epochsamples

		function sr = samplerate(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL FOR REGULARLY-SAMPLED CHANNELS
			%
			% SR = SAMPLERATE(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% SR is an array of sample rates from the specified channels
			%
			%  CHANNELTYPE is a cell array of strings, describing the type of each channel to read. This must be a regularly-sampled type, such as
			%      'analog_input' or 'ai' - regularly sampled analog input
			%      'analog_output' or 'ao' - regularly sampled analog output
			%      'digital_input' or 'di' - regularly sampled digital input
			%      'digital_output' or 'do' - regularly sampled digital output
			%
			%  CHANNEL is a vector with the identity(ies) of the channel(s) to be read.
			%
			%  EPOCHSTREAMS is a cell array of full path file names or remote 
			%  access streams that comprise the epoch of data
			%
			%  EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			%  if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
				sr = ndr.reader_obj.ndr_reader_base.samplerate(epochstreams, epoch_select, channeltype, channel);
		end;

	end; % methods
end % classdef


