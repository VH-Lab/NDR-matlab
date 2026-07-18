function header = read_SOMSMR_header(filename)
% SONPIPE.READ_SOMSMR_HEADER - Read header information from a CED SMR/SMRX file
%
%   HEADER = ndr.format.ced.sonpipe.read_SOMSMR_header(FILENAME)
%
%   Returns a structure HEADER describing the CED Spike2 file FILENAME. Works
%   with both 32-bit .smr and 64-bit .smrx files (sonpy opens either).
%
%   This is a drop-in analogue of ndr.format.ced.read_SOMSMR_header, but reads
%   the file through the sonpipe command-line tool (sonpy) rather than sigTOOL.
%
%   HEADER contains two substructures:
%   --------------------------------------------------------------------
%   fileinfo     | Information about the file (timebase, duration, #channels)
%   channelinfo  | Struct array, one entry per recorded (non-Off) channel
%
%   HEADER.fileinfo fields include:
%     timebase        - seconds per clock tick
%     max_channels    - number of channel slots
%     max_time_ticks  - duration of the recording in ticks
%     max_time        - duration of the recording in seconds
%     dTimeBase, usPerTime, maxFTime - aliases kept for compatibility with the
%                       classic SON/sigTOOL header (dTimeBase*maxFTime*usPerTime
%                       equals max_time).
%
%   HEADER.channelinfo(k) fields include:
%     number          - Spike2 channel number (1-based)
%     kind            - CED data-type code (1=Adc, 2/3/4=Event, 5=Marker,
%                       6=AdcMark/WaveMark, 7=RealMark, 8=TextMark, 9=RealWave)
%     kind_name       - human-readable kind
%     ndr_type        - NDR channel type ('analog_in','event','mark','text')
%     title, units    - channel title and units
%     sampleinterval  - seconds between samples (NaN for non-waveform channels)
%     samplerate      - 1/sampleinterval (NaN for non-waveform channels)
%     scale, offset   - Adc-to-real-units conversion (waveform channels)
%     num_samples     - estimated total waveform samples
%
%   See also ndr.format.ced.sonpipe.read_SOMSMR_datafile, ndr.format.ced.sonpipe.read_SOMSMR_sampleinterval

	arguments
		filename {mustBeTextScalar}
	end

	txt = invoke_text(sprintf('header "%s"', filename));
	raw = jsondecode(txt);

	header.fileinfo = raw.fileinfo;
	% Compatibility aliases so callers written against the classic SON header
	% keep working (see ndr.reader.ced_smr/t0_t1 and event block timing).
	header.fileinfo.usPerTime = 1;
	header.fileinfo.dTimeBase = raw.fileinfo.timebase;
	header.fileinfo.maxFTime  = raw.fileinfo.max_time_ticks;

	if isfield(raw, 'channelinfo')
		header.channelinfo = raw.channelinfo;
	else
		header.channelinfo = struct([]);
	end

	% jsondecode may return a cell array if the channel structs were ragged; the
	% CLI emits uniform fields precisely so this stays a struct array, but guard
	% just in case.
	if iscell(header.channelinfo)
		header.channelinfo = cell2struct_uniform(header.channelinfo);
	end
end

function s = cell2struct_uniform(c)
	if isempty(c)
		s = struct([]);
		return;
	end
	s = c{1};
	for i = 2:numel(c)
		s(i) = c{i};
	end
end
