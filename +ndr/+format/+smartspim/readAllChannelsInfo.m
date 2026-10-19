function info = readAllChannelsInfo(rootDir, options)
% ndr.format.smartspim.readAllChannelsInfo - describe SmartSPIM's stitched All_Channels volume
%
%   INFO = ndr.format.smartspim.READALLCHANNELSINFO(ROOTDIR)
%   INFO = ndr.format.smartspim.READALLCHANNELSINFO(ROOTDIR, 'ReadHeader', TF)
%
%   ROOTDIR/All_Channels holds the output of the SmartSPIM AutoStitch
%   pipeline: a TeraStitcher merge of the destriped Ex_* tiles with the
%   per-channel <wavelength>_flat.tiff flat-field / left-right
%   illumination correction applied and the tile overlaps blended. It is
%   the volume Imaris is built from, and the one analysis should use
%   (ferret-lightsheet/formats/SmartSPIM.md, sections 4, 6 and 7).
%
%   All_Channels is a flat folder of 2-D TIFFs, one per (z, channel),
%   named
%       <Y origin>_<X origin>_<z*10>_ch<k>.tiff
%   e.g. 675050_455000_000110_ch1.tiff, plus an ImageList.txt for
%   Imaris. Every slice spans the whole stitched canvas (image height =
%   Y, width = X), so there are no tiles. The ch<k> index follows the
%   filter-channel number, NOT the acquisition order. It is taken from
%   the <channel>_MIP_stitched folder, whose files carry the same
%   _ch<k> suffix; when that folder is absent (e.g. a partial restore),
%   k is the rank of the channel's filter-channel number among all
%   channels (Ch1 -> ch0, Ch2 -> ch1, ...).
%
%   Returned fields:
%
%     allChannelsDir  char, absolute path of ROOTDIR/All_Channels
%     channels        struct array, one entry per channel, sorted by
%                     chIndex, with fields:
%                       name        char, channel directory name
%                                   (e.g. "Ex_561_Em_561F_Ch2")
%                       chIndex     double, the k of its _ch<k> files
%                       numSlices   double, number of z-slices
%                       slicePaths  Nx1 cell of char, absolute paths
%                                   sorted by the numeric z field
%     channelNames    1xC cell of char, channels(:).name in chIndex order
%     height          double, slice height (pixels), NaN if not read
%     width           double, slice width (pixels), NaN if not read
%     dtype           char, MATLAB numeric class of the pixels ('' if
%                     not read)
%     voxelSizeUm     1x3 double [z y x] in micrometers from
%                     metadata.json, [NaN NaN NaN] if unavailable
%
%   With 'ReadHeader', false the first slice's TIFF header is not opened
%   and height / width / dtype come back NaN / NaN / ''. This is what
%   ndr.format.smartspim.hasAllChannels uses for its cheap probe.
%
%   The slices are LZW-compressed in real acquisitions; MATLAB's imread
%   decodes LZW natively.
%
%   Errors if All_Channels is missing, holds no "*_ch<k>.tif(f)" slices,
%   lacks the slices of any channel, or if two channels map to the same
%   ch<k>.
%
%   See also: ndr.format.smartspim.hasAllChannels,
%   ndr.format.smartspim.readAllChannelsVolume

    arguments
        rootDir (1,:) char {mustBeNonempty}
        options.ReadHeader (1,1) logical = true
    end

    if ~isfolder(rootDir)
        error('ndr:format:smartspim:readAllChannelsInfo:NotADirectory', ...
            'Not a directory: %s', rootDir);
    end

    allChannelsDir = fullfile(rootDir, 'All_Channels');
    if ~isfolder(allChannelsDir)
        error('ndr:format:smartspim:readAllChannelsInfo:NoAllChannels', ...
            'All_Channels directory not found: %s', allChannelsDir);
    end

    [chOfFile, zOfFile, pathOfFile] = indexSlices(allChannelsDir);
    if isempty(chOfFile)
        error('ndr:format:smartspim:readAllChannelsInfo:NoSlices', ...
            'No "*_ch<k>.tif(f)" slices found in %s', allChannelsDir);
    end

    acqChannels = ndr.format.smartspim.listChannels(rootDir);
    names = {acqChannels.name};
    chIndices = zeros(1, numel(names));
    for i = 1:numel(names)
        chIndices(i) = channelIndex(rootDir, names{i}, acqChannels);
    end
    if numel(unique(chIndices)) ~= numel(chIndices)
        error('ndr:format:smartspim:readAllChannelsInfo:DuplicateChannelIndex', ...
            'Two channels map to the same All_Channels _ch<k> index in %s.', ...
            rootDir);
    end

    [chIndices, order] = sort(chIndices);
    names = names(order);

    channels = struct('name', {}, 'chIndex', {}, 'numSlices', {}, ...
        'slicePaths', {});
    for i = 1:numel(names)
        k = chIndices(i);
        sel = find(chOfFile == k);
        if isempty(sel)
            error('ndr:format:smartspim:readAllChannelsInfo:MissingChannel', ...
                'No "_ch%d" slices for %s in %s', k, names{i}, allChannelsDir);
        end
        [~, zOrder] = sort(zOfFile(sel));
        paths = pathOfFile(sel(zOrder));
        channels(i) = struct( ...
            'name',       names{i}, ...
            'chIndex',    k, ...
            'numSlices',  numel(paths), ...
            'slicePaths', {paths(:)});
    end

    height = NaN;
    width  = NaN;
    dtype  = '';
    if options.ReadHeader
        firstPath = channels(1).slicePaths{1};
        try
            fi = imfinfo(firstPath);
        catch ME
            error('ndr:format:smartspim:readAllChannelsInfo:BadFirstSlice', ...
                'Failed to read TIFF header of %s: %s', firstPath, ME.message);
        end
        fi = fi(1);
        height = double(fi.Height);
        width  = double(fi.Width);
        dtype  = tiffDtype(fi);
    end

    voxelSizeUm = [NaN NaN NaN];
    try
        meta = ndr.format.smartspim.readAcquisitionMetadata(rootDir);
        voxelSizeUm = meta.voxelSizeUm;
    catch
        % metadata.json missing or unreadable; leave voxel size unknown.
    end

    info = struct( ...
        'allChannelsDir', allChannelsDir, ...
        'channels',       channels, ...
        'channelNames',   {names}, ...
        'height',         height, ...
        'width',          width, ...
        'dtype',          dtype, ...
        'voxelSizeUm',    voxelSizeUm);
end

function [chOfFile, zOfFile, pathOfFile] = indexSlices(folder)
    % Parse every "<Y>_<X>_<z*10>_ch<k>.tif(f)" file name in FOLDER.
    entries = dir(folder);
    n = numel(entries);
    chOfFile = zeros(1, n);
    zOfFile = zeros(1, n);
    pathOfFile = cell(1, n);
    keep = false(1, n);
    for i = 1:n
        if entries(i).isdir
            continue;
        end
        tok = regexp(entries(i).name, '^(\d+)_(\d+)_(\d+)_ch(\d+)\.tiff?$', ...
            'tokens', 'once', 'ignorecase');
        if isempty(tok)
            continue;
        end
        keep(i) = true;
        zOfFile(i) = str2double(tok{3});
        chOfFile(i) = str2double(tok{4});
        pathOfFile{i} = fullfile(folder, entries(i).name);
    end
    chOfFile = chOfFile(keep);
    zOfFile = zOfFile(keep);
    pathOfFile = pathOfFile(keep);
end

function k = channelIndex(rootDir, channelName, acqChannels)
    % Preferred: the single _ch<k> suffix used in <channel>_MIP_stitched.
    mipDir = fullfile(rootDir, [channelName '_MIP_stitched']);
    if isfolder(mipDir)
        ks = unique(indexSlices(mipDir));
        if isscalar(ks)
            k = ks;
            return;
        end
    end
    % Fallback: rank of the filter-channel number (stable on ties).
    [~, order] = sort([acqChannels.filterChannel]);
    rankedNames = {acqChannels(order).name};
    k = find(strcmp(rankedNames, channelName), 1) - 1;
end

function dt = tiffDtype(fi)
    bd = 8;
    if isfield(fi, 'BitDepth') && ~isempty(fi.BitDepth)
        bd = double(fi.BitDepth);
    end
    sampleFmt = '';
    if isfield(fi, 'SampleFormat') && ~isempty(fi.SampleFormat)
        sampleFmt = lower(char(fi.SampleFormat));
    end
    % imfinfo reports e.g. 'Unsigned integer', 'Two''s complement signed
    % integer' or 'IEEE floating point'; test 'unsigned' before 'signed'.
    if contains(sampleFmt, 'float') || contains(sampleFmt, 'ieee')
        if bd <= 32
            dt = 'single';
        else
            dt = 'double';
        end
    elseif ~contains(sampleFmt, 'unsigned') && contains(sampleFmt, 'signed')
        dt = sprintf('int%d', bd);
    elseif bd == 1
        dt = 'logical';
    else
        dt = sprintf('uint%d', bd);
    end
end
