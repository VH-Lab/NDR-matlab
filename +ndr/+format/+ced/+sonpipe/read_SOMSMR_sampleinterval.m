function [sampleinterval, total_samples, total_time] = read_SOMSMR_sampleinterval(filename, header, channel_number)
% SONPIPE.READ_SOMSMR_SAMPLEINTERVAL - Sample interval for a CED SMR/SMRX channel
%
%   [SAMPLEINTERVAL, TOTAL_SAMPLES, TOTAL_TIME] = ...
%       ndr.format.ced.sonpipe.read_SOMSMR_sampleinterval(FILENAME, HEADER, CHANNEL_NUMBER)
%
%   Returns the sample interval (in seconds) for CHANNEL_NUMBER of the CED
%   Spike2 file FILENAME. CHANNEL_NUMBER is the 1-based Spike2 channel number.
%   HEADER is accepted for signature compatibility with
%   ndr.format.ced.read_SOMSMR_sampleinterval and may be [] (it is not needed).
%
%   For non-waveform channels (events, markers) SAMPLEINTERVAL is NaN.
%
%   Outputs:
%     SAMPLEINTERVAL - seconds between samples (NaN if not a waveform)
%     TOTAL_SAMPLES  - estimated number of samples in the channel
%     TOTAL_TIME     - estimated duration of the recording, in seconds
%
%   See also ndr.format.ced.sonpipe.read_SOMSMR_header, ndr.format.ced.sonpipe.read_SOMSMR_datafile

	txt = invoke_text(sprintf('sampleinterval "%s" -c %d', filename, channel_number));
	r = jsondecode(txt);

	sampleinterval = emptytonan(r.sampleinterval);
	total_samples  = emptytonan(r.total_samples);
	total_time     = emptytonan(r.total_time);
end

function v = emptytonan(v)
	if isempty(v)
		v = NaN;
	end
end
