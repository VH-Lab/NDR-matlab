function [data, total_samples, total_time, blockinfo, time] = read_SOMSMR_datafile(filename, header, channel_number, t0, t1)
% SONPIPE.READ_SOMSMR_DATAFILE - Read samples from a CED SMR/SMRX file
%
%   [DATA, TOTAL_SAMPLES, TOTAL_TIME, BLOCKINFO, TIME] = ...
%       ndr.format.ced.sonpipe.read_SOMSMR_datafile(FILENAME, HEADER, CHANNEL_NUMBER, T0, T1)
%
%   Reads data for CHANNEL_NUMBER (1-based Spike2 channel number) from the CED
%   Spike2 file FILENAME, between times T0 and T1 (seconds). If T0 is negative
%   it is clamped to 0; if T1 is Inf the read runs to the end of the recording.
%   HEADER may be [] (it will be read from the file).
%
%   Works with both 32-bit .smr and 64-bit .smrx files. This is a drop-in
%   analogue of ndr.format.ced.read_SOMSMR_datafile, backed by the sonpipe CLI.
%
%   The behaviour depends on the channel kind:
%     * Waveform (Adc/RealWave): DATA is a column of scaled real-unit samples;
%       TIME is the matching column of sample times (seconds). Data is streamed
%       from the CLI as raw little-endian doubles for speed.
%     * Event (kinds 2/3/4): DATA and TIME are equal columns of event times (s).
%     * Marker (kinds 5/6/7/8): DATA holds the marker codes (or, for TextMark,
%       a char matrix of the text); TIME holds the marker times (seconds).
%
%   Outputs:
%     DATA          - the channel data (see above)
%     TOTAL_SAMPLES - estimated total waveform samples ([] for non-waveforms)
%     TOTAL_TIME    - estimated recording duration in seconds
%     BLOCKINFO     - always [] here; sonpy abstracts away SON disk blocks. The
%                     output is retained for signature compatibility.
%     TIME          - times (seconds) matching DATA
%
%   Note: only one channel can be read per call, matching the NDR function.
%
%   See also ndr.format.ced.sonpipe.read_SOMSMR_header, ndr.format.ced.sonpipe.read_SOMSMR_sampleinterval

	data = [];
	total_samples = [];
	total_time = [];
	blockinfo = [];
	time = [];

	if isempty(header)
		header = ndr.format.ced.sonpipe.read_SOMSMR_header(filename);
	end
	if numel(channel_number) > 1
		error('sonpipe:singleChannel', ...
			'Only one channel may be read per call; CHANNEL_NUMBER must be scalar.');
	end

	ci = ndr.format.ced.sonpipe.channelinfo(header, channel_number);
	kind = ci.kind;
	total_time = ci.max_time;

	if any(kind == [1 9]) % ---- waveform ----
		sr = ci.samplerate;
		total_samples = ci.num_samples;
		if t0 < 0 || isinf(t0)
			t0 = 0;
		end
		s0 = max(0, floor(t0 * sr));
		if isinf(t1)
			s1 = total_samples - 1;
		else
			s1 = floor(t1 * sr);
		end
		count = s1 - s0 + 1;
		if count <= 0
			return;
		end
		args = sprintf('read "%s" -c %d --start %d --count %d', ...
			filename, channel_number, s0, count);
		data = invoke_binary(args, 'double');
		n = numel(data);
		time = (s0 + (0:n-1)') / sr;

	elseif any(kind == [2 3 4]) % ---- event ----
		args = [sprintf('read "%s" -c %d', filename, channel_number) timewindow(t0, t1)];
		data = invoke_binary(args, 'double');
		time = data;

	else % ---- marker / wavemark / realmark / textmark (5,6,7,8) ----
		args = [sprintf('read "%s" -c %d', filename, channel_number) timewindow(t0, t1)];
		txt = invoke_text(args);
		r = jsondecode(txt);
		[time, data] = markers_to_output(r);
	end
end

function s = timewindow(t0, t1)
% Build the --t0/--t1 argument fragment, omitting defaults (t0<=0 -> start of
% file, t1=Inf -> end of file).
	s = '';
	if isfinite(t0) && t0 > 0
		s = [s sprintf(' --t0 %.12g', t0)];
	end
	if isfinite(t1)
		s = [s sprintf(' --t1 %.12g', t1)];
	end
end

function [time, data] = markers_to_output(r)
	time = [];
	data = [];
	if ~isfield(r, 'markers') || isempty(r.markers)
		return;
	end
	m = r.markers;
	if iscell(m) % ragged; normalise to struct array
		tmp = m{1};
		for i = 2:numel(m)
			tmp(i) = m{i};
		end
		m = tmp;
	end
	n = numel(m);
	time = zeros(n, 1);
	for i = 1:n
		time(i) = m(i).time;
	end
	if isfield(m, 'text')
		txt = cell(n, 1);
		for i = 1:n
			txt{i} = m(i).text;
		end
		data = char(txt);
	else
		ncode = numel(m(1).code);
		data = zeros(n, ncode);
		for i = 1:n
			data(i, :) = m(i).code(:)';
		end
	end
end
