function bytesOut = decode(container)
% ndr.format.blosc.decode - decompress a Blosc v1 container into raw bytes.
%
%   BYTESOUT = ndr.format.blosc.decode(CONTAINER)
%
%   CONTAINER is a uint8 vector holding one Blosc v1 container (the
%   on-disk chunk from a Zarr v2 store that used the Blosc compressor).
%   BYTESOUT is a uint8 column vector of the uncompressed payload, in
%   the same axis order Zarr wrote it in (C-order).
%
%   The typesize used at encode time is read out of the container header
%   by numcodecs and applied automatically; callers do not have to
%   supply it. To interpret the bytes as a typed array, `typecast` them
%   and reshape to the chunk shape as the caller sees fit.
%
%   Implementation:
%     Delegates to the blosc-matlab MEX (a direct C call, no
%     subprocess, ~microseconds per chunk). On first use, the MEX is
%     downloaded from GitHub Releases and cached under prefdir(). If
%     no prebuilt exists for this platform (Linux arm64, macOS Intel)
%     or the download fails, falls back to numcodecs.Blosc via a
%     subprocess in a private venv (ndr.util.blosc.setup). MATLAB's
%     `pyenv` is never touched either way.
%
%   See also: ndr.format.blosc.encode, ndr.format.blosc.isBlosc,
%             ndr.format.blosc.header, ndr.util.blosc.ensureMex.

    if ~isa(container, 'uint8')
        try
            container = typecast(container(:), 'uint8');
        catch ME
            error('ndr:format:blosc:decode:BadInput', ...
                ['CONTAINER must be a uint8 vector (or something ' ...
                 'typecast-able to one). typecast said: %s'], ME.message);
        end
    end
    out = ndr.format.blosc.decodeMany({container(:)});
    bytesOut = out{1};
end
