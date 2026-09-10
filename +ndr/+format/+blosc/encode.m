function container = encode(bytesIn, options)
% ndr.format.blosc.encode - build a Blosc v1 container from raw bytes.
%
%   CONTAINER = ndr.format.blosc.encode(BYTESIN)
%   CONTAINER = ndr.format.blosc.encode(BYTESIN, 'typesize', N, ...)
%
%   BYTESIN is either a uint8 vector of C-order raw bytes to compress
%   (in which case 'typesize' is required or defaults to 1) or a typed
%   numeric array (uint16, int32, single, ...) whose class supplies
%   `typesize` automatically. Non-vector typed arrays are read in
%   column-major (MATLAB native) order; the caller is responsible for
%   any permutation needed to put bytes into the desired on-disk axis
%   order before calling encode.
%
%   CONTAINER is a uint8 column vector holding one Blosc v1 container,
%   the same on-disk shape Zarr v2 writes when
%     "compressor": {"id":"blosc","cname":"zstd","clevel":N,"shuffle":1}
%
%   Options (Name-Value):
%     typesize  - element size in bytes (1..N). Sets the shuffle stride.
%                 Ignored when BYTESIN is a typed array (its class wins).
%                 Default 0 = infer from BYTESIN's class.
%     cname     - char, inner codec. Default 'zstd'. Other Blosc codecs
%                 ('lz4', 'blosclz', 'snappy') are accepted and passed
%                 through unchanged.
%     clevel    - integer compression level. 1..22 for zstd, 1..9 for
%                 the others. Default 5.
%     shuffle   - 0 = no shuffle, 1 = byte-shuffle, 2 = bit-shuffle.
%                 Default 1.
%     blocksize - target block size in bytes. Default 0 = numcodecs auto.
%
%   Implementation:
%     Delegates to numcodecs.Blosc via a subprocess in a private venv
%     (see ndr.util.blosc.setup). MATLAB's `pyenv` is never touched, so
%     the customer's Python configuration is not affected.
%
%   See also: ndr.format.blosc.decode, ndr.format.blosc.isBlosc,
%             ndr.util.blosc.setup.

    arguments
        bytesIn
        options.typesize (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.cname (1,:) char = 'zstd'
        options.clevel (1,1) double {mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.clevel, 1)} = 5
        options.shuffle (1,1) double {mustBeMember(options.shuffle, [0 1 2])} = 1
        options.blocksize (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    end

    typesize = options.typesize;
    if isa(bytesIn, 'uint8')
        raw = bytesIn(:);
        if typesize == 0
            typesize = 1;
        end
    else
        classSize = elementSize(class(bytesIn));
        if typesize == 0
            typesize = classSize;
        end
        raw = typecast(bytesIn(:), 'uint8');
    end
    if typesize < 1
        error('ndr:format:blosc:encode:BadTypesize', ...
            'typesize must be >= 1 (got %d).', typesize);
    end
    if mod(numel(raw), typesize) ~= 0
        error('ndr:format:blosc:encode:LengthMismatch', ...
            ['Input byte length %d is not a multiple of typesize %d; the ' ...
             'byte-shuffle would leave a partial element.'], ...
            numel(raw), typesize);
    end

    args = sprintf(['encode --cname %s --clevel %d --shuffle %d ' ...
                    '--typesize %d --blocksize %d'], ...
        options.cname, options.clevel, options.shuffle, ...
        typesize, options.blocksize);
    container = ndr.util.blosc.runTool('encode', args, raw);
end

function n = elementSize(cls)
    switch cls
        case {'uint8', 'int8', 'logical'}
            n = 1;
        case {'uint16', 'int16'}
            n = 2;
        case {'uint32', 'int32', 'single'}
            n = 4;
        case {'uint64', 'int64', 'double'}
            n = 8;
        otherwise
            error('ndr:format:blosc:encode:UnknownClass', ...
                ['Class %s has no obvious element size; pass ' ...
                 '''typesize'' explicitly.'], cls);
    end
end
