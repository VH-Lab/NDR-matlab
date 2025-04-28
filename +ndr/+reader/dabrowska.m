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
        end % ndr.reader.dabrowska.dabrowska

        function filename = filenamefromepochfiles(obj, filename_array)
            %FILENAMEFROMEPOCHFILES - Return the .mat filename from a list.
            %
            %   FILENAME = FILENAMEFROMEPOCHFILES(OBJ, FILENAME_ARRAY)
            %
            %   Identifies the Dabrowska data file (expected extension '.mat')
            %   from the cell array of full path filenames FILENAME_ARRAY.
            %   Throws an error if zero or more than one matching file is found.
            %
            % See also: ndr.reader.base/filenamefromepochfiles

            arguments
                obj ndr.reader.dabrowska
                filename_array (1,:) cell
            end

            s1 = '.*\.mat\>'; % equivalent of *.ext on the command line
			[tf, ~, ~] = vlt.string.strcmp_substitution(s1,filename_array,...
                'UseSubstituteString',0);
		    
            index = find(tf);
            if numel(index) == 0
                error('No file ending with ".mat" found in the provided list for the epoch.');
            elseif numel(index) > 1
                error('More than one file ending with ".mat" found in the provided list. This format expects only one.');
            else
                filename = filename_array{index(1)};
            end

        end % ndr.reader.dabrowska.filenamefromepochfiles()

        function ec = epochclock(obj, epochstreams, epoch_select)
            %EPOCHCLOCK - return the ndr.time.clocktype objects for an epoch
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Return the clock types available for this epoch as a cell
            %   array of NDR.TIME.CLOCKTYPE objects (or sub-class members).
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %
            %   See also: NDR.TIME.CLOCKTYPE

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('Dabrowska format only supports a single epoch (epoch_select=1).');
            end

            ec = {ndr.time.clocktype('dev_local_time')};
            [filename] = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.dabrowska.header(filename);
            if isfield(header,'time')
                ec{2} = ndr.time.clocktype('exp_global_time');
            end
        end % ndr.reader.dabrowska.epochclock()

        function t0t1 = t0_t1(obj, epochstreams, epoch_select)
            %T0_T1 - Return the beginning and end epoch times for an epoch.
            %
            %  T0T1 = T0_T1(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %  Return the beginning (t0) and end (t1) times of the epoch
            %  EPOCH_NUMBER in the same units as the NDR.TIME.CLOCKTYPE
            %  objects returned by EPOCH_NUMBER.
            %
            %  See also: NDR.TIME.CLOCKTYPE, EPOCHCLOCK
            
            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end

            [filename] = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.dabrowska.header(filename);
            t0t1 = obj.get_t0_t1_from_header(header);
        end % ndr.reader.dabrowska.t0_t1()

        function channels = getchannelsepoch(obj, epochstreams, epoch_select)
            %GETCHANNELSEPOCH - List the channels available for a given epoch.
            %
            %   CHANNELS = GETCHANNELSEPOCH(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns a structure list of channels available in the epoch.
            %   Channel information (number of channels) is read from the header
            %   derived from the filename. All data channels are assumed to be
            %   'analog_in' type. A single 'time' channel is also reported.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %
            %   Output CHANNELS structure fields:
            %       'name'         : Channel name (e.g., 'ai1', 't1')
            %       'type'         : Channel type (e.g., 'analog_in', 'time')
            %       'time_channel' : Index of the associated time channel (always 1)
            %
            % See also: NDR.FORMAT.DABROWSKA.HEADER, NDR.READER.BASE/getchannelsepoch
		
            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            [filename] = obj.filenamefromepochfiles(epochstreams);
		    header = ndr.format.dabrowska.header(filename);
			
			channels = vlt.data.emptystruct('name','type','time_channel');

            % Add the time channel first
			channels(1) = struct('name','t1','type','time','time_channel',1);

            % Add analog input channels based on header info
            for i=1:header.num_channels
                channels(end+1) = struct('name', ['ai' int2str(i)], ...
                    'type', 'analog_in', 'time_channel', 1);
            end
        end % ndr.reader.dabrowska.getchannelsepoch()

        function [datatype,p,datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE - Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS,
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the underlying data type as stored in the file.
            %   For Dabrowska files, analog data and time are 'double'.
            %   The polynomial P describes scaling: P = [OFFSET SCALE].
            %   Since this reader returns double, P is [0 1].
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: ndr.reader.base/underlying_datatype

            arguments
                obj ndr.reader.dabrowksa
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('Dabrowska format only supports a single epoch (epoch_select=1).');
            end

            % No need to read header here, type is fixed by format definition

            switch(lower(channeltype))
                case {'analog_in','ai','analog_out','ao','time','t'}
                    datatype = 'double';
                    datasize = 64;
                    p = repmat([0 1], numel(channel), 1);
                otherwise
                    % Use base class implementation for other types if needed
                    [datatype,p,datasize] = underlying_datatype@ndr.reader.base(obj, epochstreams, epoch_select, channeltype, channel);
                    warning('ndr:reader:whitematter:UnknownChannelType', ...
                        'Unknown channel type "%s" requested for underlying_datatype. Using base class default.', channeltype);
            end
        end % ndr.reader.dabrowska.underlying_datatype()

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES - Read data samples for specified channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(OBJ, CHANNELTYPE, CHANNEL,
            %       EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data for the given CHANNELTYPE and CHANNEL numbers between
            %   sample S0 and sample S1 (inclusive, 1-based).
            %
            %   Uses the ndr.format.dabrowska.read function to perform the reading.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   S0, S1 are the start and end sample numbers.
            %
            %   Returns DATA matrix (Samples x Channels). For 'time' channeltype,
            %   returns a column vector of time stamps.
            %
            % See also: ndr.format.dabrowska.read, ndr.reader.base/readchannels_epochsamples

            arguments
                obj ndr.reader.dabrowska
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
                s0 (1,1) {mustBeNumeric} % Allow Inf
                s1 (1,1) {mustBeNumeric} % Allow Inf
            end

            if epoch_select ~= 1
                error('Dabrowska format only supports a single epoch (epoch_select=1).');
            end

            filename = obj.filenamefromepochfiles(epochstreams);
            data = ndr.format.dabrowska.read(filename,channeltype);

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
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: ndr.format.dabrowska.header, ndr.reader.base/samplerate

            arguments
                obj ndr.reader.dabrowska
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            fname = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.dabrowska.header(fname);

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
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %
            %   Output CHANNELSTRUCT fields:
            %       internal_type         : Type used internally ('analog_in', 'time')
            %       internal_number       : Channel number used internally (1-based index)
            %       internal_channelname  : Original channel name ('ai1', 't1')
            %       ndr_type              : Standard NDR type ('analog_in', 'time')
            %       samplerate            : Sampling rate for the channel
            %
            % See also: ndr.reader.base/daqchannels2internalchannels

            arguments
                obj ndr.reader.whitematter
                channelprefix (1,:) cell % Cell array of char row vectors
                channelnumber (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            % Get all available channels for validation and info lookup
            channels_available = obj.getchannelsepoch(epochstreams, epoch_select);

            channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
                'internal_channelname','ndr_type','samplerate');

            if numel(channelprefix) ~= numel(channelnumber)
                error('Number of channel prefixes must match number of channel numbers.');
            end

            for i=1:numel(channelnumber)
                current_prefix = lower(channelprefix{i});
                current_number = channelnumber(i);

                found = false;
                for j=1:numel(channels_available)
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
                        'Requested channel %s%d not found in epoch.', current_prefix, current_number);
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

            t0_t1 = {[t0_local t1_local],[t0_global t1_global]};
        end
	end

end % classdef