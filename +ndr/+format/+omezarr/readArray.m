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

    % ---- BATCHED READ + DECODE ------------------------------------
    % Collect every source chunk's file path and destination
    % geometry first (fast, no I/O). Then read all present chunk
    % files' raw bytes into a cell array. Then one call to
    % ndr.format.blosc.decodeMany decodes the whole batch in ONE
    % Python round-trip (or over the persistent server pipe, at
    % zero spawn cost). Finally, reshape/permute/place each decoded
    % buffer into `data`.
    %
    % Doing the decode per-chunk was ~200-500 ms of Python startup
    % per source chunk on macOS. A 2 GB region touching hundreds of
    % source chunks was minutes of pure spawn overhead.
    plans = struct('srcIdx', {}, 'dstIdx', {}, 'chunkFile', {});
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

        plans(end + 1).srcIdx = arrayfun(@(a,b) {a:b}, srcStart, srcStop); %#ok<AGROW>
        plans(end).dstIdx = arrayfun(@(a,b) {a:b}, dstStart, dstStop);
        plans(end).chunkFile = fullfile(arrayDir, ...
            chunkKey(chunkIdx, meta.dimSep));
    end

    present = false(1, numel(plans));
    rawContainers = cell(1, numel(plans));
    for i = 1:numel(plans)
        cf = plans(i).chunkFile;
        if ~isfile(cf)
            continue;
        end
        fid = fopen(cf, 'rb');
        if fid < 0
            error('ndr:format:omezarr:readArray:ChunkOpenFailed', ...
                'Could not open chunk file %s.', cf);
        end
        cleaner = onCleanup(@() fclose(fid));
        rawContainers{i} = fread(fid, inf, '*uint8');
        clear cleaner;
        present(i) = true;
    end

    if ~isempty(meta.compressorName) && any(present)
        toDecode = rawContainers(present);
        decoded  = ndr.format.blosc.decodeMany(toDecode);
        rawContainers(present) = decoded;
    end

    chunkShape = meta.chunks;
    nelems = prod(chunkShape);
    for i = 1:numel(plans)
        plan = plans(i);
        if ~present(i)
            % Missing chunk: fill_value is already in data.
            continue;
        end
        decompressed = rawContainers{i};
        if isempty(meta.compressorName)
            expectedBytes = nelems * meta.dtypeInfo.itemBytes;
            if numel(decompressed) ~= expectedBytes
                error('ndr:format:omezarr:readArray:UncompressedChunkSize', ...
                    ['Uncompressed chunk %s is %d bytes; expected %d ' ...
                     'for shape [%s] * %d bytes.'], ...
                    plan.chunkFile, numel(decompressed), expectedBytes, ...
                    num2str(chunkShape), meta.dtypeInfo.itemBytes);
            end
        end
        if meta.dtypeInfo.needSwap
            decompressed = swapBytes(decompressed, meta.dtypeInfo.itemBytes);
        end
        linear = typecast(decompressed, meta.dtypeInfo.mlType);
        if numel(linear) ~= nelems
            error('ndr:format:omezarr:readArray:ChunkElementCountMismatch', ...
                ['Chunk %s decoded to %d elements of %s; expected %d ' ...
                 '(shape [%s]).'], ...
                plan.chunkFile, numel(linear), meta.dtypeInfo.mlType, ...
                nelems, num2str(chunkShape));
        end
        if isscalar(chunkShape)
            chunk = reshape(linear, chunkShape, 1);
        else
            chunk = permute(reshape(linear, flip(chunkShape)), ...
                            numel(chunkShape):-1:1);
        end
        slab = chunk(plan.srcIdx{:});
        data(plan.dstIdx{:}) = slab;
    end

    if ~isempty(options.OutputType)
        data = cast(data, options.OutputType);
    end
end

function key = chunkKey(chunkIndex, sep)
    parts = arrayfun(@(v) sprintf('%d', v), chunkIndex, 'UniformOutput', false);
    key = strjoin(parts, sep);
end

function out = swapBytes(bytesIn, itemBytes)
    if itemBytes == 1
        out = bytesIn;
        return;
    end
    n = numel(bytesIn);
    if mod(n, itemBytes) ~= 0
        error('ndr:format:omezarr:readArray:SwapBadSize', ...
            'Chunk bytes (%d) not a multiple of itemBytes (%d) for byte-swap.', ...
            n, itemBytes);
    end
    grouped = reshape(bytesIn(:), itemBytes, n / itemBytes);
    grouped = flipud(grouped);
    out = reshape(grouped, [], 1);
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
