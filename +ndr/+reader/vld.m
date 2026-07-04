classdef vld < ndr.reader.base
%NDR.READER.VLD - Reader class for VH Lab LabView (.vld/.vlh) files.
%
% This class reads data from the VHLAB LabView multichannel acquisition
% system binary format. Each recording epoch is described by a text header
% file (extension '.vlh') and a binary data file (extension '.vld').
%
% It relies on the helper functions NDR.FORMAT.VLD.READVHLVHEADERFILE to
% parse the header and NDR.FORMAT.VLD.READVHLVDATAFILE to read the data.
%
% All acquired channels are analog input channels ('ai1', 'ai2', ...,
% numbered in the order they were acquired in LabView) that share a single
% sampling rate and a single time channel ('t1').
%
% See also: ndr.reader.base, ndr.format.vld.readvhlvheaderfile,
%   ndr.format.vld.readvhlvdatafile

    properties (SetAccess=protected, GetAccess=public)
        % No specific properties needed beyond the base class properties.
    end

    methods

        function obj = vld()
            %VLD - Create a new NDR reader object for the VH Lab LabView format.
            %
            %   OBJ = ndr.reader.vld()
            %
            %   Creates a Neuroscience Data Reader object for the VHLAB
            %   LabView multichannel acquisition (.vld/.vlh) file format.
            %
            % See also: ndr.reader.base
        end % ndr.reader.vld.vld()

        function filename = filenamefromepochfiles(obj, epochstreams, epoch_select)
            %FILENAMEFROMEPOCHFILES - Return the .vld data filename from a list.
            %
            %   FILENAME = FILENAMEFROMEPOCHFILES(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Identifies the VH Lab LabView data file (extension '.vld')
            %   from the cell array of full path filenames EPOCHSTREAMS.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            s1 = '.*\.vld\>'; % equivalent of *.vld on the command line
            [tf, ~, ~] = vlt.string.strcmp_substitution(s1,epochstreams,...
                'UseSubstituteString',0);
            index = find(tf);
            if numel(index) == 0
                error('No file ending with ".vld" found in the provided list for the epoch.');
            elseif numel(index) < epoch_select
                error('There are only %i ".vld" files found in the provided list. epoch_select cannot be %i.',...
                    numel(index),epoch_select);
            end
            filename = epochstreams{index(epoch_select)};

        end % ndr.reader.vld.filenamefromepochfiles()

        function header = readheader(obj, epochstreams, epoch_select)
            %READHEADER - Read the VHLV header structure for an epoch.
            %
            %   HEADER = READHEADER(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Locates the '.vld' data file for the epoch, derives the
            %   matching '.vlh' header file (same path and base name), and
            %   returns the parsed header structure.
            %
            % See also: ndr.format.vld.readvhlvheaderfile

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            filename = obj.filenamefromepochfiles(epochstreams,epoch_select);
            [mypath,myname,~] = fileparts(filename);
            headerfile = fullfile(mypath,[myname '.vlh']);
            header = ndr.format.vld.readvhlvheaderfile(headerfile);

        end % ndr.reader.vld.readheader()

        function ec = epochclock(obj, epochstreams, epoch_select)
            %EPOCHCLOCK - Return the ndr.time.clocktype objects for an epoch
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Return the clock types available for this epoch as a cell
            %   array of NDR.TIME.CLOCKTYPE objects. VHLV files record time
            %   relative to the beginning of the recording, so a single
            %   'dev_local_time' clock is returned.
            %
            % See also: NDR.TIME.CLOCKTYPE

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            ec = {ndr.time.clocktype('dev_local_time')};

        end % ndr.reader.vld.epochclock()

        function t0t1 = t0_t1(obj, epochstreams, epoch_select)
            %T0_T1 - Return the beginning and end epoch times for an epoch.
            %
            %   T0T1 = T0_T1(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Return the beginning (t0) and end (t1) times of the epoch
            %   EPOCH_SELECT in the same units as the NDR.TIME.CLOCKTYPE
            %   objects returned by EPOCHCLOCK. Sample 1 occurs at t==0, so
            %   t0 is 0 and t1 is (total_samples-1)/SamplingRate.
            %
            % See also: NDR.TIME.CLOCKTYPE, EPOCHCLOCK

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            filename = obj.filenamefromepochfiles(epochstreams,epoch_select);
            header = obj.readheader(epochstreams,epoch_select);
            tot_sam = ndr.reader.vld.total_samples(header,filename);
            t0 = 0;
            t1 = (tot_sam-1)/header.SamplingRate;
            t0t1 = {[t0 t1]};

        end % ndr.reader.vld.t0_t1()

        function channels = getchannelsepoch(obj, epochstreams, epoch_select)
            %GETCHANNELSEPOCH - List the channels available for a given epoch.
            %
            %   CHANNELS = GETCHANNELSEPOCH(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns a structure list of channels available in the epoch.
            %   VHLV files store one or more analog input channels ('ai1',
            %   'ai2', ...) that share a single time channel ('t1'). The
            %   number of analog inputs is read from the 'NumChans' field of
            %   the header.
            %
            %   Output CHANNELS structure fields:
            %       'name'         : Channel name (i.e. 't1', 'ai1', 'ai2')
            %       'type'         : Channel type ('time', 'analog_in')
            %       'time_channel' : Index of the associated time channel (always 1)
            %
            % See also: NDR.FORMAT.VLD.READVHLVHEADERFILE

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

            header = obj.readheader(epochstreams,epoch_select);

            channels = vlt.data.emptystruct('name','type','time_channel');

            % Add the time channel first, then the analog input channels
            channels(1) = struct('name','t1','type','time','time_channel',1);
            for i=1:header.NumChans
                channels(end+1) = struct('name',['ai' int2str(i)],...
                    'type','analog_in','time_channel',1);
            end

        end % ndr.reader.vld.getchannelsepoch()

        function [datatype,p,datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE - Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS,
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the underlying stored data type for the requested
            %   channels. VHLV analog data are stored using the 'precision'
            %   field of the header ('double','single','int16','int32'); if a
            %   'Scale' field is present, the stored integers are scaled by
            %   SCALE/MAXINT to produce physical units, and this is reflected
            %   in the polynomial P = [OFFSET SCALE]. Time is 'double'.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in','time').
            %   CHANNEL is a vector of channel numbers.
            %
            % See also: NDR.READER.BASE/underlying_datatype

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                channeltype (1,:) char {mustBeNonempty} = 'analog_in'
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = 1
            end

            switch lower(channeltype)
                case {'time','t'}
                    datatype = 'float64';
                    datasize = 64;
                    p = repmat([0 1], numel(channel), 1);
                case {'analog_in','ai'}
                    header = obj.readheader(epochstreams,epoch_select);
                    [datatype,datasize,maxint] = ndr.reader.vld.precision2datatype(header);
                    if isfield(header,'Scale')
                        scale = header.Scale/maxint;
                    else
                        scale = 1;
                    end
                    p = repmat([0 scale], numel(channel), 1);
                otherwise
                    [datatype,p,datasize] = underlying_datatype@ndr.reader.base(obj, epochstreams, epoch_select, channeltype, channel);
                    warning('ndr:reader:vld:UnknownChannelType', ...
                        'Unknown channel type "%s" requested for underlying_datatype. Using base class default.', channeltype);
            end

        end % ndr.reader.vld.underlying_datatype()

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES - Read data samples for specified channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(OBJ, CHANNELTYPE, CHANNEL,
            %       EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data for the given CHANNELTYPE and CHANNEL numbers
            %   between sample S0 and sample S1 (inclusive, 1-based).
            %
            %   Uses the NDR.FORMAT.VLD.READVHLVDATAFILE function. DATA has
            %   one column per requested channel. For a 'time' channel type,
            %   DATA is the time (in seconds relative to the start of the
            %   recording) of each sample.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in','time').
            %   CHANNEL is a vector of channel numbers.
            %   S0, S1 are the start and end sample numbers.
            %
            % See also: NDR.FORMAT.VLD.READVHLVDATAFILE

            arguments
                obj ndr.reader.vld
                channeltype (1,:) % char or cell array of char
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                s0 (1,1) {mustBeNumeric} = -Inf
                s1 (1,1) {mustBeNumeric} = Inf
            end

            if iscell(channeltype)
                assert(all(strcmp(channeltype,channeltype{1})), ...
                    'ndr:reader:vld:readchannels_epochsamples:HeterogeneousChannelTypes', ...
                    'channeltype cell array must be uniform; the vld reader reads one type per call.');
                channeltype = channeltype{1};
            end

            filename = obj.filenamefromepochfiles(epochstreams,epoch_select);
            header = obj.readheader(epochstreams,epoch_select);
            sr = header.SamplingRate;
            tot_sam = ndr.reader.vld.total_samples(header,filename);

            % Resolve sample bounds; sample 1 occurs at t==0
            if isinf(s0)
                s0 = 1;
            elseif s0 < 1
                warning('Starting sample number must be a positive integer. Using default value (s0 = 1).');
                s0 = 1;
            elseif s0 ~= round(s0)
                s0 = round(s0);
                warning('Starting sample number must be an integer. Using closest integer value (s0 = %i).',s0);
            end
            if isinf(s1)
                s1 = tot_sam;
            elseif s1 < 1
                error('Ending sample number must be a positive integer.');
            elseif s1 ~= round(s1)
                s1 = round(s1);
                warning('Ending sample number must be an integer. Using closest integer value (s1 = %i).',s1);
            end
            if s1 > tot_sam
                warning('Ending sample number is greater than the length of the data. Using last sample (s1 = %i).',tot_sam);
                s1 = tot_sam;
            end

            t0 = (s0-1)/sr;
            t1 = (s1-1)/sr;

            if any(strcmpi(channeltype,{'time','t'}))
                % Return the timestamps for the requested samples
                [T,~] = ndr.format.vld.readvhlvdatafile(filename,header,1,t0,t1);
                data = repmat(T(:),1,numel(channel));
            else
                [~,D] = ndr.format.vld.readvhlvdatafile(filename,header,channel,t0,t1);
                data = D;
            end

        end % ndr.reader.vld.readchannels_epochsamples()

        function sr = samplerate(obj, epochstreams, epoch_select, channeltype, channel)
            %SAMPLERATE - Get the sample rate for specific channels.
            %
            %   SR = SAMPLERATE(OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the sampling rate in Hz for the specified channels.
            %   For VHLV files, the sampling rate is constant across all
            %   channels (analog inputs and time) and is read from the header.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELTYPE is the type ('analog_in', 'time', etc.).
            %   CHANNEL is the vector of channel numbers.
            %
            % See also: NDR.FORMAT.VLD.READVHLVHEADERFILE, NDR.READER.BASE/samplerate

            arguments
                obj ndr.reader.vld
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
                channeltype (1,:) char {mustBeNonempty} = 'analog_in'
                channel (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = 1
            end

            header = obj.readheader(epochstreams,epoch_select);
            sr = repmat(header.SamplingRate, size(channel));

        end % ndr.reader.vld.samplerate()

        function channelstruct = daqchannels2internalchannels(obj, channelprefix, channelnumber, epochstreams, epoch_select)
            %DAQCHANNELS2INTERNALCHANNELS - Convert public channel info to internal representation.
            %
            %   CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(OBJ, CHANNELPREFIX,
            %       CHANNELNUMBER, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Converts requested DAQ channels (e.g., prefix 'ai', numbers
            %   [1 5 10]) into the internal structure format needed by
            %   readchannels_epochsamples. For this reader the internal
            %   representation is straightforward: channels are referenced by
            %   their 1-based acquisition index.
            %
            %   EPOCHSTREAMS is a cell array of filenames for the epoch.
            %   EPOCH_SELECT is the epoch number (default = 1).
            %   CHANNELPREFIX is a cell array of prefixes ('ai' or 't').
            %   CHANNELNUMBER is a vector of channel numbers.
            %
            %   Output CHANNELSTRUCT fields:
            %       internal_type         : Type used internally ('analog_in','time')
            %       internal_number       : Channel number used internally (1-based index)
            %       internal_channelname  : Original channel name ('ai1','t1')
            %       ndr_type              : Standard NDR type ('analog_in','time')
            %       samplerate            : Sampling rate for the channel in Hz
            %
            % See also: NDR.READER.BASE/daqchannels2internalchannels

            arguments
                obj ndr.reader.vld
                channelprefix (1,:) cell % Cell array of char row vectors
                channelnumber (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
                epochstreams (1,:) cell
                epoch_select (1,1) {mustBePositive, mustBeInteger} = 1
            end

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
                    [avail_prefix, avail_number] = ndr.string.channelstring2channels(channels_available(j).name);
                    if strcmpi(current_prefix, avail_prefix{1}) && current_number == avail_number(1)
                        newentry.internal_channelname = channels_available(j).name;
                        newentry.internal_type = channels_available(j).type;
                        newentry.internal_number = current_number;
                        newentry.ndr_type = ndr.reader.base.mfdaq_type(newentry.internal_type);
                        newentry.samplerate = obj.samplerate(epochstreams, epoch_select, current_prefix, current_number);
                        channelstruct(end+1) = newentry;
                        found = true;
                        break;
                    end
                end % loop over available channels

                if ~found
                    warning('ndr:reader:vld:ChannelNotFound', ...
                        'Requested channel %s%d not found in epoch.', ...
                        current_prefix, current_number);
                end
            end % loop over requested channels

        end % ndr.reader.vld.daqchannels2internalchannels()

    end % methods

    methods (Static, Access = private)

        function [datatype,datasize,maxint] = precision2datatype(header)
            % PRECISION2DATATYPE - Map a VHLV header precision to fread datatype info
            %
            %   [DATATYPE,DATASIZE,MAXINT] = precision2datatype(HEADER)
            %
            %   Returns the FREAD/FWRITE datatype string, the sample size in
            %   bits, and the maximum integer value used for scaling, based on
            %   the 'precision' field of the header (default 'double').
            if isfield(header,'precision')
                precision = header.precision;
            else
                precision = 'double';
            end
            switch precision
                case 'double'
                    datatype = 'float64'; datasize = 64; maxint = 1;
                case 'single'
                    datatype = 'float32'; datasize = 32; maxint = 1;
                case 'int32'
                    datatype = 'int32'; datasize = 32; maxint = 2^31-1;
                case 'int16'
                    datatype = 'int16'; datasize = 16; maxint = 2^15-1;
                otherwise
                    error(['Unknown precision ' precision ' in VHLV header.']);
            end
        end % precision2datatype()

        function tot_sam = total_samples(header, filename)
            % TOTAL_SAMPLES - Estimate the total number of samples per channel
            %
            %   TOT_SAM = total_samples(HEADER, FILENAME)
            %
            %   Estimates the number of samples per channel in the '.vld'
            %   file FILENAME from the file size, the number of channels, and
            %   the stored sample size.
            [~,datasize,~] = ndr.reader.vld.precision2datatype(header);
            unit_size = datasize/8;
            d = dir(filename);
            if isempty(d)
                error(['Could not find file ' filename ' to determine its size.']);
            end
            tot_sam = d.bytes/(header.NumChans*unit_size);
        end % total_samples()

    end % methods (Static, Access = private)

end % classdef
