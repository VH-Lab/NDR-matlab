function ci = channelinfo(header, channel_number)
% SONPIPE.CHANNELINFO - Look up one channel's entry in a sonpipe header
%
%   CI = ndr.format.ced.sonpipe.channelinfo(HEADER, CHANNEL_NUMBER)
%
%   Returns the element of HEADER.channelinfo whose 'number' field equals the
%   1-based Spike2 CHANNEL_NUMBER. HEADER is the struct returned by
%   ndr.format.ced.sonpipe.read_SOMSMR_header. Errors if the channel is not present.
%
%   See also ndr.format.ced.sonpipe.read_SOMSMR_header

	arguments
		header
		channel_number {mustBeNumeric}
	end

	if isempty(header) || ~isfield(header, 'channelinfo') || isempty(header.channelinfo)
		error('sonpipe:noChannels', 'The header contains no channels.');
	end
	numbers = [header.channelinfo.number];
	idx = find(numbers == channel_number, 1);
	if isempty(idx)
		error('sonpipe:noChannel', ...
			'Channel number %d is not recorded in this file.', channel_number);
	end
	ci = header.channelinfo(idx);
end
