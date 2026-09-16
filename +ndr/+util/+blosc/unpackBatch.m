function items = unpackBatch(body)
% ndr.util.blosc.unpackBatch - deserialize the packBatch wire format
%
%   ITEMS = ndr.util.blosc.UNPACKBATCH(BODY)
%
%   Inverse of ndr.util.blosc.packBatch. Returns ITEMS as a
%   1-by-N cell array of uint8 column vectors.

    if ~isa(body, 'uint8')
        body = typecast(body(:), 'uint8');
    end
    body = body(:);
    if numel(body) < 4
        error('ndr:util:blosc:unpackBatch:BodyTooShort', ...
            'response body is %d bytes; need at least 4 for the count.', ...
            numel(body));
    end
    n = double(typecast(body(1:4), 'uint32'));
    items = cell(1, n);
    off = 4;
    for i = 1:n
        if off + 8 > numel(body)
            error('ndr:util:blosc:unpackBatch:LengthOOB', ...
                'item %d length header runs past end of body.', i);
        end
        len = double(typecast(body(off + 1 : off + 8), 'uint64'));
        off = off + 8;
        if off + len > numel(body)
            error('ndr:util:blosc:unpackBatch:BodyOOB', ...
                'item %d body runs past end of buffer.', i);
        end
        items{i} = body(off + 1 : off + len);
        off = off + len;
    end
end
