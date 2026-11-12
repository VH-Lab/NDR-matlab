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
%   e.g. 675050_455000_000110_ch1.tiff, or, by other versions of the
%   pipeline, without the origins:
%       <z*10>_ch<k>.tiff
%   e.g. 000110_ch1.tiff, or Z<z*10>_Ch<k>.tif, e.g. Z000110_Ch0.tif
%   (case does not matter); plus an ImageList.txt for Imaris. Every slice spans the whole stitched canvas (image height =
%   Y, width = X), so there are no tiles. The ch<k> index follows the
%   filter-channel number, NOT the acquisition order. It is taken from
%   the <channel>_MIP_stitched folder, whose files carry the same
%   _ch<k> suffix; when that folder is absent (e.g. a partial restore),
%   k is the rank of the channel's filter-channel number among all
%   channels (Ch1 -> ch0, Ch2 -> ch1, ...). Between the two, IMS_Notes.txt
%   ("The folder <channel>_stitched is represented as Ch<k>", written when
%   SmartSPIM converts All_Channels to Imaris) is used when it names the
%   channel; SmartSPIM 6.0 writes no _ch suffix in _MIP_stitched. A channel
%   folder without "_Ch<n>" (Ex_<laser>_Em_<filter>) gets its filter-channel
%   number from metadata.json (see ndr.format.smartspim.listChannels); a
%   single one with none takes whichever one _ch<k> the slices carry. When
%   such folders are mapped by filter-channel rank, that rank must match
%   the order the channels first appear in metadata.json's tiles, or the
%   call errors (ndr:format:smartspim:readAllChannelsInfo:ChannelOrderDisagrees):
%   which order the stitcher follows for them is not yet known.
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
    if isscalar(acqChannels) && isempty(regexp(acqChannels.name, '_Ch\d+$', 'once')) && ...
            isscalar(unique(chOfFile))
        % A single channel folder without "_Ch<n>": its slices are the only
        % _ch<k> there is, whatever number metadata.json gives it.
        chIndices = unique(chOfFile);
    else
        notes = ndr.format.smartspim.readImsNotes(rootDir);
        byRank = false(1, numel(names));
        for i = 1:numel(names)
            [chIndices(i), byRank(i)] = channelIndex(rootDir, names{i}, acqChannels, notes);
        end
        unnumbered = cellfun(@isempty, regexp(names, '_Ch\d+$', 'once'));
        if numel(names) > 1 && any(byRank) && any(unnumbered)
            checkRankMatchesMetadataOrder(rootDir, acqChannels);
        end
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
    % Parse every "<Y>_<X>_<z*10>_ch<k>.tif(f)", "<z*10>_ch<k>.tif(f)" or
    % "Z<z*10>_Ch<k>.tif(f)" file name in FOLDER (case-insensitive): z is
    % the number just before _ch<k>.
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
        tok = regexp(entries(i).name, '^(?:\d+_\d+_|Z)?(\d+)_ch(\d+)\.tiff?$', ...
            'tokens', 'once', 'ignorecase');
        if isempty(tok)
            continue;
        end
        keep(i) = true;
        zOfFile(i) = str2double(tok{1});
        chOfFile(i) = str2double(tok{2});
        pathOfFile{i} = fullfile(folder, entries(i).name);
    end
    chOfFile = chOfFile(keep);
    zOfFile = zOfFile(keep);
    pathOfFile = pathOfFile(keep);
    % A folder cannot hold one name twice, but a network share's listing
    % can return it twice (and leave others out): macOS SMB directory
    % caching does, on large folders. A volume built from such a listing
    % would repeat some planes and lack others, so refuse it.
    if numel(unique(pathOfFile)) < numel(pathOfFile)
        error('ndr:format:smartspim:readAllChannelsInfo:DuplicateListing', ...
            ['The listing of %s names some files more than once, so it ' ...
             'cannot be trusted (on a macOS SMB share, turn off directory ' ...
             'caching: dir_cache_off=yes in /etc/nsmb.conf, then remount).'], folder);
    end
    if ~isempty(chOfFile)
        [~, ia] = unique([chOfFile(:) zOfFile(:)], 'rows');
        if numel(ia) < numel(chOfFile)
            error('ndr:format:smartspim:readAllChannelsInfo:DuplicateSlice', ...
                ['%s holds more than one file for the same channel and z ' ...
                 '(tiles rather than stitched slices?).'], folder);
        end
    end
end

function checkRankMatchesMetadataOrder(rootDir, acqChannels)
    % Channel folders without "_Ch<n>" (SmartSPIM 6.0) and no direct record
    % of which _Ch<k> is whose: the filter-channel rank decides, as for
    % numbered folders. Until an acquisition shows which of the two the
    % stitcher follows there, refuse when that rank and the order the
    % channels first appear in metadata.json's tiles disagree.
    firstSeen = inf(1, numel(acqChannels));
    try
        meta = ndr.format.smartspim.readAcquisitionMetadata(rootDir);
        t = meta.tiles;
    catch
        t = struct('laser', {}, 'filter', {});
    end
    for i = 1:numel(acqChannels)
        j = find([t.laser] == acqChannels(i).wavelength & ...
            strcmp({t.filter}, acqChannels(i).filterName), 1);
        if ~isempty(j), firstSeen(i) = j; end
    end
    [~, byFilter] = sort([acqChannels.filterChannel]);
    [~, byMetadata] = sort(firstSeen);
    if any(isinf(firstSeen)) || ~isequal(byFilter, byMetadata)
        error('ndr:format:smartspim:readAllChannelsInfo:ChannelOrderDisagrees', ...
            ['In %s the channel folders have no "_Ch<n>" and nothing records ' ...
             'which All_Channels "_ch<k>" is which channel, and the channels'' ' ...
             'filter-channel order (%s) differs from the order they appear in ' ...
             'metadata.json (%s), so it is not known which order the stitcher ' ...
             'used.'], rootDir, strjoin({acqChannels(byFilter).name}, ', '), ...
            strjoin({acqChannels(byMetadata).name}, ', '));
    end
end

function [k, byRank] = channelIndex(rootDir, channelName, acqChannels, notes)
    % Preferred: the single _ch<k> suffix used in <channel>_MIP_stitched.
    mipDir = fullfile(rootDir, [channelName '_MIP_stitched']);
    if isfolder(mipDir)
        ks = unique(indexSlices(mipDir));
        if isscalar(ks)
            k = ks;
            byRank = false;
            return;
        end
    end
    % Next: SmartSPIM's own statement in IMS_Notes.txt ("The folder
    % <channel>_stitched is represented as Ch<k>").
    j = find(strcmp({notes.channelName}, channelName), 1);
    if ~isempty(j)
        k = notes(j).chIndex;
        byRank = false;
        return;
    end
    % Fallback: rank of the filter-channel number (stable on ties).
    [~, order] = sort([acqChannels.filterChannel]);
    rankedNames = {acqChannels(order).name};
    k = find(strcmp(rankedNames, channelName), 1) - 1;
    byRank = true;
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
