function h = header(container)
% ndr.format.blosc.header - parse a Blosc v1 container header, no decode.
%
%   H = ndr.format.blosc.header(CONTAINER)
%
%   Returns a struct describing the 16-byte header of the Blosc v1
%   CONTAINER. Metadata-only: no chunks are decompressed and no
%   subprocess is invoked, so this is cheap enough to call once per
%   chunk during inspection.
%
%   Fields:
%     version    - uint8, container format version (1 or 2)
%     versionlz  - uint8, LZ sub-version
%     flags      - uint8: bit 0 = byte-shuffle,
%                          bit 1 = memcpy fast-path,
%                          bit 2 = bit-shuffle
%     hasByteShuffle - logical
%     hasBitShuffle  - logical
%     isMemcpyed     - logical
%     typesize   - double, element size the shuffle was applied over
%     nbytes     - double, uncompressed payload length
%     blocksize  - double, block granularity
%     cbytes     - double, total container length (header + offsets + blocks)
%
%   The codec identity (zstd, lz4, ...) is NOT reported here: the Blosc
%   header encodes it in the top nibble of the flags byte and the
%   encoding has drifted across Blosc versions. Zarr stores name the
%   codec in .zarray.compressor.cname, and callers who need it should
%   read that. numcodecs.Blosc.decode itself resolves the codec off the
%   header, so decode() does not need this either.
%
%   See also: ndr.format.blosc.isBlosc, ndr.format.blosc.decode.

    if ~isa(container, 'uint8')
        container = typecast(container(:), 'uint8');
    end
    container = container(:);
    if numel(container) < 16
        error('ndr:format:blosc:header:Truncated', ...
            'Container is only %d bytes; header needs 16.', numel(container));
    end
    hdr = container(1:16);
    version   = hdr(1);
    versionlz = hdr(2);
    flags     = hdr(3);
    typesize  = double(hdr(4));

    nbytes    = double(typecast(hdr(5:8),   'uint32'));
    blocksize = double(typecast(hdr(9:12),  'uint32'));
    cbytes    = double(typecast(hdr(13:16), 'uint32'));

    hasByteShuffle = bitand(flags, uint8(1)) ~= 0;
    isMemcpyed     = bitand(flags, uint8(2)) ~= 0;
    hasBitShuffle  = bitand(flags, uint8(4)) ~= 0;

    h = struct( ...
        'version',        version, ...
        'versionlz',      versionlz, ...
        'flags',          flags, ...
        'hasByteShuffle', hasByteShuffle, ...
        'hasBitShuffle',  hasBitShuffle, ...
        'isMemcpyed',     isMemcpyed, ...
        'typesize',       typesize, ...
        'nbytes',         nbytes, ...
        'blocksize',      blocksize, ...
        'cbytes',         cbytes);
end
