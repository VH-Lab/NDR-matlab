classdef neuropixelsGLX < ndr.reader.base
%NDR.READER.NEUROPIXELSGLX - Reader class for Neuropixels SpikeGLX AP-band data.
%
%   This class reads action-potential band data from Neuropixels probes
%   acquired with the SpikeGLX software. Each instance handles one probe's
%   AP stream (one .ap.bin / .ap.meta file pair per epoch).
%
%   SpikeGLX saves Neuropixels data as flat interleaved int16 binary files
%   with companion .meta text files. The binary files have no header.
%   Channel count, sample rate, and gain information are read from the
%   .meta file.
%
%   Channel mapping:
%     - Neural channels are exposed as 'analog_in' (ai1..aiN)
%     - The sync word is exposed as 'digital_in' (di1)
%     - A single time channel 't1' is always present
%
%   Data is returned as int16 to preserve native precision. Use
%   ndr.format.neuropixelsGLX.samples2volts for voltage conversion.
%
%   Example:
%       r = ndr.reader('neuropixelsGLX');
%       files = {'/data/run_g0/run_g0_imec0/run_g0_t0.imec0.ap.meta'};
%       channels = r.getchannelsepoch(files, 1);
%       data = r.readchannels_epochsamples('analog_in', 1:10, files, 1, 1, 30000);
%
%   See also: ndr.reader.base, ndr.format.neuropixelsGLX.header,
%             ndr.format.neuropixelsGLX.read

    properties (SetAccess=protected, GetAccess=public)
    end

    methods

        function obj = neuropixelsGLX()
            %NEUROPIXELSGLX Create a new NDR reader for Neuropixels SpikeGLX data.
            %
            %   OBJ = ndr.reader.neuropixelsGLX()
            %
            %   Creates a Neuroscience Data Reader object for Neuropixels
            %   SpikeGLX AP-band binary files (.ap.bin with .ap.meta).
            %
            % See also: ndr.reader.base
        end

        function ec = epochclock(obj, epochstreams, epoch_select)
            %EPOCHCLOCK Return the clock type objects for an epoch.
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns {ndr.time.clocktype('dev_local_time')} since
            %   SpikeGLX timestamps are relative to the start of each file.
            %
            % See also: ndr.time.clocktype

            ec = {ndr.time.clocktype('dev_local_time')};
        end

        function t0t1 = t0_t1(obj, epochstreams, epoch_select)
            %T0_T1 Return the beginning and end epoch times.
            %
            %   T0T1 = T0_T1(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns {[0 duration]} where duration is computed from the
            %   binary file size, channel count, and sample rate.
            %
            % See also: ndr.format.neuropixelsGLX.header

            metafile = obj.filenamefromepochfiles(epochstreams);
            info = ndr.format.neuropixelsGLX.header(metafile);

            binfile = [metafile(1:end-4) 'bin'];
            if isfile(binfile)
                finfo = dir(binfile);
                bytes_per_sample = 2 * info.n_saved_chans;
                total_samples = floor(finfo.bytes / bytes_per_sample);
            else
                % Fall back to meta file info
                total_samples = round(info.file_time_secs * info.sample_rate);
            end

            t_end = (total_samples - 1) / info.sample_rate;
            t0t1 = {[0 t_end]};
        end

        function channels = getchannelsepoch(obj, epochstreams, epoch_select)
            %GETCHANNELSEPOCH List channels available for a given epoch.
            %
            %   CHANNELS = GETCHANNELSEPOCH(OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns a structure array with fields 'name', 'type', and
            %   'time_channel'. Neural channels are 'analog_in' (ai1..aiN),
            %   the sync channel is 'digital_in' (di1), and a time channel
            %   't1' is always present.
            %
            % See also: ndr.format.neuropixelsGLX.header

            metafile = obj.filenamefromepochfiles(epochstreams);
            info = ndr.format.neuropixelsGLX.header(metafile);

            channels = vlt.data.emptystruct('name', 'type', 'time_channel');

            % Time channel
            channels(1) = struct('name', 't1', 'type', 'time', 'time_channel', 1);

            % Neural channels (analog_in)
            for i = 1:info.n_neural_chans
                channels(end+1) = struct('name', ['ai' int2str(i)], ...
                    'type', 'analog_in', 'time_channel', 1); %#ok<AGROW>
            end

            % Sync channel (digital_in)
            if info.n_sync_chans > 0
                channels(end+1) = struct('name', 'di1', ...
                    'type', 'digital_in', 'time_channel', 1);
            end
        end

        function [datatype, p, datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS,
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   For analog_in channels: int16, [0 1], 16 bits.
            %   For time channels: double (computed), [0 1], 64 bits.
            %   For digital_in channels: int16 (sync word), [0 1], 16 bits.
            %
            % See also: ndr.reader.base/underlying_datatype

            switch lower(channeltype)
                case {'analog_in', 'ai'}
                    datatype = 'int16';
                    datasize = 16;
                    p = repmat([0 1], numel(channel), 1);
                case {'time', 't'}
                    datatype = 'double';
                    datasize = 64;
                    p = repmat([0 1], numel(channel), 1);
                case {'digital_in', 'di'}
                    datatype = 'int16';
                    datasize = 16;
                    p = repmat([0 1], numel(channel), 1);
                otherwise
                    [datatype, p, datasize] = underlying_datatype@ndr.reader.base(...
                        obj, epochstreams, epoch_select, channeltype, channel);
            end
        end

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES Read data samples for specified channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(OBJ, CHANNELTYPE, CHANNEL,
            %       EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data between sample S0 and S1 (inclusive, 1-based).
            %   Returns an (S1-S0+1) x numel(CHANNEL) matrix.
            %
            %   For 'analog_in': returns int16 neural data.
            %   For 'time': returns double time stamps in seconds.
            %   For 'digital_in': returns int16 sync word values.
            %
            % See also: ndr.format.neuropixelsGLX.read

            metafile = obj.filenamefromepochfiles(epochstreams);
            info = ndr.format.neuropixelsGLX.header(metafile);
            binfile = [metafile(1:end-4) 'bin'];

            switch lower(channeltype)
                case {'time', 'timestamp', 't'}
                    % Compute time from sample numbers
                    t0t1 = obj.t0_t1(epochstreams, epoch_select);
                    data = ndr.time.fun.samples2times((s0:s1)', t0t1{1}, info.sample_rate);

                case {'analog_in', 'ai'}
                    % Read neural channels (1-based channel numbers map to
                    % file columns 1:n_neural_chans)
                    [data, ~] = ndr.format.neuropixelsGLX.read(binfile, -Inf, Inf, ...
                        'numChans', info.n_saved_chans, ...
                        'SR', info.sample_rate, ...
                        'channels', channel);
                    % The read function returns the full file; we need to
                    % subset by sample range. Instead, use binarymatrix directly.
                    data = read_samples(binfile, info, uint32(channel), s0, s1);

                case {'digital_in', 'di'}
                    % Sync channel is the last channel in the file
                    sync_chan = info.n_saved_chans;
                    data = read_samples(binfile, info, uint32(sync_chan), s0, s1);

                otherwise
                    error('ndr:reader:neuropixelsGLX:UnknownChannelType', ...
                        'Unknown channel type "%s".', channeltype);
            end
        end

        function sr = samplerate(obj, epochstreams, epoch_select, channeltype, channel)
            %SAMPLERATE Get the sample rate for specified channels.
            %
            %   SR = SAMPLERATE(OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the sampling rate in Hz. For Neuropixels AP-band,
            %   all channels share the same sample rate (typically 30 kHz).
            %
            % See also: ndr.format.neuropixelsGLX.header

            metafile = obj.filenamefromepochfiles(epochstreams);
            info = ndr.format.neuropixelsGLX.header(metafile);
            sr = repmat(info.sample_rate, size(channel));
        end

        function metafile = filenamefromepochfiles(obj, filename_array)
            %FILENAMEFROMEPOCHFILES Identify the .ap.meta file from epoch file list.
            %
            %   METAFILE = FILENAMEFROMEPOCHFILES(OBJ, FILENAME_ARRAY)
            %
            %   Searches the cell array FILENAME_ARRAY for a file matching
            %   the pattern *.ap.meta. Returns the full path. Errors if
            %   zero or more than one match is found.
            %
            % See also: ndr.reader.base

            metafile = '';
            count = 0;
            for i = 1:numel(filename_array)
                if endsWith(filename_array{i}, '.ap.meta', 'IgnoreCase', true)
                    metafile = filename_array{i};
                    count = count + 1;
                end
            end

            if count == 0
                error('ndr:reader:neuropixelsGLX:NoMetaFile', ...
                    'No .ap.meta file found in the epoch file list.');
            elseif count > 1
                error('ndr:reader:neuropixelsGLX:MultipleMetaFiles', ...
                    'Multiple .ap.meta files found. Each epoch should have exactly one.');
            end
        end

        function channelstruct = daqchannels2internalchannels(obj, channelprefix, channelnumber, epochstreams, epoch_select)
            %DAQCHANNELS2INTERNALCHANNELS Convert DAQ channel specs to internal format.
            %
            %   CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(OBJ, CHANNELPREFIX,
            %       CHANNELNUMBER, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Converts requested channels (prefix/number pairs) to the
            %   internal structure needed by readchannels_epochsamples.
            %
            % See also: ndr.reader.base/daqchannels2internalchannels

            channelstruct = vlt.data.emptystruct('internal_type', 'internal_number', ...
                'internal_channelname', 'ndr_type', 'samplerate');

            channels_available = obj.getchannelsepoch(epochstreams, epoch_select);

            for i = 1:numel(channelnumber)
                current_prefix = lower(channelprefix{i});
                current_number = channelnumber(i);

                for j = 1:numel(channels_available)
                    [avail_prefix, avail_number] = ndr.string.channelstring2channels(channels_available(j).name);
                    if strcmpi(current_prefix, avail_prefix{1}) && current_number == avail_number(1)
                        newentry.internal_channelname = channels_available(j).name;
                        newentry.internal_type = channels_available(j).type;
                        newentry.internal_number = current_number;
                        newentry.ndr_type = ndr.reader.base.mfdaq_type(newentry.internal_type);
                        newentry.samplerate = obj.samplerate(epochstreams, epoch_select, current_prefix, current_number);
                        channelstruct(end+1) = newentry; %#ok<AGROW>
                        break;
                    end
                end
            end
        end

    end % methods

end % classdef


function data = read_samples(binfile, info, file_channels, s0, s1)
%READ_SAMPLES Read specific samples and channels from a SpikeGLX .bin file.
%
%   DATA = READ_SAMPLES(BINFILE, INFO, FILE_CHANNELS, S0, S1)
%
%   Low-level helper that reads samples S0 through S1 (1-based, inclusive)
%   for the specified FILE_CHANNELS (uint32, 1-based column indices in the
%   binary file) using ndr.format.binarymatrix.read.

    [data, ~, ~, ~] = ndr.format.binarymatrix.read(...
        binfile, ...
        uint32(info.n_saved_chans), ...
        file_channels, ...
        double(s0), ...
        double(s1), ...
        'dataType', 'int16', ...
        'byteOrder', 'ieee-le', ...
        'headerSkip', uint64(0));
end
