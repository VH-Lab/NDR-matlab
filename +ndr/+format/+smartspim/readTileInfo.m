function info = readTileInfo(rootDir, channelName, tileId)
% ndr.format.smartspim.readTileInfo - describe one SmartSPIM tile
%
%   INFO = ndr.format.smartspim.READTILEINFO(ROOTDIR, CHANNELNAME, TILEID)
%
%   Returns a struct describing one tile without loading any pixel data
%   beyond the first slice's TIFF header. Fields:
%
%     id           char, echo of TILEID
%     channelName  char, echo of CHANNELNAME
%     tileDir      char, absolute path to the tile's TIFF directory
%     numSlices    double, number of z-slice files in the tile directory
%     slicePaths   Nx1 cell of char, sorted absolute paths to each slice
%                  (lexical sort; the acquisition writes zero-padded
%                  filenames so lexical order matches numerical order)
%     height       double, image height (pixels), from imfinfo of the
%                  first slice
%     width        double, image width (pixels), from imfinfo of the
%                  first slice
%     dtype        char, MATLAB numeric class of the first slice's pixels
%                  as reported by imfinfo (e.g. "uint16")
%
%   TILEID is the tile's id as returned by ndr.format.smartspim.listTiles
%   (the DIR_NAME from the XML, e.g. "389960/389960_445310"). Forward
%   slashes are the on-XML separator; this function converts them to
%   the local filesystem separator before resolving.
%
%   Errors if the tile directory does not exist or is empty of TIFFs.
%   Only the first slice is opened -- reading N slices' headers on
%   thousands-of-files tiles would defeat the purpose of a cheap probe.

    if isstring(rootDir) && isscalar(rootDir)
        rootDir = char(rootDir);
    end
    if isstring(channelName) && isscalar(channelName)
        channelName = char(channelName);
    end
    if isstring(tileId) && isscalar(tileId)
        tileId = char(tileId);
    end
    if ~(ischar(rootDir) && ~isempty(rootDir))
        error('ndr:format:smartspim:readTileInfo:BadInput', ...
            'rootDir must be a non-empty char or scalar string.');
    end
    if ~(ischar(channelName) && ~isempty(channelName))
        error('ndr:format:smartspim:readTileInfo:BadInput', ...
            'channelName must be a non-empty char or scalar string.');
    end
    if ~(ischar(tileId) && ~isempty(tileId))
        error('ndr:format:smartspim:readTileInfo:BadInput', ...
            'tileId must be a non-empty char or scalar string.');
    end

    tileDir = tileIdToDir(rootDir, channelName, tileId);
    if ~isfolder(tileDir)
        error('ndr:format:smartspim:readTileInfo:NoSuchTile', ...
            'Tile directory not found: %s', tileDir);
    end

    slicePaths = listTiffSlices(tileDir);
    if isempty(slicePaths)
        error('ndr:format:smartspim:readTileInfo:NoSlices', ...
            'No TIFF slices found in tile directory: %s', tileDir);
    end

    try
        fi = imfinfo(slicePaths{1});
    catch ME
        error('ndr:format:smartspim:readTileInfo:BadFirstSlice', ...
            'Failed to read TIFF header of %s: %s', slicePaths{1}, ...
            ME.message);
    end
    fi = fi(1);

    info = struct( ...
        'id',          tileId, ...
        'channelName', channelName, ...
        'tileDir',     tileDir, ...
        'numSlices',   numel(slicePaths), ...
        'slicePaths',  {slicePaths}, ...
        'height',      double(fi.Height), ...
        'width',       double(fi.Width), ...
        'dtype',       tiffDtype(fi));
end

function tileDir = tileIdToDir(rootDir, channelName, tileId)
    parts = strsplit(char(tileId), '/');
    parts = parts(~cellfun('isempty', parts));
    tileDir = fullfile(rootDir, channelName, parts{:});
end

function paths = listTiffSlices(tileDir)
    % Match .tif and .tiff via one glob. On Windows this is
    % case-insensitive and finds .TIF/.TIFF too; on Linux the vendor
    % writes lowercase, but we also try uppercase globs to be safe.
    names = {};
    for pat = {'*.tif*', '*.TIF*'}
        found = dir(fullfile(tileDir, pat{1}));
        for j = 1:numel(found)
            names{end+1} = found(j).name; %#ok<AGROW>
        end
    end
    if isempty(names)
        paths = {};
        return;
    end
    % Case-insensitive filesystems (Windows/macOS default) return the
    % same file for both globs; deduplicate.
    uniqueNames = unique(names, 'stable');
    uniqueNames = sort(uniqueNames);
    paths = cell(numel(uniqueNames), 1);
    for i = 1:numel(uniqueNames)
        paths{i} = fullfile(tileDir, uniqueNames{i});
    end
end

function dt = tiffDtype(fi)
    bd = 8;
    if isfield(fi, 'BitDepth') && ~isempty(fi.BitDepth)
        bd = double(fi.BitDepth);
    end
    sampleFmt = '';
    if isfield(fi, 'SampleFormat') && ~isempty(fi.SampleFormat)
        sampleFmt = lower(char(fi.SampleFormat));
        if iscell(sampleFmt)
            sampleFmt = sampleFmt{1};
        end
    end
    isFloat = contains(sampleFmt, 'float') || contains(sampleFmt, 'ieee');
    isSigned = contains(sampleFmt, 'signed integer') || ...
        strcmp(sampleFmt, 'signed');
    if isFloat
        if bd <= 32
            dt = 'single';
        else
            dt = 'double';
        end
        return;
    end
    if isSigned
        switch bd
            case 8,  dt = 'int8';
            case 16, dt = 'int16';
            case 32, dt = 'int32';
            case 64, dt = 'int64';
            otherwise, dt = sprintf('int%d', bd);
        end
        return;
    end
    switch bd
        case 1,  dt = 'logical';
        case 8,  dt = 'uint8';
        case 16, dt = 'uint16';
        case 32, dt = 'uint32';
        case 64, dt = 'uint64';
        otherwise, dt = sprintf('uint%d', bd);
    end
end
