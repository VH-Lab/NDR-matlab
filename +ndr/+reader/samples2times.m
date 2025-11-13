function t = samples2times(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, s)
% SAMPLES2TIMES - convert sample numbers to time
%
% T = SAMPLES2TIMES(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, S)
%
% Given sample numbers S, returns the time T of these samples.
%
% This function calls the samples2times method of the ndr.reader.base object.
%
% See also: ndr.reader.base/samples2times
%

arguments
    ndr_reader_base_obj (1,1) ndr.reader.base
    channeltype (1,:) char
    channel (1,:) double
    epochstreams (1,:) cell
    epoch_select (1,1) double
    s (1,:) double
end

t = ndr_reader_base_obj.samples2times(channeltype, channel, epochstreams, epoch_select, s);

end
