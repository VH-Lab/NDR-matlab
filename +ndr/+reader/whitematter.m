classdef whitematter < ndr.reader.base
%NDR_READER_WHITEMATTER - Reader class for WhiteMatter LLC (WM) binary files.
%
% This class reads data from WhiteMatter LLC .bin files where metadata is
% embedded in the filename. It assumes an 8-byte header followed by
% interleaved int16 data samples.
%
% It relies on the helper function ndr.format.whitematter.header to parse
% filenames and whitematter.read (or ndr.format.binarymatrix.read) to
% read the data.
%

    properties (SetAccess=protected, GetAccess=public)
        % No specific properties needed for this reader beyond the base class
    end % properties

    methods

        function obj = whitematter()
            %WHITEMATTER - Create a new NDR reader object for WhiteMatter LLC format.
            %
            %   OBJ = ndr.reader.whitematter()
            %
            %   Creates a Neuroscience Data Reader object for the WhiteMatter LLC
            %   binary file format.
            %
            % See also: ndr.reader.base
        end % whitematter() constructor

        function ec = epochclock(obj, epochstreams, epoch_select)
            %EPOCHCLOCK - Return the ndr.time.clocktype objects for an epoch.
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns the clock types available for this epoch. For WhiteMatter
            %   files, this is assumed to be only 'dev_local_time', as the
            %   absolute time reference is derived from the filename, not embedded
            %   timing signals within the data stream relative to an external clock.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %
            % See also: ndr.time.clocktype, ndr.reader.base/epochclock

            arguments
                obj ndr.reader.whitematter
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end
            
            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end
            
            % WhiteMatter files only have local time relative to the file start
            ec = {ndr.time.clocktype('dev_local_time')}; 
            
            % Although the absolute start time is in the filename header, 
            % the internal timing is relative to the start of the file (t=0).
            % If absolute time is needed, it should be managed at a higher level 
            % using the header information.
            
        end % epochclock()

        function t0t1 = t0_t1(obj, epochstreams, epoch_select)
            %T0_T1 - Return the beginning and end epoch times for an epoch.
            %
            %   T0T1 = T0_T1(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns the beginning (t0) and end (t1) times of the epoch
            %   in seconds, relative to the start of the recording (t0=0).
            %   The end time is determined from the file size and header info.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %
            % See also: ndr.format.whitematter.header, ndr.reader.base/t0_t1

            arguments
                obj ndr.reader.whitematter
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end
            
            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            fname = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.whitematter.header(fname); % Read header from filename

            % Calculate t0 and t1 based on file properties derived from header
            bytesPerSampleValue = 2; % int16
            headerSkipBytes = 8;
            bytesPerFullSample = bytesPerSampleValue * header.num_channels;

            fileinfo = dir(fname);
            totalDataBytes = fileinfo.bytes - headerSkipBytes;
            if totalDataBytes < 0, totalDataBytes = 0; end % Handle empty file case
            
            totalSamplesInFile = floor(totalDataBytes / bytesPerFullSample);
            
            t_start = 0; 
            % Use dummy t0_t1 for duration calculation
            t_end = ndr.time.fun.samples2times(totalSamplesInFile, [0 0], header.sampling_rate); 
            
            t0t1 = {[t_start t_end]}; % Return as cell array { [t0 t1] }
            
        end % t0_t1()

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
            % See also: ndr.format.whitematter.header, ndr.reader.base/getchannelsepoch

            arguments
                obj ndr.reader.whitematter
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            fname = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.whitematter.header(fname);

            channels = vlt.data.emptystruct('name','type','time_channel');

            % Add the time channel first
            channels(1) = struct('name','t1','type','time','time_channel',1);

            % Add analog input channels based on header info
            for i=1:header.num_channels
                channels(end+1) = struct('name', ['ai' int2str(i)], ...
                                         'type', 'analog_in', ...
                                         'time_channel', 1);
            end
        end % getchannelsepoch()

        function [datatype,p,datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE - Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS, 
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the underlying data type as stored in the file.
            %   For WhiteMatter files, analog data is 'int16'. Time is 'double'.
            %   The polynomial P describes scaling: P=[OFFSET SCALE]. Since this
            %   reader returns raw int16, P is [0 1].
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: ndr.reader.base/underlying_datatype

             arguments
                obj ndr.reader.whitematter
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} 
             end
             
             if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
             end

             % No need to read header here, type is fixed by format definition
             
             switch(lower(channeltype))
                 case {'analog_in','ai'}
                     datatype = 'int16';
                     datasize = 16;
                     % Return raw data, so offset 0, scale 1
                     p = repmat([0 1], numel(channel), 1); 
                 case {'time','t'}
                     % Time is calculated, not read directly as a native type, 
                     % but returned as double
                     datatype = 'double'; 
                     datasize = 64;
                     p = repmat([0 1], numel(channel), 1);
                 otherwise
                     % Use base class implementation for other types if needed
                     [datatype,p,datasize] = underlying_datatype@ndr.reader.base(obj, epochstreams, epoch_select, channeltype, channel);
                     warning('ndr:reader:whitematter:UnknownChannelType', ...
                             'Unknown channel type "%s" requested for underlying_datatype. Using base class default.', channeltype);
             end
        end % underlying_datatype()

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES - Read data samples for specified channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(OBJ, CHANNELTYPE, CHANNEL, 
            %       EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data for the given CHANNELTYPE and CHANNEL numbers between
            %   sample S0 and sample S1 (inclusive, 1-based).
            %
            %   Uses the ndr.format.whitematter.read function to perform the reading.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   S0, S1 are the start and end sample numbers.
            %
            %   Returns DATA matrix (Samples x Channels). For 'time' channeltype,
            %   returns a column vector of time stamps.
            %
            % See also: ndr.format.whitematter.read, ndr.reader.base/readchannels_epochsamples

            arguments
                obj ndr.reader.whitematter
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger}
                s0 (1,1) {mustBeNumeric} % Allow Inf
                s1 (1,1) {mustBeNumeric} % Allow Inf
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            fname = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.whitematter.header(fname); % Need header for SR, numChans

            % Get the full time range of the file
            t0t1_file = obj.t0_t1(epochstreams, epoch_select);
            
            % Convert sample numbers to times for whitematter.read
            % Handle Inf cases for s0/s1
            if isinf(s0) && s0 < 0
                t0_read = t0t1_file{1}(1); % Start time of file
            else
                t0_read = ndr.time.fun.samples2times(s0, t0t1_file{1}, header.sampling_rate);
            end
            
            if isinf(s1) && s1 > 0
                t1_read = t0t1_file{1}(2); % End time of file
            else
                t1_read = ndr.time.fun.samples2times(s1, t0t1_file{1}, header.sampling_rate);
            end

            % Ensure times are within file bounds after conversion
            t0_read = max(t0_read, t0t1_file{1}(1));
            t1_read = min(t1_read, t0t1_file{1}(2));
            
            if t1_read < t0_read
                data = []; % Return empty if time range is invalid
                if strcmpi(channeltype,'time')
                   data = double(data); % Match expected time type
                else
                   data = int16(data); % Match expected data type
                end
                return;
            end

            % Call whitematter.read
            if strcmpi(channeltype, 'time')
                % Need to read at least one data channel to get the time vector
                if isempty(channel) || ~any(channel >= 1 & channel <= header.num_channels)
                     % Check if *any* requested channel is valid
                     valid_channels = channel(channel >= 1 & channel <= header.num_channels);
                     if isempty(valid_channels)
                         read_channel_for_time = 1; % Default to channel 1 if no valid channels provided
                     else
                         read_channel_for_time = valid_channels(1); % Use the first valid channel
                     end
                else
                    read_channel_for_time = channel(1); % Use first valid channel provided
                end

                 % Read only the requested channel to get the time vector
                [~, data] = ndr.format.whitematter.read(fname, t0_read, t1_read, ...
                                    'numChans', header.num_channels, ...
                                    'SR', header.sampling_rate, ...
                                    'channels', read_channel_for_time); 
                 data = data(:); % Ensure time is a column vector
            elseif strcmpi(channeltype, 'analog_in') || strcmpi(channeltype, 'ai')
                % Read the specified analog channels
                [data, ~] = ndr.format.whitematter.read(fname, t0_read, t1_read, ...
                                    'numChans', header.num_channels, ...
                                    'SR', header.sampling_rate, ...
                                    'channels', channel); 
            else
                error('Unknown channel type "%s" requested.', channeltype);
            end

        end % readchannels_epochsamples()

        function sr = samplerate(ndr_reader_wm_obj, epochstreams, epoch_select, channeltype, channel)
            %SAMPLERATE - Get the sample rate for specific channels.
            %
            %   SR = SAMPLERATE(OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the sampling rate in Hz for the specified channels.
            %   For WhiteMatter files, the sampling rate is constant across all 
            %   analog channels and is read from the header (filename).
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (must be 1 for this format).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: ndr.format.whitematter.header, ndr.reader.base/samplerate

            arguments
                ndr_reader_wm_obj ndr.reader.whitematter
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} 
                channeltype (1,:) char {mustBeNonempty}
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
            end

            if epoch_select ~= 1
                error('WhiteMatter format only supports a single epoch (epoch_select=1).');
            end

            fname = ndr_reader_wm_obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.whitematter.header(fname);

            % Sampling rate is the same for all analog channels and time
            sr = repmat(header.sampling_rate, size(channel));

        end % samplerate()

        function fname = filenamefromepochfiles(obj, filename_array)
            %FILENAMEFROMEPOCHFILES - Return the .bin filename from a list.
            %
            %   FILENAME = FILENAMEFROMEPOCHFILES(OBJ, FILENAME_ARRAY)
            %
            %   Identifies the WhiteMatter LLC data file (expected extension '.bin'
            %   and starting with 'HSW', case-insensitive) from the cell array 
            %   of full path filenames FILENAME_ARRAY.
            %   Throws an error if zero or more than one matching file is found.
            %
            % See also: ndr.reader.base/filenamefromepochfiles

            arguments
                obj ndr.reader.whitematter
                filename_array (1,:) cell
            end
            
            fname = '';
            count = 0;
            for i=1:numel(filename_array)
                [~,name_part,ext] = fileparts(filename_array{i});
                % Check both extension and prefix (case-insensitive)
                if strcmpi(ext, '.bin') && startsWith(name_part, 'HSW', 'IgnoreCase', true)
                    fname = filename_array{i};
                    count = count + 1;
                end
            end

            if count == 0
                error('No file starting with "HSW" and ending with ".bin" found in the provided list for the epoch.');
            elseif count > 1
                error('More than one file starting with "HSW" and ending with ".bin" found in the provided list. This format expects only one.');
            end
        end % filenamefromepochfiles()

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
            
            % Get header info for samplerate and num_channels validation
            fname = obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.whitematter.header(fname);
            
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
                    warning('ndr:reader:whitematter:ChannelNotFound', ...
                            'Requested channel %s%d not found in epoch.', current_prefix, current_number);
                end
            end % loop over requested channels

        end % daqchannels2internalchannels()

    end % methods

end % classdef

