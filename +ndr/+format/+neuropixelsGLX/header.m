function info = header(metafilename)
%HEADER Parse a SpikeGLX .meta file into a standardized header structure.
%
%   INFO = ndr.format.neuropixelsGLX.header(METAFILENAME)
%
%   Reads a SpikeGLX .meta file and extracts key recording parameters into
%   a standardized structure with numeric fields suitable for data reading.
%
%   This function handles both AP-band and LF-band .meta files, and
%   correctly parses the channel subset specification (snsSaveChanSubset)
%   to determine exactly which channels were saved.
%
%   Inputs:
%       METAFILENAME - Full path to the .meta file (char row vector).
%
%   Outputs:
%       INFO - A scalar structure with the following fields:
%           sample_rate      : Sampling rate in Hz (double).
%           n_saved_chans    : Total number of saved channels including
%                              the sync channel (double).
%           n_neural_chans   : Number of neural (non-sync) channels saved
%                              (double). For AP band this is the number of
%                              AP channels; for LF band, the LF channels.
%           n_sync_chans     : Number of sync channels (0 or 1) (double).
%           saved_chan_list   : 1-based vector of saved channel indices
%                              (double row vector). If all channels are
%                              saved, this is 1:n_saved_chans.
%           voltage_range    : Peak-to-peak voltage range [Vmin Vmax] in
%                              volts (1x2 double).
%           max_int          : Maximum integer value for the ADC (double).
%           bits_per_sample  : Bits per sample value (always 16) (double).
%           file_size_bytes  : Total file size in bytes (double).
%           file_time_secs   : Recording duration in seconds (double).
%           probe_type       : Probe type identifier (char).
%           probe_sn         : Probe serial number (char).
%           stream_type      : 'ap' or 'lf' (char), determined from the
%                              meta file name.
%           meta             : The raw meta structure from readmeta (struct).
%
%   Example:
%       info = ndr.format.neuropixelsGLX.header('/data/run_g0_t0.imec0.ap.meta');
%       fprintf('Sample rate: %g Hz\n', info.sample_rate);
%       fprintf('Neural channels: %d\n', info.n_neural_chans);
%       fprintf('Duration: %.2f s\n', info.file_time_secs);
%
%   See also: ndr.format.neuropixelsGLX.readmeta, ndr.format.neuropixelsGLX.read

    arguments
        metafilename (1,:) char {mustBeFile}
    end

    meta = ndr.format.neuropixelsGLX.readmeta(metafilename);

    info = struct();
    info.meta = meta;

    % Sample rate
    if isfield(meta, 'imSampRate')
        info.sample_rate = str2double(meta.imSampRate);
    elseif isfield(meta, 'niSampRate')
        info.sample_rate = str2double(meta.niSampRate);
    else
        error('ndr:format:neuropixelsGLX:header:NoSampleRate', ...
            'Could not find sample rate in meta file.');
    end

    % Number of saved channels
    info.n_saved_chans = str2double(meta.nSavedChans);

    % Parse snsApLfSy or snsMnMaXaDw to determine neural vs sync channels.
    % Also compute, for digital lines:
    %   n_digital_word_cols : number of int16 columns in the .bin file
    %                         that hold digital word data (stored last).
    %   n_digital_lines     : number of single-bit digital lines exposed.
    %   digital_line_col    : (n_digital_lines x 1) 0-based DW column
    %                         offset (0 = first DW column).
    %   digital_line_bit    : (n_digital_lines x 1) 0-based bit position
    %                         within that column (0..15).
    %   digital_line_label  : (n_digital_lines x 1) cellstr describing
    %                         the underlying SpikeGLX line, e.g. 'XD0'
    %                         for port-0 line 0, 'XD1.3' for port-1 line
    %                         3, or 'SY0.6' for sync col 0 bit 6.
    %
    % For NIDQ streams the count of active lines comes from niXDBytes1
    % and niXDBytes2 (bytes captured per port). NI-DAQ hardware only
    % enables digital input in whole-byte chunks, so every bit within a
    % captured byte is electrically active even if the user only wired
    % some of them; niXDChans1/2 is just informational and is not used
    % to gate which lines are exposed. For IMEC streams there is no
    % per-bit configuration; all 16 bits of each sync int16 are exposed.
    if isfield(meta, 'snsApLfSy')
        % imec stream: AP,LF,SY counts
        counts = sscanf(meta.snsApLfSy, '%d,%d,%d');
        % counts(1) = AP chans, counts(2) = LF chans, counts(3) = SY chans
        info.n_sync_chans = counts(3);
        % Determine if this is AP or LF from filename
        [~, name, ~] = fileparts(metafilename);
        if contains(name, '.lf')
            info.stream_type = 'lf';
            info.n_neural_chans = counts(2);
        else
            info.stream_type = 'ap';
            info.n_neural_chans = counts(1);
        end
        % IMEC sync word is an int16; each sync column provides 16 bits.
        % In practice only bit 6 is the SMA sync input, but all 16 bits
        % are exposed as independent digital lines so callers can pick
        % whichever they need.
        info.n_digital_word_cols = info.n_sync_chans;
        n_lines = 16 * info.n_sync_chans;
        info.n_digital_lines    = n_lines;
        info.digital_line_col   = zeros(n_lines, 1);
        info.digital_line_bit   = zeros(n_lines, 1);
        info.digital_line_label = cell(n_lines, 1);
        idx = 0;
        for c = 0:(info.n_sync_chans - 1)
            for b = 0:15
                idx = idx + 1;
                info.digital_line_col(idx)   = c;
                info.digital_line_bit(idx)   = b;
                info.digital_line_label{idx} = sprintf('SY%d.%d', c, b);
            end
        end
    elseif isfield(meta, 'snsMnMaXaDw')
        % NI-DAQ stream: MN,MA,XA,DW
        info.stream_type = 'nidq';
        counts = sscanf(meta.snsMnMaXaDw, '%d,%d,%d,%d');
        info.n_mn_chans = counts(1);  % multiplexed neural
        info.n_ma_chans = counts(2);  % multiplexed analog
        info.n_xa_chans = counts(3);  % non-multiplexed analog
        info.n_dw_chans = counts(4);  % digital word int16 columns
        info.n_neural_chans = counts(1) + counts(2) + counts(3);
        info.n_sync_chans = counts(4);
        info.n_digital_word_cols = counts(4);

        % Bytes saved per port. NI hardware only enables digital input
        % in whole-byte chunks, so each saved byte = 8 active lines
        % regardless of how many of them the user actually wired up.
        n_bytes_p0 = 0;
        if isfield(meta, 'niXDBytes1')
            n_bytes_p0 = str2double(meta.niXDBytes1);
        end
        n_bytes_p1 = 0;
        if isfield(meta, 'niXDBytes2')
            n_bytes_p1 = str2double(meta.niXDBytes2);
        end

        % If neither byte field is present, fall back to assuming every
        % bit of every DW int16 column is in use (16 lines per column).
        if n_bytes_p0 == 0 && n_bytes_p1 == 0
            n_lines_p0 = 16 * info.n_dw_chans;
            n_lines_p1 = 0;
        else
            n_lines_p0 = 8 * n_bytes_p0;
            n_lines_p1 = 8 * n_bytes_p1;
        end

        % Compute the (col, bit) position of each active line.
        % SpikeGLX storage layout: port0 lines occupy the first
        % n_bytes_p0*8 bits of the concatenated digital bit stream,
        % then port1 lines occupy the next n_bytes_p1*8 bits. The bit
        % stream is laid out across n_dw_chans int16 columns (16 bits
        % per column).
        n_lines = n_lines_p0 + n_lines_p1;
        info.n_digital_lines    = n_lines;
        info.digital_line_col   = zeros(n_lines, 1);
        info.digital_line_bit   = zeros(n_lines, 1);
        info.digital_line_label = cell(n_lines, 1);
        idx = 0;
        for k = 0:(n_lines_p0 - 1)
            abs_bit = k;
            idx = idx + 1;
            info.digital_line_col(idx)   = floor(abs_bit / 16);
            info.digital_line_bit(idx)   = mod(abs_bit, 16);
            info.digital_line_label{idx} = sprintf('XD%d', k);
        end
        for k = 0:(n_lines_p1 - 1)
            abs_bit = n_bytes_p0 * 8 + k;
            idx = idx + 1;
            info.digital_line_col(idx)   = floor(abs_bit / 16);
            info.digital_line_bit(idx)   = mod(abs_bit, 16);
            info.digital_line_label{idx} = sprintf('XD1.%d', k);
        end
    else
        % Fallback
        info.stream_type = 'unknown';
        info.n_neural_chans = info.n_saved_chans - 1;
        info.n_sync_chans = 1;
        info.n_digital_word_cols = 1;
        info.n_digital_lines = 16;
        info.digital_line_col   = zeros(16, 1);
        info.digital_line_bit   = (0:15)';
        info.digital_line_label = cell(16, 1);
        for b = 0:15
            info.digital_line_label{b+1} = sprintf('bit%d', b);
        end
    end

    % Parse saved channel subset
    if isfield(meta, 'snsSaveChanSubset')
        info.saved_chan_list = parse_channel_subset(meta.snsSaveChanSubset, info.n_saved_chans);
    else
        info.saved_chan_list = 1:info.n_saved_chans;
    end

    % Voltage range
    if isfield(meta, 'imAiRangeMax')
        vmax = str2double(meta.imAiRangeMax);
        vmin = str2double(meta.imAiRangeMin);
        info.voltage_range = [vmin vmax];
    elseif isfield(meta, 'niAiRangeMax')
        vmax = str2double(meta.niAiRangeMax);
        vmin = str2double(meta.niAiRangeMin);
        info.voltage_range = [vmin vmax];
    else
        info.voltage_range = [-0.6 0.6]; % Neuropixels 1.0 default
    end

    % Max integer value
    if isfield(meta, 'imMaxInt')
        info.max_int = str2double(meta.imMaxInt);
    elseif isfield(meta, 'niMaxInt')
        info.max_int = str2double(meta.niMaxInt);
    else
        info.max_int = 512; % Neuropixels 1.0 default
    end

    % NI-DAQ gains
    if isfield(meta, 'niMNGain')
        info.ni_mn_gain = str2double(meta.niMNGain);
    end
    if isfield(meta, 'niMAGain')
        info.ni_ma_gain = str2double(meta.niMAGain);
    end

    % Bits per sample
    info.bits_per_sample = 16;

    % File size and duration
    if isfield(meta, 'fileSizeBytes')
        info.file_size_bytes = str2double(meta.fileSizeBytes);
    else
        info.file_size_bytes = 0;
    end

    if isfield(meta, 'fileTimeSecs')
        info.file_time_secs = str2double(meta.fileTimeSecs);
    else
        info.file_time_secs = 0;
    end

    % Probe information
    if isfield(meta, 'imDatPrb_type')
        info.probe_type = meta.imDatPrb_type;
    else
        info.probe_type = '';
    end

    if isfield(meta, 'imDatPrb_sn')
        info.probe_sn = meta.imDatPrb_sn;
    else
        info.probe_sn = '';
    end

end


function chan_list = parse_channel_subset(subset_str, n_saved_chans)
%PARSE_CHANNEL_SUBSET Parse the snsSaveChanSubset field.
%
%   CHAN_LIST = PARSE_CHANNEL_SUBSET(SUBSET_STR, N_SAVED_CHANS)
%
%   The snsSaveChanSubset field can be:
%     - 'all'         : All channels saved
%     - '0:5,8,10:12' : Specific channels (0-based ranges/singles)
%
%   Returns a 1-based channel index vector.

    if strcmpi(strtrim(subset_str), 'all')
        chan_list = 1:n_saved_chans;
        return;
    end

    chan_list = [];
    parts = strsplit(strtrim(subset_str), ',');
    for i = 1:numel(parts)
        part = strtrim(parts{i});
        if contains(part, ':')
            range_vals = sscanf(part, '%d:%d');
            chan_list = [chan_list, range_vals(1):range_vals(2)]; %#ok<AGROW>
        else
            chan_list = [chan_list, str2double(part)]; %#ok<AGROW>
        end
    end

    % Convert from 0-based to 1-based
    chan_list = chan_list + 1;

end
