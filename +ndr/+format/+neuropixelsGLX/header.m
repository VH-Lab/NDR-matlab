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

    % Parse snsApLfSy or snsMnMaXaDw to determine neural vs sync channels
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
    elseif isfield(meta, 'snsMnMaXaDw')
        % NI-DAQ stream: MN,MA,XA,DW
        info.stream_type = 'nidq';
        counts = sscanf(meta.snsMnMaXaDw, '%d,%d,%d,%d');
        info.n_mn_chans = counts(1);  % multiplexed neural
        info.n_ma_chans = counts(2);  % multiplexed analog
        info.n_xa_chans = counts(3);  % non-multiplexed analog
        info.n_dw_chans = counts(4);  % digital words
        info.n_neural_chans = counts(1) + counts(2) + counts(3);
        info.n_sync_chans = counts(4);
    else
        % Fallback
        info.stream_type = 'unknown';
        info.n_neural_chans = info.n_saved_chans - 1;
        info.n_sync_chans = 1;
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
