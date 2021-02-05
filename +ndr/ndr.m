classdef ndr

	properties (GetAccess=public, SetAccess=protected)
		ndr_reader      % the ndr reader object
	end;

	methods
		function ndr_obj = ndr(ndr_reader_type)
			% NDR - create a new Neuroscience Data Reader object
			%
			% NDR_OBJ = NDR(NDR_READER_TYPE)
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
				ndr_obj.ndr_reader = feval(j(match).classname);
		end; % ndr()

		function ec = epochclock(ndr_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - returns the types of time units available to this epoch of data
			%

		end; % epochclock()

		function channels = getchannelsepoch(ndr_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - List the channels that are available on this device for a given epoch
			%
			% CHANNELS = GETCHANNELSEPOCH(NDR_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
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

		function [data] = readevents_epochsamples(ndr_reader, channeltype, channel, epochstreams, epoch_select, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
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
						srd = ndi_daqreader_mfdaq_obj.samplerate(epochfiles,{'di'}, channel(i));
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						time_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
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
					data = ndi_daqreader_mfdaq_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochfiles, t0, t1); % abstract class
				end;
		end; % readevents_epochsamples()

		function [data] = readevents_epochsamples_native(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
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

		function sr = samplerate(ndr_obj, epochstreams, epoch_select, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(NDR_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
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
end % classdef


