function chunk = readChunk(arrayDir, chunkIndex, meta)
% readChunk - read and decode one chunk file into a MATLAB array shaped
% like meta.chunks. Returns fill_value for a missing chunk file (a legal
% Zarr sparse store).
%
%   CHUNK = readChunk(ARRAYDIR, CHUNKINDEX, META)
%
%   CHUNKINDEX is a 0-based row vector, one entry per axis, in shape
%   order. META is the struct returned by readZArrayMeta.
%
%   Returns a MATLAB array of size META.chunks and class META.dtypeInfo.mlType.
%   The array is oriented so that CHUNK(i1,i2,...,in) is the element the
%   Python/numpy view would see at the same 1-based index; that requires
%   flipping the shape and permuting because Zarr uses C-order on disk
%   while MATLAB is column-major.

    key = chunkKey(chunkIndex, meta.dimSep);
    chunkFile = fullfile(arrayDir, key);

    chunkShape = meta.chunks;
    nelems     = prod(chunkShape);

    if ~isfile(chunkFile)
        chunk = repmat(meta.fillValue, chunkShape);
        return;
    end

    fid = fopen(chunkFile, 'rb');
    if fid < 0
        error('ndr:format:omezarr:readArray:ChunkOpenFailed', ...
            'Could not open chunk file %s.', chunkFile);
    end
    cleanFile = onCleanup(@() fclose(fid));
    raw = fread(fid, inf, '*uint8');

    if isempty(meta.compressorName)
        decompressed = raw;
        expectedBytes = nelems * meta.dtypeInfo.itemBytes;
        if numel(decompressed) ~= expectedBytes
            error('ndr:format:omezarr:readArray:UncompressedChunkSize', ...
                ['Uncompressed chunk %s is %d bytes; expected %d ' ...
                 'for shape [%s] * %d bytes.'], ...
                chunkFile, numel(decompressed), expectedBytes, ...
                num2str(chunkShape), meta.dtypeInfo.itemBytes);
        end
    else
        decompressed = decompressBlosc(raw, meta.compressorName);
    end

    if meta.dtypeInfo.needSwap
        decompressed = swapBytes(decompressed, meta.dtypeInfo.itemBytes);
    end

    linear = typecast(decompressed, meta.dtypeInfo.mlType);
    if numel(linear) ~= nelems
        error('ndr:format:omezarr:readArray:ChunkElementCountMismatch', ...
            ['Chunk %s decoded to %d elements of %s; expected %d ' ...
             '(shape [%s]).'], ...
            chunkFile, numel(linear), meta.dtypeInfo.mlType, nelems, ...
            num2str(chunkShape));
    end

    % Zarr writes C-order (last axis fastest). Reshape to reversed shape
    % as a Fortran-order matrix, then permute to get an array indexed
    % the same way numpy would index it.
    if numel(chunkShape) == 1
        chunk = reshape(linear, chunkShape, 1);
    else
        chunk = permute(reshape(linear, flip(chunkShape)), ...
                        numel(chunkShape):-1:1);
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
