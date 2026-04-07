function volts = samples2volts(data, info, channels)
%SAMPLES2VOLTS Convert raw int16 samples to voltage in volts.
%
%   VOLTS = ndr.format.neuropixelsGLX.samples2volts(DATA, INFO)
%   VOLTS = ndr.format.neuropixelsGLX.samples2volts(DATA, INFO, CHANNELS)
%
%   Converts raw int16 Neuropixels data to voltage using the gain and range
%   parameters from the meta file header.
%
%   The conversion formula for Neuropixels imec channels is:
%       volts = double(data) * imAiRangeMax / imMaxInt / gain
%
%   where imAiRangeMax and imMaxInt come from the meta file and gain is
%   the per-channel gain from the imroTbl. This matches the official
%   SpikeGLX MATLAB tools (SGLX_readMeta.m).
%
%   Per-channel gains are automatically parsed from the imroTbl field.
%   If imroTbl is absent, default gains are used (500 for AP, 250 for LF).
%
%   For NI-DAQ streams, gains are determined from niMNGain and niMAGain
%   fields in the meta file.
%
%   Inputs:
%       DATA     - N x C int16 matrix of raw samples.
%       INFO     - Header structure from ndr.format.neuropixelsGLX.header.
%       CHANNELS - Optional 1-based channel indices corresponding to the
%                  columns of DATA. If omitted, columns are assumed to be
%                  channels 1:C in order.
%
%   Outputs:
%       VOLTS - N x C double matrix of voltages in volts.
%
%   Example:
%       info = ndr.format.neuropixelsGLX.header('run_g0_t0.imec0.ap.meta');
%       [data, ~] = ndr.format.neuropixelsGLX.read('run_g0_t0.imec0.ap.bin', 0, 1, 'scale', false);
%       volts = ndr.format.neuropixelsGLX.samples2volts(data(:,1:info.n_neural_chans), info);
%
%   See also: ndr.format.neuropixelsGLX.header, ndr.format.neuropixelsGLX.read

    arguments
        data {mustBeNumeric}
        info (1,1) struct
        channels (1,:) {mustBeNumeric, mustBeInteger, mustBePositive} = []
    end

    vmax = info.voltage_range(2);
    n_chans = size(data, 2);

    if strcmpi(info.stream_type, 'nidq')
        % NI-DAQ stream: build gain and digital mask for all channels
        [all_gains, all_is_digital] = build_nidq_gains(info, info.n_saved_chans);
        if ~isempty(channels)
            gains = all_gains(channels);
            is_digital = all_is_digital(channels);
        else
            gains = all_gains(1:n_chans);
            is_digital = all_is_digital(1:n_chans);
        end
        volts = double(data);
        analog_cols = ~is_digital;
        if any(analog_cols)
            volts(:, analog_cols) = volts(:, analog_cols) .* ...
                (vmax ./ (info.max_int .* gains(analog_cols)));
        end
        % Digital columns remain as raw double(data) — no voltage scaling
    elseif isfield(info.meta, 'imroTbl')
        % Imec stream with per-channel gains from imroTbl
        all_gains = parse_imro_gains(info.meta.imroTbl, info.stream_type);
        n_neural = numel(all_gains);
        % Build digital mask: sync channel(s) follow neural channels
        n_total = info.n_saved_chans;
        all_is_digital = [false(1, n_neural), true(1, n_total - n_neural)];
        % Pad gains to cover all channels (sync gets gain=1, unused)
        all_gains = [all_gains, ones(1, n_total - n_neural)];
        if ~isempty(channels)
            if numel(all_gains) < max(channels)
                all_gains = [all_gains, ones(1, max(channels) - numel(all_gains))];
                all_is_digital = [all_is_digital, true(1, max(channels) - numel(all_is_digital))];
            end
            gains = all_gains(channels);
            is_digital = all_is_digital(channels);
        else
            gains = all_gains(1:n_chans);
            is_digital = all_is_digital(1:n_chans);
        end
        volts = double(data);
        analog_cols = ~is_digital;
        if any(analog_cols)
            volts(:, analog_cols) = volts(:, analog_cols) .* ...
                (vmax ./ (info.max_int .* gains(analog_cols)));
        end
    else
        % Default gain for Neuropixels 1.0
        if strcmpi(info.stream_type, 'ap')
            default_gain = 500;
        else
            default_gain = 250;
        end
        volts = double(data) * vmax / (info.max_int * default_gain);
    end

end


function [gains, is_digital] = build_nidq_gains(info, n_chans)
%BUILD_NIDQ_GAINS Build per-channel gain and digital mask for NI-DAQ streams.
%
%   NI-DAQ channels are ordered: MN (neural), MA (auxiliary analog),
%   XA (non-multiplexed analog), DW (digital words).
%   MN channels use niMNGain, MA channels use niMAGain, XA channels
%   have gain=1 (already in volts). DW channels are digital and are not
%   voltage-scaled.
%
%   Returns:
%       gains      - 1 x n_chans gain vector (analog channels only; DW = 1).
%       is_digital - 1 x n_chans logical, true for DW channels.

    mn_gain = 1;
    ma_gain = 1;
    if isfield(info, 'ni_mn_gain')
        mn_gain = info.ni_mn_gain;
    end
    if isfield(info, 'ni_ma_gain')
        ma_gain = info.ni_ma_gain;
    end

    n_mn = 0; n_ma = 0; n_xa = 0; n_dw = 0;
    if isfield(info, 'n_mn_chans'), n_mn = info.n_mn_chans; end
    if isfield(info, 'n_ma_chans'), n_ma = info.n_ma_chans; end
    if isfield(info, 'n_xa_chans'), n_xa = info.n_xa_chans; end
    if isfield(info, 'n_dw_chans'), n_dw = info.n_dw_chans; end

    gains = [repmat(mn_gain, 1, n_mn), ...
             repmat(ma_gain, 1, n_ma), ...
             ones(1, n_xa), ...
             ones(1, n_dw)];

    is_digital = [false(1, n_mn + n_ma + n_xa), true(1, n_dw)];

    % Pad or trim to match the number of channels
    if numel(gains) >= n_chans
        gains = gains(1:n_chans);
        is_digital = is_digital(1:n_chans);
    else
        gains = [gains, ones(1, n_chans - numel(gains))];
        is_digital = [is_digital, true(1, n_chans - numel(is_digital))];
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
