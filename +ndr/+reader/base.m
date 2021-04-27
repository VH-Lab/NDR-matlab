classdef base

	methods
		function ndr_reader_base_obj = base(ndr_reader_type)
			% READER - create a new Neuroscience Data Reader Base object
			%
			% READER_OBJ = ndr.reader.base()
			%
			% Creates an Neuroscence Data Reader object of the indicated type.
			%
		end; % READER()

		function ec = epochclock(ndr_reader_base_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the ndr.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Return the clock types available for this epoch as a cell array
			% of ndr.time.clocktype objects (or sub-class members).
			%
			% For the generic ndr.reader.base, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: ndr.time.clocktype
			%
				ec = {ndr.time.clocktype('dev_local_time')};
		end % epochclock

		function t0t1 = t0_t1(ndr_reader_base_obj, epochstreams, epoch_select)
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Return the beginning (t0) and end (t1) times of the epoch defined by EPOCHSTREAMS and EPOCH_SELECT.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: ndr.time.clocktype, ndr.reader.base/epochclock
			%
				t0t1 = {[NaN NaN]};
		end % t0_t1()

		function channels = getchannelsepoch(ndr_reader_base_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - List the channels that are available on this device for a given epoch
			%
			% CHANNELS = GETCHANNELSEPOCH(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the channel list of acquired channels in this epoch
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
				channels = struct('name',[],'type',[]);
				channels = channels([]);
		end; % getchannelsepoch()

		function data = readchannels_epochsamples(ndr_reader, channeltype, channel, epochstreams, epoch_select, s0, s1)
			%  FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%
				data = []; % abstract class
		end % readchannels_epochsamples()

		function [data] = readevents_epochsamples(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', 'dep', 'dimp', 'dimn', etc). It must be a a cell array of strings.
			%
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%
			%  EPOCH is the epoch number or epochID
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.

				if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
					data = {};
					for i=1:numel(channel),
						% optimization speed opportunity
						srd = ndr_reader_base_obj.samplerate(epochfiles,{'di'}, channel(i));
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndr_reader_base_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						time_here = ndr_reader_base_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
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
						data{i} = [ [vlt.data.colvec(time_here(transitions_on_samples)); vlt.data.colvec(time_here(transitions_off_samples)) ] ...
								[ones(numel(transitions_on_samples),1); -ones(numel(transitions_off_samples),1) ] ];
						if ~isempty(transitions_off_samples),
							[dummy,order] = sort(data{i}(:,1));
							data{i} = data{i}(order,:); % sort by on/off
						end;
					end;

					if numel(channel)==1,
						data = data{1};
					end;
				else,
					data = ndr_reader_base_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochfiles, t0, t1); % abstract class
				end;
		end; % readevents_epochsamples()

		function [data] = readevents_epochsamples_native(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc). It must be a string (not a cell array of strings).
			%
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%
			%  EPOCH is the epoch number or epochID
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%
			%  TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
			%
				data = []; % abstract class
		end; % readevents_epochsamples

		function sr = samplerate(ndr_reader_base_obj, epochstreams, epoch_select, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%
			% CHANNELTYPE can be either a string or a cell array of
			% strings the same length as the vector CHANNEL.
			% If CHANNELTYPE is a single string, then it is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.
				sr = []; % abstract class;
		end;

	end; % methods

	methods (Static), % functions that don't need the object
		function ct = mfdaq_channeltypes
			% MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq objects
			%
			%  CT = MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq objects
			%
			%  Returns a cell array of strings of supported channels of the
			%  ndi.daq.system.mfdaq class. These are the following:
			%
			%  Channel type:       | Description: 
			%  -------------------------------------------------------------
			%  analog_in           | Analog input channel
			%  aux_in              | Auxiliary input
			%  analog_out          | Analog output channel
			%  digital_in          | Digital input channel
			%  digital_out         | Digital output channel
			%  marker              | 
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
			ct = { 'analog_in', 'aux_in', 'analog_out', 'digital_in', 'digital_out', 'marker', 'event', 'time' };
		end;

		function prefix = mfdaq_prefix(channeltype)
			% MFDAQ_PREFIX - Give the channel prefix for a channel type
			%
			%  PREFIX = MFDAQ_PREFIX(CHANNELTYPE)
			%
			%  Produces the channel name prefix for a given CHANNELTYPE.
			% 
			% Channel type:               | MFDAQ_PREFIX:
			% ---------------------------------------------------------
			% 'analog_in',       'ai'     | 'ai' 
			% 'analog_out',      'ao'     | 'ao'
			% 'digital_in',      'di'     | 'di'
			% 'digital_out',     'do'     | 'do'
			% 'time','timestamp','t'      | 't'
			% 'auxiliary','aux','ax',     | 'ax'
			%    'auxiliary_in'           | 
			% 'mark', 'marker', or 'mk'   | 'mk'
			% 'text'                      | 'text'
			% 'event' or 'e'              | 'e'
			% 'metadata' or 'md'          | 'md'
			% 'digital_in_event', 'de',   | 'dep'
			% 'digital_in_event_pos','dep'| 
			% 'digital_in_event_neg','den'| 'den'
			% 'digital_in_mark','dimp',   | 'dimp'
			% 'digital_in_mark_pos','dim' |
			% 'digital_in_mark_neg','dimn'| 'dimn'
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
			%
				switch channeltype,
					case {'analog_in','ai'},
						prefix = 'ai';
					case {'analog_out','ao'},
						prefix = 'ao';
					case {'digital_in','di'},
						prefix = 'di';
					case {'digital_out','do'},
						prefix = 'do';
					case {'digital_in_event','digital_in_event_pos','de','dep'},
						prefix = 'dep';
					case {'digital_in_event_neg','den'},
						prefix = 'den';
					case {'digital_in_mark', 'digital_in_mark_pos','dim','dimp'},
						prefix = 'dimp';
					case {'digital_in_mark_neg','dimn'},
						prefix = 'dimn';
					case {'time','timestamp','t'},
						prefix = 't';
					case {'auxiliary','aux','ax','auxiliary_in'},
						prefix = 'ax';
					case {'marker','mark','mk'},
						prefix = 'mk';
					case {'event','e'},
						prefix = 'e';
					case {'metadata','md'},
						prefix = 'md';
					case {'text'},
						prefix = 'text';
				end;
		end % mfdaq_prefix()

		function type = mfdaq_type(channeltype)
			% MFDAQ_TYPE - Give the preferred long channel type for a channel type
			%
			%  TYPE = MFDAQ_TYPE(CHANNELTYPE)
			%
			%  Produces the preferred long channel type name for a given CHANNELTYPE.
			% 
			% Channel type:               | MFDAQ_TYPE:
			% ---------------------------------------------------------
			% 'analog_in',       'ai'     | 'analog_in' 
			% 'analog_out',      'ao'     | 'analog_out'
			% 'digital_in',      'di'     | 'digital_in'
			% 'digital_out',     'do'     | 'digital_out'
			% 'time','timestamp','t'      | 'time'
			% 'auxiliary','aux','ax',     | 'auxiliary'
			%    'auxiliary_in'           | 
			% 'mark', 'marker', or 'mk'   | 'mark'
			% 'event' or 'e'              | 'event'
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_PREFIX
			%
				switch channeltype,
					case {'analog_in','ai'},
						type = 'analog_in';
					case {'analog_out','ao'},
						type = 'analog_out';
					case {'digital_in','di'},
						type = 'digital_in';
					case {'digital_out','do'},
						type = 'digital_out';
					case {'time','timestamp','t'},
						type = 'time';
					case {'auxiliary','aux','ax','auxiliary_in'},
						type = 'ax';
					case {'marker','mark','mk'},
						type = 'mark';
					case {'event','e'},
						type = 'event';
				end;
		end;
	
	end % methods (Static)
end % classdef
