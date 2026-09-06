function data = readArray(zarrPath, pyramidName, level, options)
% ndr.format.omezarr.readArray - read pixels from an OME-Zarr pyramid.
%
%   DATA = ndr.format.omezarr.READARRAY(ZARRPATH, PYRAMIDNAME, LEVEL)
%   DATA = ndr.format.omezarr.READARRAY(..., 'Region', [start; stop])
%   DATA = ndr.format.omezarr.READARRAY(..., 'OutputType', TYPE)
%
%   Returns an n-D MATLAB array for one region of one pyramid level of
%   the OME-Zarr store at ZARRPATH.
%
%   Positional inputs:
%     ZARRPATH     - directory containing .zattrs (the OME-Zarr store root)
%     PYRAMIDNAME  - one of the names returned by
%                    ndr.format.omezarr.LISTPYRAMIDS. There is no default:
%                    pyramid selection is always explicit, because that
%                    is the silent-failure guard issue #127 named.
%     LEVEL        - 1-based level number. Level 1 is the highest
%                    resolution (the first entry in the pyramid's
%                    `datasets` array).
%
%   Options:
%     'Region'     - 2-by-N numeric matrix [start; stop], each column is
%                    one axis, in the array's stored axis order (typically
%                    c,z,y,x). All values are 1-based and INCLUSIVE, so
%                    [1;shape] reads the whole array along that axis.
%                    Default: the whole array.
%     'OutputType' - char/string; cast the returned array to this MATLAB
%                    class. Default: '' (return the array's native type).
%
%   Scope, and what raises rather than silently returning wrong data:
%     * Zarr v2 stores only. v3 (zarr.json + c/ chunk keys) is not
%       supported and errors.
%     * C-order arrays only. Fortran-order errors.
%     * Blosc container with the Zstd codec, or no compression at all.
%       LZ4, Zlib, and bit-shuffle error clearly rather than being
%       decoded incorrectly.
%     * Numeric fixed-length dtypes: u1/u2/u4/u8, i1/i2/i4/i8, f4/f8.
%     * Both little-endian ('<') and big-endian ('>') storage; bytes are
%       swapped when the file's endian differs from the host.
%
%   The Zstd decoder is the system `zstd` binary. See
%   private/decompressZstd.m for the rationale (no toolbox dependency;
%   no minimum-MATLAB bump; no hand-rolled Zstd; no MEX build step).

    arguments
        zarrPath (1,:) char
        pyramidName (1,:) char
        level (1,1) double {mustBeInteger, mustBePositive}
        options.Region double = []
        options.OutputType (1,:) char = ''
    end

    arrayDir = ndr.format.omezarr.resolveArrayPath(zarrPath, pyramidName, level);
    meta = readZArrayMeta(arrayDir);

    shape  = meta.shape;
    chunks = meta.chunks;
    nd     = numel(shape);

    if isempty(options.Region)
        regionStart = ones(1, nd);
        regionStop  = shape;
    else
        [regionStart, regionStop] = validateRegion(options.Region, shape);
    end

    outShape = regionStop - regionStart + 1;
    outShapeForAlloc = outShape;
    if numel(outShapeForAlloc) < 2
        outShapeForAlloc = [outShapeForAlloc 1];
    end
    if any(outShape < 1)
        data = zeros(outShapeForAlloc, meta.dtypeInfo.mlType);
        if ~isempty(options.OutputType)
            data = cast(data, options.OutputType);
        end
        return;
    end

    data = repmat(meta.fillValue, outShapeForAlloc);

    firstChunk = floor((regionStart - 1) ./ chunks);   % 0-based
    lastChunk  = floor((regionStop  - 1) ./ chunks);   % 0-based
    chunkCounts = lastChunk - firstChunk + 1;
    totalChunks = prod(chunkCounts);

    for linIdx = 0 : totalChunks - 1
        chunkIdx = firstChunk + unravelIndex(linIdx, chunkCounts);

        chunkArrayStart = chunkIdx .* chunks + 1;
        chunkArrayStop  = min((chunkIdx + 1) .* chunks, shape);

        overlapStart = max(chunkArrayStart, regionStart);
        overlapStop  = min(chunkArrayStop,  regionStop);
        if any(overlapStop < overlapStart)
            continue;
        end

        srcStart = overlapStart - chunkArrayStart + 1;
        srcStop  = overlapStop  - chunkArrayStart + 1;
        dstStart = overlapStart - regionStart + 1;
        dstStop  = overlapStop  - regionStart + 1;

        chunk = readChunk(arrayDir, chunkIdx, meta);

        srcIdx = arrayfun(@(a,b) {a:b}, srcStart, srcStop);
        dstIdx = arrayfun(@(a,b) {a:b}, dstStart, dstStop);

        slab = chunk(srcIdx{:});
        data(dstIdx{:}) = slab;
    end

    if ~isempty(options.OutputType)
        data = cast(data, options.OutputType);
    end
end

function idx = unravelIndex(linIdx, counts)
% Convert a 0-based linear index to a 0-based row vector of subscripts
% ordered so the FIRST axis varies fastest. This matches how we
% construct the chunk index range (row-major across axes would also work,
% but first-axis-fastest keeps subscripts contiguous per axis).
    n = numel(counts);
    idx = zeros(1, n);
    remaining = linIdx;
    for d = 1:n
        idx(d) = mod(remaining, counts(d));
        remaining = floor(remaining / counts(d));
    end
end

function [regionStart, regionStop] = validateRegion(region, shape)
    nd = numel(shape);
    if ~(isnumeric(region) && size(region,1) == 2 && size(region,2) == nd)
        error('ndr:format:omezarr:readArray:BadRegion', ...
            ['Region must be a 2-by-%d numeric matrix [start; stop] ' ...
             '(one column per axis in shape order).'], nd);
    end
    regionStart = double(region(1, :));
    regionStop  = double(region(2, :));
    if any(regionStart < 1) || any(regionStart ~= floor(regionStart))
        error('ndr:format:omezarr:readArray:BadRegion', ...
            'Region start values must be positive integers.');
    end
    if any(regionStop < regionStart)
        error('ndr:format:omezarr:readArray:BadRegion', ...
            'Region stop must be >= start on every axis.');
    end
    if any(regionStop > shape)
        error('ndr:format:omezarr:readArray:RegionOutOfBounds', ...
            'Region stop [%s] exceeds array shape [%s].', ...
            num2str(regionStop), num2str(shape));
    end
end
