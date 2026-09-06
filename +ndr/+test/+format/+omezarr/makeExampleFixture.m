function [fixtureDir, groundTruth] = makeExampleFixture(parentDir, options)
% ndr.test.format.omezarr.makeExampleFixture - write a dual-pyramid fixture
%
%   FIXTUREDIR = ndr.test.format.omezarr.MAKEEXAMPLEFIXTURE()
%   FIXTUREDIR = ndr.test.format.omezarr.MAKEEXAMPLEFIXTURE(PARENTDIR)
%   [FIXTUREDIR, GROUNDTRUTH] = ndr.test.format.omezarr.MAKEEXAMPLEFIXTURE(
%       PARENTDIR, 'WithChunks', true)
%
%   Builds an OME-Zarr store on disk that mirrors the lab dual-pyramid
%   layout from ferret-lightsheet/formats/OurUsualZarrFormat.md: one
%   shared level-0 array plus separate "mean" and "max" downsample
%   chains.
%
%   By default (WithChunks=false), only metadata files are written --
%   .zattrs, .zgroup, and .zarray. That is enough for the discovery
%   layer in +format/+omezarr (isOMEZarr, readAttrs, listPyramids,
%   resolveArrayPath) and keeps no binary in the repo.
%
%   With WithChunks=true, this ALSO writes real Blosc+Zstd-compressed
%   chunk files with a deterministic content (a seeded uint16 volume)
%   and returns the ground-truth arrays in GROUNDTRUTH so tests can
%   compare a readArray result against them byte-for-byte. Chunk shapes
%   are chosen so the shape is NOT an integer multiple of the chunk
%   size along the spatial axes: this exercises the edge-chunk path
%   (last chunk on each axis is smaller than the chunk shape and padded
%   with fill_value on disk).
%
%   The chunk-writing path calls the system `zstd` binary via
%   private/encodeBlosc + private/compressZstd. If zstd is not on PATH,
%   WithChunks=true raises the same "install zstd" error the reader
%   would; there is deliberately no silent fallback to uncompressed
%   chunks, because a reader that only exercised the uncompressed path
%   would prove nothing about the Blosc+Zstd path the lab actually
%   writes.
%
%   PARENTDIR defaults to a fresh directory under tempdir. Pass '' to
%   accept the default while still passing WithChunks.
%
%   GROUNDTRUTH is a struct with fields:
%     level0        - the seeded uint16 volume, shape [1 Z Y X]
%     meanLevel1    - 2x-downsampled mean pyramid, shape [1 Z/2 Y/2 X/2]
%     maxLevel1     - 2x-downsampled max pyramid, same shape
%     meanLevel2    - 4x-downsampled mean
%     maxLevel2     - 4x-downsampled max
%     shape0        - level-0 shape row vector
%     chunkShape0   - level-0 chunk shape row vector
%     dtype         - '<u2'

    arguments
        parentDir char = ''
        options.WithChunks (1,1) logical = false
        options.Seed (1,1) double = 20260906
    end

    if isempty(parentDir)
        parentDir = tempname;
        mkdir(parentDir);
    end
    fixtureDir = fullfile(parentDir, 'example.zarr');
    if isfolder(fixtureDir)
        rmdir(fixtureDir, 's');
    end
    mkdir(fixtureDir);

    dtype = '<u2';

    if options.WithChunks
        % Small, but with axes that are NOT multiples of the chunk size
        % on at least one spatial axis so the last chunk along that axis
        % is an edge chunk. This is the case the read path most easily
        % gets wrong.
        shape0  = [1 8 8 10];
        chunks0 = [1 4 4 4];   % x: 10 into chunks of 4 -> 3 chunks (4+4+2 edge)
        shape1  = [1 4 4 5];
        chunks1 = [1 4 4 4];   % edge on x still (5 into 4 -> 2 chunks: 4+1 edge)
        shape2  = [1 2 2 3];
        chunks2 = [1 4 4 4];
    else
        shape0  = [1 256 256 256];
        chunks0 = [1 256 256 256];
        shape1  = [1 128 128 128];
        chunks1 = shape1;
        shape2  = [1  64  64  64];
        chunks2 = shape2;
    end

    writeZGroup(fixtureDir);

    writeZArray(fullfile(fixtureDir, '0'), shape0, chunks0, dtype);

    meanDir = fullfile(fixtureDir, 'mean');
    mkdir(meanDir);
    writeZGroup(meanDir);
    writeZArray(fullfile(meanDir, '1'), shape1, chunks1, dtype);
    writeZArray(fullfile(meanDir, '2'), shape2, chunks2, dtype);

    maxDir  = fullfile(fixtureDir, 'max');
    mkdir(maxDir);
    writeZGroup(maxDir);
    writeZArray(fullfile(maxDir, '1'), shape1, chunks1, dtype);
    writeZArray(fullfile(maxDir, '2'), shape2, chunks2, dtype);

    axes = { ...
        struct('name', 'c', 'type', 'channel'), ...
        struct('name', 'z', 'type', 'space', 'unit', 'micrometer'), ...
        struct('name', 'y', 'type', 'space', 'unit', 'micrometer'), ...
        struct('name', 'x', 'type', 'space', 'unit', 'micrometer') };

    meanDatasets = { ...
        makeDataset('0',      [1 4 4 4]), ...
        makeDataset('mean/1', [1 8 8 8]), ...
        makeDataset('mean/2', [1 16 16 16]) };
    maxDatasets = { ...
        makeDataset('0',      [1 4 4 4]), ...
        makeDataset('max/1',  [1 8 8 8]), ...
        makeDataset('max/2',  [1 16 16 16]) };

    multiscales = { ...
        struct('name', 'mean', 'type', 'box', ...
               'axes', {axes}, 'datasets', {meanDatasets}), ...
        struct('name', 'max',  'type', 'max', ...
               'axes', {axes}, 'datasets', {maxDatasets}) };

    attrs = struct('multiscales', {multiscales});
    writeJSON(fullfile(fixtureDir, '.zattrs'), attrs);

    groundTruth = struct();
    if ~options.WithChunks
        return;
    end

    % Build a deterministic uint16 volume for level 0 and its
    % downsamples. Use a seeded RandStream so the fixture is reproducible
    % without disturbing the caller's random state.
    rs = RandStream('twister', 'Seed', options.Seed);
    lvl0 = randi(rs, 65535, shape0, 'uint16');

    % Downsamples: for THIS fixture only we compute mean and max on
    % 2x2x2 spatial blocks. Edge padding: pad with the boundary value
    % so downsample math stays consistent even on odd extents (matches
    % what the lab writer does via da.pad(..., mode='edge')).
    mean1 = downsampleBlock(lvl0, @mean, dtype);
    max1  = downsampleBlock(lvl0, @max,  dtype);
    mean2 = downsampleBlock(mean1, @mean, dtype);
    max2  = downsampleBlock(max1,  @max,  dtype);

    writeChunks(fullfile(fixtureDir, '0'),      lvl0,  chunks0);
    writeChunks(fullfile(fixtureDir, 'mean/1'), mean1, chunks1);
    writeChunks(fullfile(fixtureDir, 'max/1'),  max1,  chunks1);
    writeChunks(fullfile(fixtureDir, 'mean/2'), mean2, chunks2);
    writeChunks(fullfile(fixtureDir, 'max/2'),  max2,  chunks2);

    groundTruth.level0      = lvl0;
    groundTruth.meanLevel1  = mean1;
    groundTruth.maxLevel1   = max1;
    groundTruth.meanLevel2  = mean2;
    groundTruth.maxLevel2   = max2;
    groundTruth.shape0      = shape0;
    groundTruth.chunkShape0 = chunks0;
    groundTruth.dtype       = dtype;
end

function d = makeDataset(pathStr, scale)
    d = struct( ...
        'path', pathStr, ...
        'coordinateTransformations', ...
            {{ struct('type', 'scale', 'scale', scale) }} );
end

function writeZGroup(dirPath)
    writeJSON(fullfile(dirPath, '.zgroup'), struct('zarr_format', 2));
end

function writeZArray(arrayDir, shape, chunks, dtype)
    if ~isfolder(arrayDir)
        mkdir(arrayDir);
    end
    meta = struct( ...
        'zarr_format', 2, ...
        'shape', shape, ...
        'chunks', chunks, ...
        'dtype', dtype, ...
        'compressor', struct('id', 'blosc', 'cname', 'zstd', ...
                             'clevel', 5, 'shuffle', 1), ...
        'fill_value', 0, ...
        'order', 'C', ...
        'filters', [], ...
        'dimension_separator', '.');
    writeJSON(fullfile(arrayDir, '.zarray'), meta);
end

function writeJSON(path, s)
    txt = jsonencode(s);
    fid = fopen(path, 'w');
    if fid < 0
        error('ndr:test:format:omezarr:makeExampleFixture:OpenFailed', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, txt, 'char');
end

function out = downsampleBlock(vol, reducer, dtype)
    sz = size(vol, 1:4);
    outShape = [sz(1), ...
                ceil(sz(2)/2), ...
                ceil(sz(3)/2), ...
                ceil(sz(4)/2)];
    % Pad odd axes with edge values so 2x coarsening is well-defined.
    padded = vol;
    if mod(sz(2), 2) == 1
        padded = cat(2, padded, padded(:, end, :, :));
    end
    if mod(sz(3), 2) == 1
        padded = cat(3, padded, padded(:, :, end, :));
    end
    if mod(sz(4), 2) == 1
        padded = cat(4, padded, padded(:, :, :, end));
    end
    p = double(padded);
    % Group into 2x2x2 blocks and reduce.
    ps = size(p, 1:4);
    reshaped = reshape(p, ps(1), 2, ps(2)/2, 2, ps(3)/2, 2, ps(4)/2);
    if isequal(reducer, @mean)
        agg = mean(reshaped, [2 4 6]);
    else
        agg = max(reshaped, [], [2 4 6]);
    end
    agg = reshape(agg, ps(1), ps(2)/2, ps(3)/2, ps(4)/2);
    switch dtype
        case '<u2'
            out = uint16(round(agg));
        otherwise
            error('ndr:test:format:omezarr:makeExampleFixture:UnsupportedDType', ...
                'Only <u2 is supported in the fixture builder; got "%s".', dtype);
    end
    % Trim any padding back off (in case padded exceeded outShape*2).
    out = out(1:outShape(1), 1:outShape(2), 1:outShape(3), 1:outShape(4));
end

function writeChunks(arrayDir, vol, chunkShape)
% Split VOL into chunkShape-sized tiles (padded with 0 on the edges),
% Blosc+Zstd-encode each, and write to arrayDir/<c>.<z>.<y>.<x>.
    sz = size(vol, 1:4);
    nChunks = ceil(sz ./ chunkShape);
    typesize = 2;   % uint16
    for c = 0:nChunks(1)-1
        for z = 0:nChunks(2)-1
            for y = 0:nChunks(3)-1
                for x = 0:nChunks(4)-1
                    chunk = zeros(chunkShape, 'uint16');
                    srcS = [c z y x] .* chunkShape + 1;
                    srcE = min(srcS + chunkShape - 1, sz);
                    dstE = srcE - srcS + 1;
                    chunk(1:dstE(1), 1:dstE(2), 1:dstE(3), 1:dstE(4)) = ...
                        vol(srcS(1):srcE(1), srcS(2):srcE(2), ...
                            srcS(3):srcE(3), srcS(4):srcE(4));
                    key = sprintf('%d.%d.%d.%d', c, z, y, x);
                    outPath = fullfile(arrayDir, key);
                    writeBloscZstdChunk(outPath, chunk, typesize);
                end
            end
        end
    end
end

function writeBloscZstdChunk(outPath, chunk, typesize)
% Serialize an n-D uint16 array to C-order bytes, byte-shuffle, wrap in
% one Blosc block, Zstd-compress, and write.
    % Reverse the reader's un-permute: MATLAB column-major -> C-order
    % bytes. permute to swap axes, then reshape to a linear column.
    nd = ndims(chunk);
    % Match the reader's logic: it does permute(reshape(V, flip(shape)), nd:-1:1)
    % to get chunk. So to invert: chunk -> permute(chunk, [nd:-1:1]) -> reshape to
    % flip(shape) -> reshape column -> bytes.
    permuted = permute(chunk, nd:-1:1);   % now indexed [xn ... x1] with x_nd first
    linear = permuted(:);                  % column-major linear
    raw = typecast(linear, 'uint8');
    raw = raw(:);
    nbytes = numel(raw);
    if mod(nbytes, typesize) ~= 0
        error('ndr:test:format:omezarr:makeExampleFixture:BadTypesize', ...
            'Chunk bytes (%d) not a multiple of typesize (%d).', nbytes, typesize);
    end
    shuffled = shuffleBytes(raw, typesize);
    blockPayload = encodeZstdPayload(shuffled);

    blocksize = nbytes;    % one block
    cbytes    = 16 + 4 + 4 + numel(blockPayload);  % header + 1 offset + block cbytes + payload

    hdr = zeros(16, 1, 'uint8');
    hdr(1) = 2;                             % blosc format version
    hdr(2) = 1;                             % versionlz (zstd format version)
    % flags byte: bit 0 = byte shuffle enabled; bits 4 & 7 encode the
    % zstd decoder id (0x10 | 0x80 = 0x90). The MATLAB reader ignores
    % the codec bits and looks up the compressor via .zarray's `cname`,
    % but numcodecs.Blosc validates them, so we set them faithfully so
    % chunks written here interoperate with a Python-side reader too
    % (that's what the symmetry test relies on).
    hdr(3) = uint8(hex2dec('91'));
    hdr(4) = uint8(typesize);
    hdr(5:8)   = typecast(uint32(nbytes),    'uint8');
    hdr(9:12)  = typecast(uint32(blocksize), 'uint8');
    hdr(13:16) = typecast(uint32(cbytes),    'uint8');

    offsetTable = typecast(uint32(16 + 4), 'uint8');   % one offset, points past itself
    blockHeader = typecast(uint32(numel(blockPayload)), 'uint8');

    container = [hdr(:); offsetTable(:); blockHeader(:); blockPayload(:)];

    fid = fopen(outPath, 'wb');
    if fid < 0
        error('ndr:test:format:omezarr:makeExampleFixture:ChunkOpenFailed', ...
            'Could not open %s for writing.', outPath);
    end
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, container, 'uint8');
end

function out = shuffleBytes(bytesIn, typesize)
% Same layout as the reader's unshuffleBytes, inverted: given
% interleaved element bytes, produce [byte0 for all elems | byte1 for
% all elems | ...].
    bytesIn = bytesIn(:);
    n = numel(bytesIn);
    nelems = n / typesize;
    lanes = reshape(bytesIn, typesize, nelems);   % (typesize, nelems)
    out = reshape(lanes.', [], 1);                 % lane-major
end

function payload = encodeZstdPayload(bytesIn)
% Encode bytesIn with the system zstd binary; return raw compressed bytes.
    zstdBin = locateZstdBinary();
    inPath  = [tempname() '.bin'];
    outPath = [tempname() '.zst'];
    cleanup = onCleanup(@() cleanupFiles({inPath, outPath}));
    fid = fopen(inPath, 'wb');
    if fid < 0
        error('ndr:test:format:omezarr:makeExampleFixture:ZstdInputFailed', ...
            'Could not create temp file %s.', inPath);
    end
    fwrite(fid, bytesIn, 'uint8');
    fclose(fid);
    cmd = sprintf('%s -qf -5 --no-check -o %s %s', ...
        shellQuote(zstdBin), shellQuote(outPath), shellQuote(inPath));
    [status, out] = system(cmd);
    if status ~= 0
        error('ndr:test:format:omezarr:makeExampleFixture:ZstdFailed', ...
            'zstd compression failed (exit %d): %s', status, strtrim(out));
    end
    fid = fopen(outPath, 'rb');
    if fid < 0
        error('ndr:test:format:omezarr:makeExampleFixture:ZstdOutputMissing', ...
            'zstd reported success but %s does not exist.', outPath);
    end
    payload = fread(fid, inf, '*uint8');
    fclose(fid);
end

function bin = locateZstdBinary()
    persistent cached
    if ~isempty(cached)
        bin = cached;
        return;
    end
    if ispc
        [s, out] = system('where zstd');
    else
        [s, out] = system('command -v zstd');
    end
    if s == 0
        lines = strsplit(strtrim(out), newline);
        candidate = strtrim(lines{1});
        if ~isempty(candidate) && exist(candidate, 'file') == 2
            cached = candidate;
            bin = cached;
            return;
        end
    end
    error('ndr:test:format:omezarr:makeExampleFixture:ZstdNotFound', ...
        ['The `zstd` executable is required to build the OME-Zarr ' ...
         'chunk fixture and was not found on PATH. Install it: ' ...
         '`apt install zstd` / `brew install zstd`, or download from ' ...
         'https://github.com/facebook/zstd/releases (Windows).']);
end

function s = shellQuote(p)
    if ispc
        s = ['"' p '"'];
    else
        s = ['''' strrep(p, '''', '''\''''') ''''];
    end
end

function cleanupFiles(paths)
    for i = 1:numel(paths)
        p = paths{i};
        if ~isempty(p) && exist(p, 'file') == 2
            try
                delete(p);
            catch
                % best-effort
            end
        end
    end
end
