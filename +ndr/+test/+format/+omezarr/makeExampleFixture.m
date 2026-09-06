function fixtureDir = makeExampleFixture(parentDir)
% ndr.test.format.omezarr.makeExampleFixture - write a dual-pyramid fixture
%
%   FIXTUREDIR = ndr.test.format.omezarr.MAKEEXAMPLEFIXTURE()
%   FIXTUREDIR = ndr.test.format.omezarr.MAKEEXAMPLEFIXTURE(PARENTDIR)
%
%   Builds a metadata-only OME-Zarr store on disk that mirrors the lab
%   dual-pyramid layout from
%   ferret-lightsheet/formats/OurUsualZarrFormat.md: one shared level-0
%   array plus separate "mean" and "max" downsample chains. No chunk
%   bytes are written; only .zattrs, .zgroup, and .zarray files. This
%   is enough for the discovery/metadata layer in +format/+omezarr and
%   avoids committing binary fixtures to the repo.
%
%   PARENTDIR defaults to a fresh directory under tempdir.

    if nargin < 1 || isempty(parentDir)
        parentDir = tempname;
        mkdir(parentDir);
    end
    fixtureDir = fullfile(parentDir, 'example.zarr');
    if isfolder(fixtureDir)
        rmdir(fixtureDir, 's');
    end
    mkdir(fixtureDir);

    % Shape and chunks: (c, z, y, x) with 4 microns isotropic at level 0
    shape0  = [1 256 256 256];
    chunks  = [1 256 256 256];
    dtype   = '<u2';

    levelShapes = { shape0, ...
                    [1 128 128 128], ...
                    [1  64  64  64] };
    levelChunks = { chunks, chunks, chunks };

    writeZGroup(fixtureDir);

    writeZArray(fullfile(fixtureDir, '0'), levelShapes{1}, levelChunks{1}, dtype);

    meanDir = fullfile(fixtureDir, 'mean');
    mkdir(meanDir);
    writeZGroup(meanDir);
    writeZArray(fullfile(meanDir, '1'), levelShapes{2}, levelChunks{2}, dtype);
    writeZArray(fullfile(meanDir, '2'), levelShapes{3}, levelChunks{3}, dtype);

    maxDir  = fullfile(fixtureDir, 'max');
    mkdir(maxDir);
    writeZGroup(maxDir);
    writeZArray(fullfile(maxDir, '1'), levelShapes{2}, levelChunks{2}, dtype);
    writeZArray(fullfile(maxDir, '2'), levelShapes{3}, levelChunks{3}, dtype);

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
        'filters', []);
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
