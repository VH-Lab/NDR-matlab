classdef dabrowska < ndr.reader.base
%NDR_READER_DABROWSKA - Reader class for Dabrowksa MAT files.
%
% This class reads data from Dabrowska lab .mat files.
%
% It relies on the helper function NDR.FORMAT.DABROWSKA.HEADER to parse
% filenames and NDR.FORMAT.DABROWSKA.READ to read the data.

    properties (SetAccess=protected, GetAccess=public)
        % No specific properties needed for this reader beyond the base
        % class properies.
    end

    methods

        function obj = dabrowska()
            %DABROWSKA - Create a new NDR reader object for Dabrowska format.
            %
            %   OBJ = ndr.reader.dabrowska()
            %
            %   Creates a Neuroscience Data Reader object for the Dabrowska
            %   lab mat file format.
            %
            % See also: ndr.reader.base
        end % ndr.reader.dabrowska.dabrowska()

        function filename = filenamefromepochfiles(obj, epochstreams, epoch_select)
            %FILENAMEFROMEPOCHFILES - Return the .mat filename from a list.
            %
            %   FILENAME = FILENAMEFROMEPOCHFILES(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Identifies the Dabrowska data files (extension '.mat')
            %   from the cell array of full path filenames EPOCHSTREAMS.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end
    
            s1 = '.*\.mat\>'; % equivalent of *.ext on the command line
			[tf, ~, ~] = vlt.string.strcmp_substitution(s1,epochstreams,...
                'UseSubstituteString',0);
            index = find(tf);
            if numel(index) == 0
                error('No file ending with ".mat" found in the provided list for the epoch.');
            elseif numel(index) < epoch_select
                error('There are only %i ".mat" files found in the provided list. epoch_select cannot be %i.',...
                    numel(index),epoch_select);
            end
            filename = epochstreams{index(epoch_select)};

        end % ndr.reader.dabrowska.filenamefromepochfiles()

        function ec = epochclock(obj, epochstreams, epoch_select)
            %EPOCHCLOCK - Return the ndr.time.clocktype objects for an epoch
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Return the clock types available for this epoch as a cell
            %   array of NDR.TIME.CLOCKTYPE objects (or sub-class members).
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %
            % See also: NDR.TIME.CLOCKTYPE

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            ec = {ndr.time.clocktype('dev_local_time')};
            [filename] = obj.filenamefromepochfiles(epochstreams,epoch_select);
            header = ndr.format.dabrowska.header(filename);
            if isfield(header,'time')
                ec{2} = ndr.time.clocktype('exp_global_time');
            end

        end % ndr.reader.dabrowska.epochclock()

        function t0t1 = t0_t1(obj, epochstreams, epoch_select)
            %T0_T1 - Return the beginning and end epoch times for an epoch.
            %
            %   T0T1 = T0_T1(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Return the beginning (t0) and end (t1) times of the epoch
            %   EPOCH_SELECT in the same units as the NDR.TIME.CLOCKTYPE
            %   objects returned by EPOCH_SELECT.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %
            % See also: NDR.TIME.CLOCKTYPE, EPOCHCLOCK
            
            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            [filename] = obj.filenamefromepochfiles(epochstreams,epoch_select);
            header = ndr.format.dabrowska.header(filename);
            if ~isfield(header, 'triggerTime') || ~isfield(header,'duration')
                error('Header is missing required fields to compute t0 and t1.');
            end
            t0t1 = obj.get_t0_t1_from_header(header);

        end % ndr.reader.dabrowska.t0_t1()

        function channels = getchannelsepoch(obj, epochstreams, epoch_select)
            %GETCHANNELSEPOCH - List the channels available for a given epoch.
            %
            %   CHANNELS = GETCHANNELSEPOCH(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns a structure list of channels available in the epoch.
            %   Channels are assumed to be of type 'time', 'analog_in', and
            %   'analog_out' with only a single of each type per epoch.
            %   Channels are verified by reading variable names in the
            %   associated ".mat" file.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %
            %   Output CHANNELS structure fields:
            %       'name'         : Channel name (i.e. 't1', 'ai1', 'ao1')
            %       'type'         : Channel type (i.e., 'time', 'analog_in', 'analog_out')
            %       'time_channel' : Index of the associated time channel (always 1)
            %
            % See also: NDR.FORMAT.DABROWSKA.HEADER
		
            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end
			
            [filename] = obj.filenamefromepochfiles(epochstreams,epoch_select);
            varNames = who('-file', filename);

			channels = vlt.data.emptystruct('name','type','time_channel');

            % Add the time first then analog input and output channels
			channels(1) = struct('name','t1','type','time','time_channel',1);
            if ismember('inputData',varNames)
                channels(end+1) = struct('name','ai1','type','analog_in','time_channel',1);
            end
            if ismember('outputData',varNames)
                channels(end+1) = struct('name','ao1','type','analog_out','time_channel',1);
            end

        end % ndr.reader.dabrowska.getchannelsepoch()

        function [datatype,p,datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE - Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS,
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the underlying data type. For Dabrowska files, 
            %   analog data and time are 'double'.The polynomial P 
            %   describes scaling: P = [OFFSET SCALE]. Since this reader 
            %   returns double, P is always [0 1].
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in','analog_out','time').
            %   CHANNEL is a vector of channel numbers.
            %
            % See also: NDR.READER.BASE/underlying_datatype

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                channeltype (1,:) char {mustBeNonempty} = 'analog_in'
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = 1
            end

            % No need to read header, type is fixed
            switch lower(channeltype)
                case {'analog_in','ai','analog_out','ao','time','t'}
                    datatype = 'double';
                    datasize = 64;
                    p = repmat([0 1], numel(channel), 1);
                otherwise
                    % Use base class implementation for other types if needed
                    [datatype,p,datasize] = underlying_datatype@ndr.reader.base(obj, epochstreams, epoch_select, channeltype, channel);
                    warning('ndr:reader:dabrowska:UnknownChannelType', ...
                        'Unknown channel type "%s" requested for underlying_datatype. Using base class default.', channeltype);
            end
        end % ndr.reader.dabrowska.underlying_datatype()

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES - Read data samples for specified channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(OBJ, CHANNELTYPE, CHANNEL,
            %       EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data for the given CHANNELTYPE and CHANNEL numbers 
            %   between sample S0 and sample S1 (inclusive, 1-based).
            %
            %   Uses the NDR.FORMAT.DABROWSKA.READ function.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in','analog_out','time').
            %   CHANNEL is a vector of channel numbers.
            %   S0, S1 are the start and end sample numbers.
            %
            %   Returns a column vector (Samples x 1) of time stamps or 
            %   data values.
            %
            % See also: NDR.FORMAT.DABROWSKA.READ, NDR.READER.BASE/readchannels_epochsamples

            arguments
                obj ndr.reader.dabrowska
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                s0 (1,1) {mustBeNumeric} = -Inf % Allow Inf
                s1 (1,1) {mustBeNumeric} = Inf % Allow Inf
            end

            % Read data
            filename = obj.filenamefromepochfiles(epochstreams,epoch_select);
            data = ndr.format.dabrowska.read(filename,channeltype);
            
            % Get data between samples
            if isinf(s0)
                s0 = 1;
            elseif s0 < 1
                s0 = 1;
                warning('Starting sample number must be a positive integer. Using default value (s0 = %i).',s0)
            elseif s0 ~= round(s0)
                s0 = round(s0);
                warning('Starting sample number must be an integer. Using closest integer value (s0 = %i).',s0)
            end
            if isinf(s1)
                s1 = numel(data);
            elseif s1 < 1
                error('Ending sample number must be a positive integer.')
            elseif s1 ~= round(s1)
                s1 = round(s1);
                warning('Ending sample number must be an integer. Using closest integer value (s1 = %i).',s1)
            elseif s1 > numel(data)
                s1 = numel(data);
                warning('Ending sample number is greater than the length of the data. Using last sample point (s1 = %i).',s1)
            end
            data = data(s0:s1);

        end % ndr.dabrowska.readchannels_epochsamples()

        function sr = samplerate(obj, epochstreams, epoch_select, channeltype, channel)
            %SAMPLERATE - Get the sample rate for specific channels.
            %
            %   SR = SAMPLERATE(OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the sampling rate in Hz for the specified channels.
            %   For Dabrowska files, the sampling rate is constant across all
            %   analog channels and is read from the header (filename).
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: NDR.FORMAT.DABROWSKA.HEADER, NDR.READER.BASE/samplerate

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                channeltype (1,:) char {mustBeNonempty} = 'analog_in'
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = 1
            end

            filename = obj.filenamefromepochfiles(epochstreams,epoch_select);
            header = ndr.format.dabrowska.header(filename);

            % Sampling rate is the same for all analog channels and time
            sr = repmat(header.sampleRate, size(channel));

        end % ndr.reader.dabrowska.samplerate()

        function channelstruct = daqchannels2internalchannels(obj, channelprefix, channelnumber, epochstreams, epoch_select)
            %DAQCHANNELS2INTERNALCHANNELS - Convert public channel info to internal representation.
            %
            %   CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(OBJ, CHANNELPREFIX,
            %       CHANNELNUMBER, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Converts requested DAQ channels (e.g., prefix 'ai', numbers [1 5 10])
            %   into the internal structure format needed by readchannels_epochsamples.
            %   For this reader, the internal representation is straightforward as
            %   channels are simply referenced by their 1-based index.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELPREFIX is the type ('ai', 'ao', or 't').
            %   CHANNEL is a vector of channel numbers.
            %
            %   Output CHANNELSTRUCT fields:
            %       internal_type         : Type used internally ('analog_in','analog_out','time')
            %       internal_number       : Channel number used internally (1-based index)
            %       internal_channelname  : Original channel name ('ai1','ao1','t1')
            %       ndr_type              : Standard NDR type ('analog_in','analog_out','time')
            %       samplerate            : Sampling rate for the channel in Hz
            %
            % See also: NDR.READER.BASE/daqchannels2internalchannels,
            %   NDR.STRING.CHANNELSTRING2CHANNELS, 
            %   NDR.READER.BASE.MFDAQ_TYPE, samplerate

            arguments
                obj ndr.reader.dabrowska
                channelprefix (1,:) cell % Cell array of char row vectors
                channelnumber (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            % Get all available channels for validation and info lookup
            channels_available = obj.getchannelsepoch(epochstreams,epoch_select);

            channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
                'internal_channelname','ndr_type','samplerate');

            if numel(channelprefix) ~= numel(channelnumber)
                error('Number of channel prefixes must match number of channel numbers.');
            end

            for i=1:numel(channelnumber)
                current_prefix = lower(channelprefix{i});
                current_number = channelnumber(i);

                found = false;
                for j = 1:numel(channels_available)
                    
                    % Check if the available channel matches the request
                    [avail_prefix, avail_number] = ndr.string.channelstring2channels(channels_available(j).name);

                    if strcmpi(current_prefix, avail_prefix{1}) && current_number == avail_number(1)
                        % Match found
                        newentry.internal_channelname = channels_available(j).name;
                        newentry.internal_type = channels_available(j).type; % Use the type determined by getchannelsepoch
                        newentry.internal_number = current_number; % Internal number is the public number for this reader
                        newentry.ndr_type = ndr.reader.base.mfdaq_type(newentry.internal_type); % Standardize type
                        newentry.samplerate = obj.samplerate(epochstreams, epoch_select, current_prefix, current_number);

                        channelstruct(end+1) = newentry;
                        found = true;
                        break; % Move to the next requested channel
                    end
                end % loop over available channels

                if ~found
                    warning('ndr:reader:dabrowska:ChannelNotFound', ...
                        'Requested channel %s%d not found in epoch.', ...
                        current_prefix, current_number);
                end
            end % loop over requested channels

        end % ndr.reader.dabrowska.daqchannels2internalchannels()

    end % methods

    methods (Static, Access = private)
		function t0_t1 = get_t0_t1_from_header(header)

            % Get global t0 and t1 time of each step and entire epoch
            t0_global_steps = datetime(header.triggerTime,'convertFrom','datenum')';
            t1_global_steps = t0_global_steps + milliseconds(header.duration);
            t0_global = min(t0_global_steps);
            t1_global = max(t1_global_steps);

            % Get local t0 and t1 time of each step and entire epoch
            t0_local_steps = seconds(t0_global_steps - t0_global);
            t1_local_steps = seconds(t1_global_steps - t0_global);
            t0_local = min(t0_local_steps);
            t1_local = max(t1_local_steps);
            
            % Return local and global times (converted back to datenum)
            t0_t1 = {[t0_local t1_local],...
                convertTo([t0_global t1_global],'datenum')};
        end
	end

end % classdef