function volume = readAllChannelsVolume(rootDir, channelName, options)
% ndr.format.smartspim.readAllChannelsVolume - read one channel of SmartSPIM's stitched volume
%
%   VOLUME = ndr.format.smartspim.READALLCHANNELSVOLUME(ROOTDIR, CHANNELNAME)
%   VOLUME = ndr.format.smartspim.READALLCHANNELSVOLUME(..., 'ZRange', [START STOP])
%
%   Reads the stitched, flat-field-corrected z-slices of one channel
%   from ROOTDIR/All_Channels and stacks them into a 3D array with axis
%   order (z, y, x), the same layout as
%   ndr.format.smartspim.readTileVolume. By default all slices are read.
%   Pass 'ZRange' as a two-element 1-based inclusive [START STOP] to
%   read a sub-range.
%
%   CHANNELNAME is the channel directory name (e.g. "Ex_561_Em_561F_Ch2");
%   the mapping to the All_Channels _ch<k> files is resolved by
%   ndr.format.smartspim.readAllChannelsInfo.
%
%   The returned array has the numeric class of the TIFF pixel data
%   (uint16 for SmartSPIM).
%
%   Errors if All_Channels is not usable, the channel is unknown, ZRange
%   is invalid, or any slice fails to decode or differs in shape/class.
%
%   See also: ndr.format.smartspim.readAllChannelsInfo,
%   ndr.format.smartspim.readTileVolume

    arguments
        rootDir (1,:) char {mustBeNonempty}
        channelName (1,:) char {mustBeNonempty}
        options.ZRange {mustBeNumeric, mustBeInteger} = []
    end

    info = ndr.format.smartspim.readAllChannelsInfo(rootDir);
    c = find(strcmp(info.channelNames, channelName), 1);
    if isempty(c)
        error('ndr:format:smartspim:readAllChannelsVolume:NoSuchChannel', ...
            'Channel "%s" not found in %s. Available: %s', channelName, ...
            rootDir, strjoin(info.channelNames, ', '));
    end
    slicePaths = info.channels(c).slicePaths;
    n = info.channels(c).numSlices;

    zrange = options.ZRange;
    if isempty(zrange)
        firstZ = 1;
        lastZ  = n;
    else
        if numel(zrange) ~= 2
            error('ndr:format:smartspim:readAllChannelsVolume:BadZRange', ...
                'ZRange must be a two-element [START STOP] vector.');
        end
        firstZ = double(zrange(1));
        lastZ  = double(zrange(2));
        if firstZ < 1 || lastZ > n || firstZ > lastZ
            error('ndr:format:smartspim:readAllChannelsVolume:BadZRange', ...
                'ZRange [%g %g] is not a valid 1-based inclusive range in [1, %d].', ...
                firstZ, lastZ, n);
        end
    end

    nSlices = lastZ - firstZ + 1;
    h = info.height;
    w = info.width;
    volume = zeros(nSlices, h, w, info.dtype);

    for i = 1:nSlices
        pathI = slicePaths{firstZ + i - 1};
        try
            img = imread(pathI);
        catch ME
            error('ndr:format:smartspim:readAllChannelsVolume:BadSlice', ...
                'Failed to decode %s: %s', pathI, ME.message);
        end
        if size(img, 1) ~= h || size(img, 2) ~= w || ~strcmp(class(img), info.dtype)
            error('ndr:format:smartspim:readAllChannelsVolume:ShapeMismatch', ...
                'Slice %s has shape %dx%d (%s); expected %dx%d (%s).', ...
                pathI, size(img, 1), size(img, 2), class(img), ...
                h, w, info.dtype);
        end
        volume(i, :, :) = img;
    end
end
