classdef base

	properties (SetAccess=protected)
		MightHaveTimeGaps = false; % Boolean: true if the reader might have time gaps, false otherwise
	end

	methods
		function ndr_reader_base_obj = base(ndr_reader_type)
			% READER - create a new Neuroscience Data Reader Base object
			%
			% READER_OBJ = ndr.reader.base()
			%
			% Creates an Neuroscence Data Reader object of the indicated type.
			%
		end; % READER()

		function [b,errormsg] = canbereadtogether(ndr_reader_base_obj, channelstruct)
			% CANBEREADTOGETHER - can the channels in a channel struct be read in a single function call?
			% 
			% [B,ERRORMSG] = CANBEREADTOGETHER(NDR_READER_BASE_OBJ, CHANNELSTRUCT)
			%
			% Returns 1 if the NDR_READER_BASE_OBJ can read all of the channels in
			% CHANNELSTRUCT with a single function call. If they cannot be read together,
			% a description is provided in ERRORMSG.
			%
			% In the abstract class, this returns 1 if all of the samplerate values are
			% the same and none are NaNs.
			%
			% CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.
			% ------------------------------------------------------------------------------
			%
				% in the abstract class, this returns 1 if all the samplerates are the same
				% and none are NaNs
				b  = 1;
				errormsg = '';

				sr = [channelstruct.samplerate];
				if ~all(isnan(sr)),
					% if all are not NaN, then none can be
					if any(isnan(sr)),
						b = 0;
						errormsg = ['All samplerates must either be the same number or they must all be NaN, indicating they are all not regularly sampled channels.'];
					else,
						sr_ = uniquetol(sr);
						if numel(sr_)~=1,
							b = 0;
							errormsg = ['All sample rates must be the same for all requested regularly-sampled channels for a single function call.'];
						end;
					end;
				end;

		end; % canbereadtogether()

		function channelstruct = daqchannels2internalchannels(ndr_reader_base_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_BASE_OBJ, ...
			%    CHANNELPREFIX, CHANNELNUMBERS, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Inputs:
			% For a set of CHANNELPREFIX (cell array of channel prefixes that describe channels for
			% this device) and CHANNELNUMBER (array of channel numbers, 1 for each entry in CHANNELPREFIX),
			% and for a given recording epoch (specified by EPOCHSTREAMS and EPOCH_SELECT), this function
			% returns a structure CHANNELSTRUCT describing the channel information that should be passed to
			% READCHANNELS_EPOCHSAMPLES or READEVENTS_EPOCHSAMPLES.
			%
			% EPOCHSTREAMS is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			% Output: CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.                            |
			% ------------------------------------------------------------------------------
			%
				% abstract class returns empty
				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type','samplerate');
		end; % daqchannels2internalchannels

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
			% 'time_channel'     | The index of the time channel that describes the time of this channel
			%
			% The way 'name' is constructed depends on the reader's labeling
			% convention for that channel type. See CHANNELLABELINGCONVENTION
			% for the contract.
			%
				channels = vlt.data.emptystruct('name','type','time_channel');
		end; % getchannelsepoch()

		function convention = channelLabelingConvention(ndr_reader_base_obj, channeltype)
			% CHANNELLABELINGCONVENTION - Describe how this reader names channels of a given type
			%
			% CONVENTION = CHANNELLABELINGCONVENTION(NDR_READER_BASE_OBJ, CHANNELTYPE)
			%
			% Returns a string declaring the naming convention this reader uses
			% for channels of type CHANNELTYPE in GETCHANNELSEPOCH and as input
			% to DAQCHANNELS2INTERNALCHANNELS. CONVENTION is one of:
			%
			%   'indexed'  - Names use NDR-standard prefixes (e.g. 'ai', 'ao',
			%                'ax', 'di', 'do', 't') followed by a 1-based count
			%                of recorded channels of that type. The first
			%                recorded analog input is 'ai1', the second 'ai2',
			%                and so on, regardless of any hardware-channel gaps
			%                in the underlying file. This is the convention NDI
			%                users typically expect; it is the default and the
			%                only one for which the trailing number is safe to
			%                interpret as a position.
			%
			%   'physical' - Names use NDR-standard prefixes followed by the
			%                manufacturer's hardware channel number, in the
			%                manufacturer's own indexing base (which may be
			%                0-based, 1-based, or per-type). The number is a
			%                hardware identity, not a position, and may have
			%                gaps. Example: an Intan amplifier channel
			%                'A-007' under 'physical' would be 'ai7' (Intan
			%                amp channels are 0-based), while an Intan aux
			%                channel 'AUX1' would be 'ax1' (1-based).
			%                Consumers must not assume a uniform indexing
			%                base across types under this convention.
			%
			%   'native'   - The name is the device-native string verbatim,
			%                without any NDR-standard prefix (e.g. 'A-007',
			%                'AUX1', 'Vm', 'L_LFP'). The name is opaque: do
			%                not attempt to parse a number or type out of it.
			%                The type must be read from the channel struct's
			%                'type' field, not inferred from the name.
			%
			% A reader may return different conventions for different
			% channel types (e.g. 'indexed' for amplifier inputs and
			% 'native' for user-labeled analog signals).
			%
			% The base implementation returns 'indexed' for every channel
			% type. Subclasses should override this only if their
			% GETCHANNELSEPOCH actually emits non-indexed names.
			%
				convention = 'indexed';
		end % channelLabelingConvention()

        function [datatype,p,datasize] = underlying_datatype(ndr_reader_obj, epochstreams, epoch_select, channeltype, channel)
            % UNDERLYING_DATATYPE - get the underlying data type for a channel in an epoch
            %
            % [DATATYPE,P,DATASIZE] = UNDERLYING_DATATYPE(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            % Return the underlying datatype for the requested channel.
            %
            % DATATYPE is a type that is suitable for passing to FREAD or FWRITE
            %  (e.g., 'float64', 'uint16', etc. See help fread.)
            %
            % P is a matrix of polynomials that converts between the double data that is returned by
            % READCHANNEL. RETURNED_DATA = (RAW_DATA+P(i,1))*P(i,2)+(RAW_DATA+P(i,1))*P(i,3) ...
            % There is one row of P for each entry of CHANNEL.
            %
            % DATASIZE is the sample size in bits.
            %
            % CHANNELTYPE must be a string. It is assumed that
            % that CHANNELTYPE applies to every entry of CHANNEL.
            %

            switch(channeltype)
                case {'analog_in','analog_out','auxiliary_in','time'},
                    % For the abstract class, keep the data in doubles. This will always work but may not
                    % allow for optimal compression if not overridden
                    datatype = 'float64';
                    datasize = 64;
                    p = repmat([0 1],numel(channel),1);
                case {'digital_in','digital_out'}
                    datatype = 'char';
                    datasize = 8;
                    p = repmat([0 1],numel(channel),1);
                case {'eventmarktext','event','marker','text'}
                    datatype = 'float64';
                    datasize = 64;
                    p = repmat([0 1],numel(channel),1);
                otherwise,
                    error(['Unknown channel type ' channeltype '.']);
            end
        end

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

		function [timestamps, data] = readevents_epochsamples_native(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
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
				timestamps = [];
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

		function t = samples2times(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, s)
			% SAMPLES2TIMES - convert sample numbers to time
			%
			% T = SAMPLES2TIMES(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, S)
			%
			% Given sample numbers S, returns the time T of these samples.
			%
			% This function assumes a constant sampling rate. If the recording device permits
			% gaps, then this function should be overridden.
			%
			% See also: ndr.reader.base/times2samples
			%
				sr = ndr_reader_base_obj.samplerate(epochstreams, epoch_select, channeltype, channel);
				sr_unique = unique(sr);
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;
				t0t1 = ndr_reader_base_obj.t0_t1(epochstreams, epoch_select);
				t = ndr.time.fun.samples2times(s, t0t1{1}, sr_unique);
		end; % samples2times()

		function s = times2samples(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, t)
			% TIMES2SAMPLES - convert time to sample numbers
			%
			% S = TIMES2SAMPLES(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T)
			%
			% Given sample times T, returns the sample numbers S of these samples.
			%
			% This function assumes a constant sampling rate. If the recording device permits
			% gaps, then this function should be overridden.
			%
			% See also: ndr.reader.base/samples2times
			%
				sr = ndr_reader_base_obj.samplerate(epochstreams, epoch_select, channeltype, channel);
				sr_unique = unique(sr);
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;
				t0t1 = ndr_reader_base_obj.t0_t1(epochstreams, epoch_select);
				s = ndr.time.fun.times2samples(t, t0t1{1}, sr_unique);
		end; % times2samples()

		%% Image / frame reading API
		% The methods below define the frame-based reading interface used by
		% image-series readers (movies, z-stacks, slide scans). It is the
		% imaging counterpart of the regularly-sampled channel API above; the
		% two families are siblings, not subclasses. A reader that handles
		% images implements ONLY the frame API (not readchannels_epochsamples
		% and friends); readers that do not handle images inherit these no-op
		% defaults.
		%
		% The frame API design is modeled on nansen.stack.ImageStack
		% (VervaekeLab, https://github.com/VervaekeLab/NANSEN). See the
		% ImageStack -> frame-reader method mapping in ndr.reader.tiffstack.
		%
		% Every method takes (EPOCHSTREAMS, EPOCH_SELECT, ...) like the rest
		% of the reader API. A "frame" is one image plane along the ordering
		% axes (T, and Z when present). FRAMEIND indexes those ordering axes.

		function n = numframes(ndr_reader_base_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames in an image epoch
			%
			% N = NUMFRAMES(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the number of frames (planes along the ordering axes) in
			% the epoch. The abstract class returns 0.
			%
			% Modeled on nansen.stack.ImageStack NumTimepoints/NumPlanes.
				n = 0; % abstract class
		end % numframes()

		function sz = framesize(ndr_reader_base_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent of an image epoch, without reading pixels
			%
			% SZ = FRAMESIZE(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the full extent of the image data as a 1x5 vector
			% [Y X C Z T] (height, width, channels, z-planes, timepoints)
			% WITHOUT loading pixel data. The abstract class returns zeros.
			%
			% Modeled on nansen.stack.ImageStack/getFrameSetSize. Keeping the
			% channel axis (C) separate from the spatial (Y,X) and ordering
			% (Z,T) axes matches the V_delta axes+channels split.
				sz = [0 0 0 0 0]; % abstract class
		end % framesize()

		function order = dimensionorder(ndr_reader_base_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames
			%
			% ORDER = DIMENSIONORDER(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the order of the dimensions of the arrays returned by
			% READFRAMES and described by FRAMESIZE, as a character string
			% over {Y,X,C,Z,T}. The default is 'YXCZT'.
			%
			% Modeled on nansen.stack.ImageStack DimensionOrder/DataDimensionOrder.
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(ndr_reader_base_obj, epochstreams, epoch_select)
			% DATATYPE - the underlying numeric class of the image data
			%
			% DT = DATATYPE(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns the underlying numeric class of the image pixels (e.g.
			% 'uint16'). The abstract class returns ''.
			%
			% Modeled on nansen.stack.ImageStack DataType.
				dt = ''; % abstract class
		end % datatype()

		function t = frametimes(ndr_reader_base_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - the time of each requested frame, in EPOCHCLOCK units
			%
			% T = FRAMETIMES(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Returns an Nx1 vector of the time of each frame in FRAMEIND, in
			% the units of the clock returned by EPOCHCLOCK. For a movie this
			% is the device-local time (seconds from the start of the epoch);
			% for a clockless slide scan / z-stack the epoch clock is
			% 'no_time' and these are NaN. The abstract class returns [].
			%
			% Modeled on nansen.stack.ImageStack/getFrameTimes. The values
			% returned here feed EPOCHCLOCK and T0_T1.
				t = []; % abstract class
		end % frametimes()

		function frames = readframes(ndr_reader_base_obj, epochstreams, epoch_select, frameind)
			% READFRAMES - read image frames from an epoch
			%
			% FRAMES = READFRAMES(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Lazily reads the frames indexed by FRAMEIND (indices along the
			% ordering axes T, and Z when present) and returns them as an array
			% laid out in DIMENSIONORDER (default 'YXCZT'). All channels are
			% returned. The abstract class returns [].
			%
			% Modeled on nansen.stack.ImageStack/getFrameSet.
				frames = []; % abstract class
		end % readframes()

		function m = metadata(ndr_reader_base_obj, epochstreams, epoch_select)
			% METADATA - standardized image-acquisition metadata for an epoch
			%
			% M = METADATA(NDR_READER_BASE_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns a struct of standardized acquisition metadata for an image
			% epoch. It describes HOW the frames were acquired (in particular the
			% raster-scan timing that lets one compute when each line/pixel was
			% sampled), separately from the pixel data itself. ALL TIME FIELDS
			% ARE IN SECONDS. The struct has the fields:
			%
			%   israster        - logical; true if this epoch is a raster scan
			%                     with known line/frame timing
			%   frame_period    - time to acquire one frame (s)
			%   line_period     - time to acquire one scanned line/row (s)
			%   dwell_time      - per-pixel dwell time (s)
			%   lines_per_frame - number of scanned lines (rows) per frame
			%   pixels_per_line - number of pixels (columns) per line
			%   bidirectional   - logical; true if alternate lines are scanned
			%                     in the reverse direction
			%
			% A raster scan does not acquire a frame instantaneously: it sweeps
			% line by line, so at slow frame rates the top of a frame is acquired
			% well before the bottom. LINE_PERIOD (plus FRAMETIMES) is what lets a
			% caller reconstruct the acquisition time of each line/pixel.
			%
			% The abstract class returns the "empty" struct (israster=false, NaN
			% timing) from ndr.reader.base.emptyimagemetadata. Raster readers
			% (e.g. ndr.reader.prairieview) override this and fill in the fields
			% they can determine; fields that cannot be determined stay NaN.
			%
			% See also: ndr.reader.base.emptyimagemetadata,
			%   ndr.reader.prairieview/metadata, ndr.reader.base/frametimes
				m = ndr.reader.base.emptyimagemetadata();
		end % metadata()

	end; % methods

	methods (Static), % functions that don't need the object

		function m = emptyimagemetadata()
			% EMPTYIMAGEMETADATA - the standardized image-metadata struct with default (unknown) values
			%
			% M = ndr.reader.base.emptyimagemetadata()
			%
			% Returns the standardized image-acquisition metadata struct used by
			% ndr.reader.base/metadata, with every field at its "unknown"
			% default: israster=false, bidirectional=false, and NaN for each
			% timing/geometry value. A reader fills in the fields it can supply
			% and leaves the rest at these defaults, so consumers always see the
			% same field set. ALL TIME FIELDS ARE IN SECONDS.
			%
			% See also: ndr.reader.base/metadata
				m = struct('israster', false, ...
					'frame_period', NaN, ...
					'line_period', NaN, ...
					'dwell_time', NaN, ...
					'lines_per_frame', NaN, ...
					'pixels_per_line', NaN, ...
					'bidirectional', false);
		end % emptyimagemetadata()

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
					case {'text'},
						type = 'text';
					otherwise,
						error(['Type ' channeltype ' is unknown.']);
				end;
		end;
	
	end % methods (Static)
end % classdef
