classdef neuropixelsGLX < ndr.reader.base
%NDR.READER.NEUROPIXELSGLX - Reader class for SpikeGLX data (AP, LF, NIDQ).
%
%   This class reads data from Neuropixels probes and NI-DAQ devices
%   acquired with the SpikeGLX software. Each instance handles one stream
%   (one .bin / .meta file pair per epoch).
%
%   SpikeGLX saves Neuropixels data as flat interleaved int16 binary files
%   with companion .meta text files. The binary files have no header.
%   Channel count, sample rate, and gain information are read from the
%   .meta file.
%
%   Channel mapping:
%     - Neural channels are exposed as 'analog_in' (ai1..aiN)
%     - Digital lines are exposed as 'digital_in' (di1..diM), where each
%       di channel is a single bit of the packed digital word(s). The
%       number of lines is determined from metadata: for NIDQ streams
%       it is 8 * (niXDBytes1 + niXDBytes2); for IMEC streams it is
%       16 * n_sync_chans (bit 6 is the SMA sync input in practice).
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
            %   digital lines are 'digital_in' (di1..diM) with one entry
            %   per single-bit line in the packed digital word(s), and a
            %   time channel 't1' is always present.
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

            % Digital lines (digital_in) — one per bit of the packed
            % digital word(s). n_digital_lines comes from metadata
            % (niXDBytes1/niXDBytes2 for NIDQ, 16*n_sync_chans for IMEC).
            for i = 1:info.n_digital_lines
                channels(end+1) = struct('name', ['di' int2str(i)], ...
                    'type', 'digital_in', 'time_channel', 1); %#ok<AGROW>
            end
        end

        function [datatype, p, datasize] = underlying_datatype(obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE Get the native data type for channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(OBJ, EPOCHSTREAMS,
            %       EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   CHANNELTYPE may be a char vector or a cell array of char
            %   vectors. If a cell array, all entries must be the same type.
            %
            %   For analog_in channels: int16, [0 1], 16 bits.
            %   For time channels: double (computed), [0 1], 64 bits.
            %   For digital_in channels: int16 (sync word), [0 1], 16 bits.
            %
            % See also: ndr.reader.base/underlying_datatype

            if iscell(channeltype)
                channeltype = channeltype{1};
            end
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
            %   CHANNELTYPE may be a char vector or a cell array of char
            %   vectors. If a cell array, all entries must be the same type.
            %
            %   For 'analog_in': returns int16 neural data.
            %   For 'time': returns double time stamps in seconds.
            %   For 'digital_in': returns int16 single-bit values (0 or 1)
            %                     extracted from the packed digital word(s).
            %                     CHANNEL gives the 1-based digital line(s).
            %
            % See also: ndr.format.neuropixelsGLX.read

            if iscell(channeltype)
                channeltype = channeltype{1};
            end

            metafile = obj.filenamefromepochfiles(epochstreams);
            info = ndr.format.neuropixelsGLX.header(metafile);
            binfile = [metafile(1:end-4) 'bin'];

            switch lower(channeltype)
                case {'time', 'timestamp', 't'}
                    % Compute time from sample numbers
                    t0t1 = obj.t0_t1(epochstreams, epoch_select);
                    data = ndr.time.fun.samples2times((s0:s1)', t0t1{1}, info.sample_rate);

                case {'analog_in', 'ai'}
                    data = read_samples(binfile, info, uint32(channel), s0, s1);

                case {'digital_in', 'di'}
                    % Digital words occupy the last n_digital_word_cols
                    % columns of the file. Each int16 column holds up to
                    % 16 single-bit lines. CHANNEL is a vector of 1-based
                    % digital line indices; map each to (column, bit) and
                    % extract the bit with bitget.
                    line_0based = double(channel(:)) - 1;
                    if any(line_0based < 0) || ...
                       any(line_0based >= info.n_digital_lines)
                        error('ndr:reader:neuropixelsGLX:DigitalLineOutOfRange', ...
                            'Digital line out of range; valid lines are 1..%d.', ...
                            info.n_digital_lines);
                    end
                    first_dw_col = info.n_saved_chans - info.n_digital_word_cols + 1;
                    dw_col_offset = floor(line_0based / 16);  % 0-based DW column offset
                    bit_pos       = mod(line_0based, 16);     % 0-based bit within column

                    n_samples = double(s1) - double(s0) + 1;
                    data = zeros(n_samples, numel(channel), 'int16');
                    unique_cols = unique(dw_col_offset);
                    for u = 1:numel(unique_cols)
                        file_col = first_dw_col + unique_cols(u);
                        raw = read_samples(binfile, info, uint32(file_col), s0, s1);
                        idx = find(dw_col_offset == unique_cols(u));
                        for k = 1:numel(idx)
                            data(:, idx(k)) = int16(bitget(raw, bit_pos(idx(k)) + 1));
                        end
                    end

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
            %FILENAMEFROMEPOCHFILES Identify the companion .meta file from epoch file list.
            %
            %   METAFILE = FILENAMEFROMEPOCHFILES(OBJ, FILENAME_ARRAY)
            %
            %   Finds the .meta file that is the companion to the .bin file
            %   in the epoch file list. The .meta file must have the same
            %   base name as the .bin file (e.g., run.nidq.bin -> run.nidq.meta).
            %   This allows other .meta files to be present in the epoch for
            %   synchronization purposes.
            %
            % See also: ndr.reader.base

            % First, find the .bin file
            binfile = '';
            for i = 1:numel(filename_array)
                if endsWith(filename_array{i}, '.bin', 'IgnoreCase', true)
                    binfile = filename_array{i};
                    break;
                end
            end

            if ~isempty(binfile)
                % Derive the expected .meta filename from the .bin filename
                metafile = [binfile(1:end-3) 'meta'];
                % Verify it exists in the file list or on disk
                if ~any(strcmp(filename_array, metafile)) && ~isfile(metafile)
                    error('ndr:reader:neuropixelsGLX:NoMetaFile', ...
                        'No companion .meta file found for %s.', binfile);
                end
            else
                % No .bin file; fall back to finding a single .meta file
                metafile = '';
                count = 0;
                for i = 1:numel(filename_array)
                    if endsWith(filename_array{i}, '.meta', 'IgnoreCase', true)
                        metafile = filename_array{i};
                        count = count + 1;
                    end
                end
                if count == 0
                    error('ndr:reader:neuropixelsGLX:NoMetaFile', ...
                        'No .meta file found in the epoch file list.');
                elseif count > 1
                    error('ndr:reader:neuropixelsGLX:MultipleMetaFiles', ...
                        'Multiple .meta files found and no .bin file to disambiguate.');
                end
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
