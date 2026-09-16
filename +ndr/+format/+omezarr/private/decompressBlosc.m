function bytesOut = decompressBlosc(bytesIn, compressorName)
% decompressBlosc - decode a Blosc v1 container to raw bytes.
%
%   BYTESOUT = decompressBlosc(BYTESIN, COMPRESSORNAME)
%
%   BYTESIN is a uint8 column vector holding the on-disk contents of a
%   Blosc-compressed chunk. COMPRESSORNAME is a char row telling the
%   caller which inner codec is expected -- for now it is informational
%   only, since numcodecs reads the codec identity out of the container
%   header and does the right thing regardless.
%
%   Returns a uint8 column vector of length header.nbytes.
%
%   Delegates to ndr.format.blosc.decode, which routes through
%   numcodecs.Blosc.decode in a private venv (see ndr.util.blosc.setup
%   for the venv, and ndr.format.blosc for the public surface). That
%   gives us EVERY Blosc codec (zstd, lz4, lz4hc, blosclz, snappy) plus
%   byte-shuffle, bit-shuffle, and the memcpy fast-path, without
%   reimplementing them one at a time in MATLAB. Zarr v2's default
%   compressor is Blosc/LZ4 (not Zstd), so a reader that only knew
%   Zstd -- as this file used to -- refused a big fraction of real
%   OME-Zarr stores.

    if ~isa(bytesIn, 'uint8')
        bytesIn = typecast(bytesIn(:), 'uint8');
    end
    bytesIn = bytesIn(:);
    if numel(bytesIn) < 16
        error('ndr:format:omezarr:readArray:BloscHeaderTruncated', ...
            'Blosc container is only %d bytes; header needs 16.', numel(bytesIn));
    end
    % compressorName is retained in the signature for API compatibility
    % with older callers, but numcodecs reads codec identity out of the
    % container header directly so we do not need to consult it.
    bytesOut = ndr.format.blosc.decode(bytesIn);
end

