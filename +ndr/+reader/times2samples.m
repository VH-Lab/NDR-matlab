function s = times2samples(ndr_reader_base_obj, channeltype, channel, epochstreams, epoch_select, t)
% TIMES2SAMPLES - convert time to sample numbers
%
% S = TIMES2SAMPLES(NDR_READER_BASE_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T)
%
% Given sample times T, returns the sample numbers S of these samples.
%
% This function calls the times2samples method of the ndr.reader.base object.
%
% See also: ndr.reader.base/times2samples
%

arguments
    ndr_reader_base_obj (1,1) ndr.reader.base
    channeltype (1,:) char
    channel (1,:) double
    epochstreams (1,:) cell
    epoch_select (1,1) double
    t (1,:) double
end

s = ndr_reader_base_obj.times2samples(channeltype, channel, epochstreams, epoch_select, t);

end
