function volts = samples2volts(data, info)
%SAMPLES2VOLTS Convert raw int16 samples to voltage in volts.
%
%   VOLTS = ndr.format.neuropixelsGLX.samples2volts(DATA, INFO)
%
%   Converts raw int16 Neuropixels data to voltage using the gain and range
%   parameters from the meta file header.
%
%   The conversion formula for Neuropixels imec channels is:
%       volts = double(data) * Vrange / (2 * maxInt * totalGain)
%
%   where Vrange = imAiRangeMax - imAiRangeMin, maxInt = imMaxInt, and
%   totalGain is parsed from the imroTbl (per-channel gains).
%
%   For simplicity, this function applies a uniform gain. If per-channel
%   gains are needed, use the imroTbl field from the meta structure.
%
%   Inputs:
%       DATA - N x C int16 matrix of raw samples.
%       INFO - Header structure from ndr.format.neuropixelsGLX.header.
%
%   Outputs:
%       VOLTS - N x C double matrix of voltages in volts.
%
%   Example:
%       info = ndr.format.neuropixelsGLX.header('run_g0_t0.imec0.ap.meta');
%       [data, ~] = ndr.format.neuropixelsGLX.read('run_g0_t0.imec0.ap.bin', 0, 1);
%       volts = ndr.format.neuropixelsGLX.samples2volts(data(:,1:info.n_neural_chans), info);
%
%   See also: ndr.format.neuropixelsGLX.header, ndr.format.neuropixelsGLX.read

    arguments
        data {mustBeNumeric}
        info (1,1) struct
    end

    vrange = info.voltage_range(2) - info.voltage_range(1);

    % Parse per-channel gains from imroTbl if available
    if isfield(info.meta, 'imroTbl')
        gains = parse_imro_gains(info.meta.imroTbl, info.stream_type);
        n_chans = size(data, 2);
        if numel(gains) >= n_chans
            gains = gains(1:n_chans);
        else
            % Pad with the last gain value if data has fewer channels
            gains = [gains, repmat(gains(end), 1, n_chans - numel(gains))];
        end
        % Apply per-channel conversion
        volts = double(data) .* (vrange ./ (2 * info.max_int .* gains));
    else
        % Default gain for Neuropixels 1.0 AP band
        if strcmpi(info.stream_type, 'ap')
            default_gain = 500;
        else
            default_gain = 250;
        end
        volts = double(data) * vrange / (2 * info.max_int * default_gain);
    end

end


function gains = parse_imro_gains(imroTbl_str, stream_type)
%PARSE_IMRO_GAINS Extract per-channel gains from imroTbl string.
%
%   The imroTbl format varies by probe type but generally:
%     (probeType,nChan)(chanIdx bank refIdx apGain lfGain apHiPass)
%   For each channel entry in parentheses after the first (header) entry,
%   the AP gain is at position 4 and LF gain at position 5 (0-indexed from
%   the channel entry fields).

    gains = [];

    % Find all parenthesized groups
    tokens = regexp(imroTbl_str, '\(([^)]+)\)', 'tokens');
    if numel(tokens) < 2
        return;
    end

    % First token is the header, skip it
    for i = 2:numel(tokens)
        vals = sscanf(tokens{i}{1}, '%d %d %d %d %d %d');
        if numel(vals) >= 5
            if strcmpi(stream_type, 'ap')
                gains(end+1) = vals(4); %#ok<AGROW>
            else
                gains(end+1) = vals(5); %#ok<AGROW>
            end
        elseif numel(vals) >= 4
            gains(end+1) = vals(4); %#ok<AGROW>
        end
    end

end
