function pyramids = listPyramids(zarrPath)
% ndr.format.omezarr.listPyramids - enumerate pyramids in an OME-Zarr store
%
%   PYRAMIDS = ndr.format.omezarr.LISTPYRAMIDS(ZARRPATH)
%
%   Returns a struct array with one entry per NGFF `multiscales` entry
%   in <ZARRPATH>/.zattrs. Fields per entry:
%
%     name        - char, from multiscales(i).name. May be empty.
%     type        - char, from multiscales(i).type. Descriptive only --
%                   for the lab layout this is "box" for mean and "max"
%                   for max, but the field's history includes wrong
%                   values (a previous writer labeled the mean pyramid
%                   "gaussian"). Do not switch behavior on it.
%     axes        - struct array of axis descriptors as they appear in
%                   NGFF: fields `name`, `type`, `unit` (any of which
%                   may be missing in the source and come back empty).
%     levels      - struct array, one entry per resolution level, with
%                   fields:
%                     path         - char, the dataset path as written
%                                    in .zattrs (e.g. '0', 'mean/1')
%                     shape        - numeric row vector, from the
%                                    array's .zarray
%                     chunks       - numeric row vector, from .zarray
%                     dtype        - char, from .zarray (e.g. '<u2')
%                     scale        - numeric row vector, the level's
%                                    coordinate scale
%                     translation  - numeric row vector, the level's
%                                    coordinate translation (0s if the
%                                    file has none)
%
%   Pyramid selection everywhere else in this package is by NAME. This
%   function is the source of truth for what names exist.
%
%   The shared-level-0 case (both pyramids' first entry points at the
%   same path, typically '0') is represented honestly: both entries'
%   levels(1).path is the same string, and resolveArrayPath will resolve
%   them to the same directory. Nothing here special-cases it.

    attrs = ndr.format.omezarr.readAttrs(zarrPath);

    if ~isfield(attrs, 'multiscales')
        error('ndr:format:omezarr:listPyramids:NoMultiscales', ...
            '.zattrs in %s has no multiscales field.', zarrPath);
    end

    msRaw = attrs.multiscales;
    if isstruct(msRaw)
        ms = msRaw(:);
    elseif iscell(msRaw)
        ms = msRaw;
    else
        error('ndr:format:omezarr:listPyramids:BadMultiscales', ...
            'multiscales must be a JSON array; got %s.', class(msRaw));
    end

    n = numel(ms);
    pyramids = repmat(struct('name', '', 'type', '', 'axes', struct([]), ...
        'levels', struct([])), n, 1);

    zarrPathChar = char(zarrPath);

    for i = 1:n
        entry = getEntry(ms, i);
        pyramids(i).name   = getCharField(entry, 'name');
        pyramids(i).type   = getCharField(entry, 'type');
        pyramids(i).axes   = normalizeAxes(entry);
        pyramids(i).levels = normalizeLevels(entry, zarrPathChar);
    end
end

function entry = getEntry(ms, i)
    if iscell(ms)
        entry = ms{i};
    else
        entry = ms(i);
    end
end

function v = getCharField(s, name)
    if isfield(s, name) && ~isempty(s.(name))
        v = char(s.(name));
    else
        v = '';
    end
end

function axesOut = normalizeAxes(entry)
    axesOut = struct('name', {}, 'type', {}, 'unit', {});
    if ~isfield(entry, 'axes') || isempty(entry.axes)
        return;
    end
    ax = entry.axes;
    if isstruct(ax)
        ax = num2cell(ax(:));
    end
    for j = 1:numel(ax)
        a = ax{j};
        axesOut(j).name = getCharField(a, 'name');
        axesOut(j).type = getCharField(a, 'type');
        axesOut(j).unit = getCharField(a, 'unit');
    end
end

function levelsOut = normalizeLevels(entry, zarrPathChar)
    levelsOut = struct('path', {}, 'shape', {}, 'chunks', {}, ...
        'dtype', {}, 'scale', {}, 'translation', {});

    if ~isfield(entry, 'datasets') || isempty(entry.datasets)
        return;
    end

    ds = entry.datasets;
    if isstruct(ds)
        ds = num2cell(ds(:));
    end

    for k = 1:numel(ds)
        d = ds{k};
        pathStr = getCharField(d, 'path');
        levelsOut(k).path = pathStr;

        [scale, translation] = extractCoordinateTransforms(d);
        levelsOut(k).scale = scale;
        levelsOut(k).translation = translation;

        arrayDir = fullfile(zarrPathChar, strrep(pathStr, '/', filesep));
        [shape, chunks, dtype] = readZArrayMeta(arrayDir);
        levelsOut(k).shape  = shape;
        levelsOut(k).chunks = chunks;
        levelsOut(k).dtype  = dtype;
    end
end

function [scale, translation] = extractCoordinateTransforms(d)
    scale = [];
    translation = [];
    if ~isfield(d, 'coordinateTransformations') || ...
            isempty(d.coordinateTransformations)
        return;
    end
    ct = d.coordinateTransformations;
    if isstruct(ct)
        ct = num2cell(ct(:));
    end
    for m = 1:numel(ct)
        c = ct{m};
        if ~isfield(c, 'type')
            continue;
        end
        switch char(c.type)
            case 'scale'
                if isfield(c, 'scale')
                    scale = reshape(double(c.scale), 1, []);
                end
            case 'translation'
                if isfield(c, 'translation')
                    translation = reshape(double(c.translation), 1, []);
                end
        end
    end
    if isempty(translation) && ~isempty(scale)
        translation = zeros(1, numel(scale));
    end
end

function [shape, chunks, dtype] = readZArrayMeta(arrayDir)
    shape = [];
    chunks = [];
    dtype = '';
    zarrayPath = fullfile(arrayDir, '.zarray');
    if ~isfile(zarrayPath)
        return;
    end
    try
        raw = fileread(zarrayPath);
        meta = jsondecode(raw);
    catch
        return;
    end
    if isfield(meta, 'shape')
        shape = reshape(double(meta.shape), 1, []);
    end
    if isfield(meta, 'chunks')
        chunks = reshape(double(meta.chunks), 1, []);
    end
    if isfield(meta, 'dtype')
        dtype = char(meta.dtype);
    end
end
