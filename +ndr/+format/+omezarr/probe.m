function info = probe(zarrPath)
% ndr.format.omezarr.probe - cheap metadata probe of an OME-Zarr store
%
%   INFO = NDR.FORMAT.OMEZARR.PROBE(ZARRPATH)
%
%   Returns a struct summarising an OME-Zarr (NGFF v0.4) store without
%   reading a single chunk. The intended caller is an ingest / GUI
%   confirmation screen that needs "should we accept this?" info before
%   the user commits.
%
%   Fields:
%     ok           - logical; false if the directory does not parse as
%                    an OME-Zarr store. All other fields are then empty.
%     nPyramids    - number of `multiscales` entries.
%     pyramidNames - cellstr, name per entry (may contain '' entries).
%     pyramidTypes - cellstr, type per entry.
%     axesOrder    - char, e.g. 'tczyx', from the first pyramid.
%     axesUnits    - cellstr, per-axis unit strings from the first
%                    pyramid.
%     level0Shape  - numeric vector, level-0 shape from the first
%                    pyramid.
%     level0Chunks - numeric vector, level-0 chunk shape.
%     level0Scale  - numeric vector, level-0 voxel size in axesUnits.
%     dtype        - char, level-0 dtype string.
%     nLevelsPerPyramid - numeric vector, level count per pyramid.
%
%   The pyramid this reports level-0 metadata for is the FIRST
%   multiscales entry; a store with mean and max pyramids typically has
%   both entries share the same level-0 array (NGFF's `path` is the
%   same string) so any first-pyramid metadata is enough for a
%   confirmation dialog.
%
%   For anything that has to distinguish pyramids or reach deeper
%   levels, use NDR.FORMAT.OMEZARR.LISTPYRAMIDS instead; this function
%   is a lightweight shortcut.
%
%   See also: ndr.format.omezarr.isOMEZarr, ndr.format.omezarr.listPyramids

    arguments
        zarrPath (1,:) char
    end

    info = struct( ...
        'ok', false, ...
        'nPyramids', 0, ...
        'pyramidNames', {{}}, ...
        'pyramidTypes', {{}}, ...
        'axesOrder', '', ...
        'axesUnits', {{}}, ...
        'level0Shape', [], ...
        'level0Chunks', [], ...
        'level0Scale', [], ...
        'dtype', '', ...
        'nLevelsPerPyramid', []);

    if ~isfolder(zarrPath) || ~ndr.format.omezarr.isOMEZarr(zarrPath)
        return;
    end

    pyramids = ndr.format.omezarr.listPyramids(zarrPath);
    if isempty(pyramids)
        return;
    end

    info.ok = true;
    info.nPyramids = numel(pyramids);
    info.pyramidNames = arrayfun(@(p) char(p.name), pyramids, 'UniformOutput', false);
    info.pyramidTypes = arrayfun(@(p) char(p.type), pyramids, 'UniformOutput', false);

    axes = pyramids(1).axes;
    if ~isempty(axes)
        info.axesOrder = strjoin(arrayfun(@(a) char(a.name), axes, ...
            'UniformOutput', false), '');
        info.axesUnits = arrayfun(@(a) char(a.unit), axes, ...
            'UniformOutput', false);
    end

    levels = pyramids(1).levels;
    if ~isempty(levels)
        info.level0Shape  = reshape(double(levels(1).shape), 1, []);
        info.level0Chunks = reshape(double(levels(1).chunks), 1, []);
        info.level0Scale  = reshape(double(levels(1).scale), 1, []);
        info.dtype        = char(levels(1).dtype);
    end

    info.nLevelsPerPyramid = arrayfun(@(p) numel(p.levels), pyramids);
end
