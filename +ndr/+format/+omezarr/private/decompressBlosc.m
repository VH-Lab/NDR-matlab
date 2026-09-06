function bytesOut = decompressBlosc(bytesIn, compressorName)
% decompressBlosc - decode a Blosc v1 container to raw bytes.
%
%   BYTESOUT = decompressBlosc(BYTESIN, COMPRESSORNAME)
%
%   BYTESIN is a uint8 column vector holding the on-disk contents of a
%   Blosc-compressed chunk. COMPRESSORNAME is a char row telling the
%   function which codec to hand each block to; it comes from the
%   .zarray's `compressor.cname` field. Only 'zstd' is supported here.
%
%   The Blosc container format is well-defined; this function reads the
%   16-byte header, walks the per-block offset table, hands each block
%   payload to the codec, then re-assembles and un-shuffles bytes.
%
%   Return value is a uint8 column vector of length header.nbytes.
%
%   Only the shape actually written by the lab is supported:
%     * flags & 0x02 (MEMCPY): accepted -- the payload is raw bytes
%       already, no codec is invoked, no shuffle is undone (Blosc leaves
%       memcpy'd data unshuffled even when the shuffle bit is set).
%     * flags & 0x01 (byte shuffle): supported -- un-shuffled by
%       typesize after each block is decompressed.
%     * flags & 0x04 (bit shuffle): errors, because the lab does not use
%       it and getting it wrong silently would be a bad failure mode.
%
%   The codec code encoded in the top bits of the flags byte is
%   deliberately ignored. The .zarray's compressor.cname is the source of
%   truth for which codec was used, and the flags-byte encoding of codec
%   id has never been fully standardized across Blosc versions -- reading
%   from .zarray avoids that ambiguity entirely.

    if ~isa(bytesIn, 'uint8')
        bytesIn = typecast(bytesIn(:), 'uint8');
    end
    bytesIn = bytesIn(:);
    n = numel(bytesIn);
    if n < 16
        error('ndr:format:omezarr:readArray:BloscHeaderTruncated', ...
            'Blosc container is only %d bytes; header needs 16.', n);
    end

    hdr = bytesIn(1:16);
    version = hdr(1);
    if version < 1 || version > 2
        error('ndr:format:omezarr:readArray:BloscVersionUnsupported', ...
            ['Unsupported Blosc header version %d. Only v1/v2 ' ...
             '(Blosc1) containers are supported.'], double(version));
    end
    flags    = hdr(3);
    typesize = double(hdr(4));

    nbytes    = double(typecast(hdr(5:8),   'uint32'));
    blocksize = double(typecast(hdr(9:12),  'uint32'));
    cbytes    = double(typecast(hdr(13:16), 'uint32'));

    if cbytes ~= n
        error('ndr:format:omezarr:readArray:BloscSizeMismatch', ...
            'Blosc header reports cbytes=%d but chunk file has %d bytes.', ...
            cbytes, n);
    end

    hasByteShuffle = bitand(flags, uint8(1)) ~= 0;
    isMemcpyed     = bitand(flags, uint8(2)) ~= 0;
    hasBitShuffle  = bitand(flags, uint8(4)) ~= 0;

    if hasBitShuffle
        error('ndr:format:omezarr:readArray:UnsupportedBitshuffle', ...
            ['Blosc chunk uses bit-shuffle (flags=0x%02x). Only ' ...
             'byte-shuffle (or no shuffle) is supported.'], double(flags));
    end

    if isMemcpyed
        % Payload is the raw bytes; shuffle is NOT applied even when the
        % shuffle bit is set on this branch.
        payload = bytesIn(17:end);
        if numel(payload) ~= nbytes
            error('ndr:format:omezarr:readArray:MemcpySizeMismatch', ...
                ['Memcpy'' Blosc chunk payload is %d bytes; header ' ...
                 'nbytes=%d.'], numel(payload), nbytes);
        end
        bytesOut = payload;
        return;
    end

    if nbytes == 0
        bytesOut = zeros(0, 1, 'uint8');
        return;
    end
    if blocksize <= 0
        error('ndr:format:omezarr:readArray:BadBlocksize', ...
            'Blosc header reports blocksize=%d.', blocksize);
    end

    nblocks = ceil(nbytes / blocksize);
    if numel(bytesIn) < 16 + 4 * nblocks
        error('ndr:format:omezarr:readArray:OffsetsTruncated', ...
            ['Blosc container needs %d bytes for the offset table ' ...
             '(%d blocks); only %d bytes remain after the header.'], ...
            4 * nblocks, nblocks, numel(bytesIn) - 16);
    end
    offsets = typecast(bytesIn(17 : 16 + 4*nblocks), 'uint32');

    bytesOut = zeros(nbytes, 1, 'uint8');
    for b = 1:nblocks
        blockStart = double(offsets(b)) + 1;  % 1-based
        if blockStart + 4 - 1 > numel(bytesIn)
            error('ndr:format:omezarr:readArray:BlockHeaderTruncated', ...
                'Block %d header runs past the end of the chunk.', b);
        end
        blockCbytes = double(typecast(bytesIn(blockStart : blockStart+3), 'uint32'));
        payloadStart = blockStart + 4;
        payloadEnd   = payloadStart + blockCbytes - 1;
        if payloadEnd > numel(bytesIn)
            error('ndr:format:omezarr:readArray:BlockPayloadTruncated', ...
                ['Block %d payload (%d bytes) runs past the end ' ...
                 'of the chunk.'], b, blockCbytes);
        end
        payload = bytesIn(payloadStart : payloadEnd);

        thisBlockNbytes = min(blocksize, nbytes - (b-1)*blocksize);

        switch lower(compressorName)
            case 'zstd'
                block = decompressZstd(payload, thisBlockNbytes);
            otherwise
                error('ndr:format:omezarr:readArray:UnsupportedCodec', ...
                    ['Blosc codec "%s" is not supported. Only "zstd" ' ...
                     'is supported.'], compressorName);
        end

        if numel(block) ~= thisBlockNbytes
            error('ndr:format:omezarr:readArray:BlockSizeMismatch', ...
                ['Block %d decompressed to %d bytes; expected %d ' ...
                 '(block %d of %d, header blocksize=%d, nbytes=%d).'], ...
                b, numel(block), thisBlockNbytes, b, nblocks, ...
                blocksize, nbytes);
        end

        if hasByteShuffle && typesize > 1
            block = unshuffleBytes(block, typesize);
        end

        destStart = (b-1) * blocksize + 1;
        destEnd   = destStart + thisBlockNbytes - 1;
        bytesOut(destStart:destEnd) = block;
    end
end

function out = unshuffleBytes(in, typesize)
% Reverse Blosc's byte-shuffle: given a block whose bytes were rearranged
% so that all first-bytes come first, then all second-bytes, etc., put
% them back into interleaved element order.
    in = in(:);
    n  = numel(in);
    if mod(n, typesize) ~= 0
        error('ndr:format:omezarr:readArray:UnshuffleBadSize', ...
            'Block length %d is not a multiple of typesize %d.', ...
            n, typesize);
    end
    nelems = n / typesize;
    % Reshape: rows = typesize (each row is one byte-lane, length = nelems)
    % Blosc lays them out as [byte0 for all elems][byte1 for all elems]...
    % which is typesize x nelems in row-major, i.e. shape (typesize, nelems)
    % after reshape([typesize nelems]) in Fortran order.
    lanes = reshape(in, nelems, typesize).';  % (typesize, nelems)
    out = reshape(lanes, [], 1);              % interleaved element bytes
end
