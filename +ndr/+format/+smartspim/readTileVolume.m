function volume = readTileVolume(rootDir, channelName, tileId, varargin)
% ndr.format.smartspim.readTileVolume - assemble one SmartSPIM tile as a 3D volume
%
%   VOLUME = ndr.format.smartspim.READTILEVOLUME(ROOTDIR, CHANNELNAME, TILEID)
%   VOLUME = ndr.format.smartspim.READTILEVOLUME(..., 'ZRange', [START STOP])
%
%   Reads the z-slices of one SmartSPIM tile from disk and stacks them
%   into a 3D array with axis order (z, y, x). By default all slices
%   are read. Pass 'ZRange' as a two-element 1-based inclusive [START
%   STOP] to read a sub-range.
%
%   The returned array has the same numeric class as the underlying
%   TIFF pixel data (typically uint16 for SmartSPIM).
%
%   This is per-tile only: stitching / cross-tile assembly is out of
%   scope for the NDR format layer -- see ferret-lightsheet
%   (pyanalysis/smartspim/volume.py) for the working Python
%   implementation.
%
%   Errors if the tile directory is missing, ZRange is invalid, or any
%   slice fails to decode.

    p = inputParser();
    p.FunctionName = 'ndr.format.smartspim.readTileVolume';
    p.addParameter('ZRange', [], @(x) isempty(x) || (isnumeric(x) && ...
        numel(x) == 2 && all(x == floor(x))));
    p.parse(varargin{:});
    zrange = p.Results.ZRange;

    info = ndr.format.smartspim.readTileInfo(rootDir, channelName, tileId);
    n = info.numSlices;

    if isempty(zrange)
        firstZ = 1;
        lastZ  = n;
    else
        firstZ = double(zrange(1));
        lastZ  = double(zrange(2));
        if firstZ < 1 || lastZ > n || firstZ > lastZ
            error('ndr:format:smartspim:readTileVolume:BadZRange', ...
                'ZRange [%g %g] is not a valid 1-based inclusive range in [1, %d].', ...
                firstZ, lastZ, n);
        end
    end

    nSlices = lastZ - firstZ + 1;
    h = info.height;
    w = info.width;

    % Read first slice to lock in the class; then preallocate the
    % volume and copy each slice into it.
    firstPath = info.slicePaths{firstZ};
    try
        firstImg = imread(firstPath);
    catch ME
        error('ndr:format:smartspim:readTileVolume:BadSlice', ...
            'Failed to decode %s: %s', firstPath, ME.message);
    end
    if size(firstImg, 1) ~= h || size(firstImg, 2) ~= w
        error('ndr:format:smartspim:readTileVolume:ShapeMismatch', ...
            'Slice %s has shape %dx%d; expected %dx%d.', ...
            firstPath, size(firstImg, 1), size(firstImg, 2), h, w);
    end

    volume = zeros(nSlices, h, w, class(firstImg));
    volume(1, :, :) = firstImg;

    for i = 2:nSlices
        pathI = info.slicePaths{firstZ + i - 1};
        try
            img = imread(pathI);
        catch ME
            error('ndr:format:smartspim:readTileVolume:BadSlice', ...
                'Failed to decode %s: %s', pathI, ME.message);
        end
        if size(img, 1) ~= h || size(img, 2) ~= w || ~strcmp(class(img), class(firstImg))
            error('ndr:format:smartspim:readTileVolume:ShapeMismatch', ...
                'Slice %s has shape %dx%d (%s); expected %dx%d (%s).', ...
                pathI, size(img, 1), size(img, 2), class(img), ...
                h, w, class(firstImg));
        end
        volume(i, :, :) = img;
    end
end
