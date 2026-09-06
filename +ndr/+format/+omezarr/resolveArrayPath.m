function arrayPath = resolveArrayPath(zarrPath, pyramidName, level)
% ndr.format.omezarr.resolveArrayPath - map (pyramid,level) to a Zarr array
%
%   ARRAYPATH = ndr.format.omezarr.RESOLVEARRAYPATH(ZARRPATH, PYRAMIDNAME, LEVEL)
%
%   Returns the absolute on-disk directory of the Zarr array for a
%   given pyramid and resolution level.
%
%   PYRAMIDNAME is one of the names returned by
%   ndr.format.omezarr.LISTPYRAMIDS. If the name is not present, this
%   errors with a message listing what is available. This is the
%   silent-failure guard: a reader cannot get the wrong pyramid because
%   two entries were named the same, or because the caller misspelled
%   one; it gets an error naming the choice.
%
%   LEVEL is 1-based (level 1 is the highest resolution -- the first
%   entry in the pyramid's `datasets` array). This matches MATLAB
%   indexing and NDR convention; the NGFF file itself often labels the
%   full-resolution dataset "0", but that is a path string, not an
%   index.
%
%   The shared-level-0 case (both pyramids' first entry points at the
%   same on-disk array) resolves correctly: calling this for
%   `('mean',1)` and `('max',1)` on the lab layout returns the same
%   directory, because both pyramids' datasets(1).path is '0'.

    pyramids = ndr.format.omezarr.listPyramids(zarrPath);
    pyramidName = char(pyramidName);

    names = {pyramids.name};
    idx = find(strcmp(names, pyramidName), 1);
    if isempty(idx)
        error('ndr:format:omezarr:resolveArrayPath:UnknownPyramid', ...
            ['Pyramid "%s" is not in %s. ' ...
             'Available pyramids: %s.'], ...
            pyramidName, zarrPath, formatNameList(names));
    end

    levels = pyramids(idx).levels;
    if ~(isnumeric(level) && isscalar(level) && level == floor(level) && level >= 1)
        error('ndr:format:omezarr:resolveArrayPath:BadLevel', ...
            'level must be a positive integer scalar; got %s.', ...
            mat2str(level));
    end
    if level > numel(levels)
        error('ndr:format:omezarr:resolveArrayPath:LevelOutOfRange', ...
            'Pyramid "%s" has %d level(s); level %d requested.', ...
            pyramidName, numel(levels), level);
    end

    pathStr = levels(level).path;
    arrayPath = fullfile(char(zarrPath), strrep(pathStr, '/', filesep));

    if ~isfolder(arrayPath)
        error('ndr:format:omezarr:resolveArrayPath:ArrayMissing', ...
            ['Metadata for pyramid "%s" level %d points at "%s", ' ...
             'but that directory does not exist.'], ...
            pyramidName, level, arrayPath);
    end
end

function s = formatNameList(names)
    if isempty(names)
        s = '(none)';
        return;
    end
    parts = cell(1, numel(names));
    for i = 1:numel(names)
        if isempty(names{i})
            parts{i} = '""';
        else
            parts{i} = ['"' names{i} '"'];
        end
    end
    s = strjoin(parts, ', ');
end
