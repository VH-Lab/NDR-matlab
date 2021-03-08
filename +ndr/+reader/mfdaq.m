% NDR_READER_MFDAQ - Multifunction DAQ reader class
%
% The ndr.reader.mfdaq object class.
%
% This object allows one to address multifunction data acquisition systems that
% sample a variety of data types potentially simultaneously. 
%
% The channel types that are supported are the following:
% Channel type (string):      | Description
% -------------------------------------------------------------
% 'analog_in'   or 'ai'       | Analog input
% 'analog_out'  or 'ao'       | Analog output
% 'digital_in'  or 'di'       | Digital input
% 'digital_out' or 'do'       | Digital output
% 'time'        or 't'        | Time
% 'auxiliary_in','aux' or 'ax'| Auxiliary channels
% 'event', or 'e'             | Event trigger (returns times of event trigger activation)
% 'mark', or 'mk'             | Mark channel (contains value at specified times)
% 
%
% See also: ndr.reader.mfdaq/ndr.reader.mfdaq
%

classdef mfdaq < ndr.reader
	properties (GetAccess=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = mfdaq(varargin)
			% ndr.reader.mfdaq - Create a new multifunction DAQ object
			%
			%  D = ndr.reader.mfdaq()
			%
			%  Creates a new ndi.daq.reader.mfdaq object.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndr.reader(varargin{:});
		end; % ndr.reader.mfdaq

        function ec = epochclock(ndr_reader_mfdaq_obj, epoch_number)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDR_READER_MFDAQ_OBJ, EPOCH_NUMBER)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndr.time.clocktype objects (or sub-class members).
			% 
			% For the generic ndi.daq.reader.mfdaq, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: ndr.time.clocktype
            %
                ec = {ndi.time.clocktype('dev_local_time')};
        end % epochclock

		function t0t1 = t0_t1(ndr_epochset_obj, epochfiles)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDR_EPOCHSET_OBJ, EPOCHFILES)
			%
			% Return the beginning (t0) and end (t1) times of the epoch defined by EPOCHFILES.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: ndr.time.clocktype, EPOCHCLOCK
			%
				t0t1 = {[NaN NaN]};
		end % t0t1


		function channels = getchannelsepoch(ndr_reader_mfdaq_obj, epochfiles)
			% GETCHANNELSEPOCH - List the channels that were sampled for this epoch
			%
			%  CHANNELS = GETCHANNELSEPOCH(NDR_READER_MFDAQ_OBJ, EPOCHFILES)
			%
			%  Returns the channel list of acquired channels in these EPOCHFILES
			%
			%  The channels are of different types. In the below, 
			%  'n' is replaced with the channel number.
			%  Type       | Description
			%  ------------------------------------------------------
			%  ain        | Analog input (e.g., ai1 is the first input channel)
			%  din        | Digital input (e.g., di1 is the first input channel)
			%  t          | Time - a time channel
			%  axn        | Auxillary inputs
			%
			% CHANNELS is a structure list of all channels with fields:
			% -------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data stored in the channel
			%                    |    (e.g., 'analog_input', 'digital_input', 'image', 'timestamp')
			%
				channels = struct('name',[],'type',[]);  
				channels = channels([]);
		end; % getchannelsepoch

		function data = readchannels_epochsamples(ndr_reader_mfdaq_obj, channeltype, channel, epochfiles, s0, s1)
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

		function [data] = readevents_epochsamples(ndr_reader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
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
			%
			%  TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
			%  
				if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
					data = {};
					for i=1:numel(channel),
						% optimization speed opportunity
						srd = ndr_reader_mfdaq_obj.samplerate(epochfiles,{'di'}, channel(i));
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndr_reader_mfdaq_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						time_here = ndr_reader_mfdaq_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
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
					data = ndr_reader_mfdaq_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochfiles, t0, t1); % abstract class
				end;
					
		end; % readevents_epochsamples

		function [data] = readevents_epochsamples_native(ndr_reader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
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

                function sr = samplerate(ndr_reader_mfdaq_obj, epochfiles, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
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