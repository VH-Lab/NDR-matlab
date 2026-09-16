function body = packBatch(items)
% ndr.util.blosc.packBatch - serialize a cell array of byte vectors
%
%   BODY = ndr.util.blosc.PACKBATCH(ITEMS)
%
%   Wire format (little-endian):
%     4 bytes  uint32 count
%     for each item:
%       8 bytes uint64 length
%       length bytes body
%
%   Matches blosc_tool.py's _read_batch / _write_batch. Kept in this
%   private helper so encodeMany, decodeMany and the persistent
%   server client all agree on one on-the-wire layout.

    n = numel(items);
    % First pass: total size, so we allocate once.
    lengths = zeros(1, n, 'uint64');
    for i = 1:n
        it = items{i};
        if ~isa(it, 'uint8')
            it = typecast(it(:), 'uint8');
            items{i} = it;
        end
        lengths(i) = numel(it);
    end
    total = 4 + 8 * n + double(sum(lengths));
    body = zeros(total, 1, 'uint8');

    body(1:4) = typecast(uint32(n), 'uint8');
    off = 4;
    for i = 1:n
        body(off + 1 : off + 8) = typecast(lengths(i), 'uint8');
        off = off + 8;
        len = double(lengths(i));
        if len > 0
            body(off + 1 : off + len) = items{i}(:);
            off = off + len;
        end
    end
end
