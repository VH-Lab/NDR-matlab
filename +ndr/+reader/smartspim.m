% NDR_READER_SMARTSPIM - Reader class for LifeCanvas SmartSPIM acquisitions
%
% This class exposes a SmartSPIM acquisition through NDR's image (frame)
% API. It is a native NDR image reader, sibling of ndr.reader.omezarr
% and ndr.reader.tiffstack rather than of the regularly-sampled readers:
% it implements ONLY the frame API (numframes, framesize, dimensionorder,
% datatype, frametimes, readframes, epochclock, t0_t1). No fake sample
% rate, no fake t0_t1 for the regularly-sampled abstraction.
%
% Everything below this class -- metadata / XML parsing, file discovery,
% pixel decoding -- lives in ndr.format.smartspim.* . The class here only
% maps NDR calls into ndr.format.smartspim calls.
%
% Image sources. A processed SmartSPIM acquisition holds two images of
% the same brain (ferret-lightsheet/formats/SmartSPIM.md):
%   * All_Channels/ -- SmartSPIM AutoStitch's stitched volume: the
%     destriped tiles merged by TeraStitcher with flat-field and
%     left/right illumination correction and blended overlaps. This is
%     the better-stitched, harmonized data (and what Imaris shows), so
%     the reader PREFERS it whenever it is present for every channel.
%   * Ex_*/ -- the destriped per-tile stacks, not flat-corrected and not
%     stitched. They stay readable tile by tile (they are the source of
%     truth and keep the destriper's unscaled intensities), and they are
%     the only image source of acquisitions without All_Channels.
% The reader never stitches tiles itself: stitched data comes only from
% SmartSPIM's own All_Channels output (stitching in MATLAB remains the
% open question of issue #128).
%
% Epoch layout. The epochstream names what to read:
%   { ROOTDIR }                         stitched All_Channels volume,
%                                       every channel on the C axis
%   { ROOTDIR, CHANNELNAME }            stitched All_Channels volume of
%                                       one channel (C = 1)
%   { ROOTDIR, CHANNELNAME, TILEID }    one destriped Ex_* tile (C = 1)
% Sidecar files may accompany it inside a larger cell:
%   { { ROOTDIR, CHANNELNAME, TILEID }, sidecar1, sidecar2, ... }
% Without a usable All_Channels folder (AutoStitch not run, or not
% restored), the first two forms fall back to the per-tile layout and
% error with a list of what could complete the pinning, exactly as
% before: there is no default channel and no default tile.
%
% Dimension model:
%   T <- Z axis of the volume (each z-slice TIFF is a "frame")
%   Y, X <- Y, X axes of the plane (the TIFF height and width; for
%          All_Channels the whole stitched canvas)
%   C = number of channels in the epoch. For { ROOTDIR } the channels
%       are ordered by their All_Channels _ch<k> index (the
%       filter-channel order); resolveepoch returns their names in
%       info.channelNames.
%   Z = 1
% Frames are returned in 'YXCZT' order: size [Y X C 1 nFrames].
%
% Timing: SmartSPIM acquisitions do not carry per-slice timestamps.
% epochclock is 'no_time' and frametimes returns NaN, matching
% ndr.reader.omezarr's clockless behaviour.

classdef smartspim < ndr.reader.base

    properties
    end

    methods

        function smartspim_obj = smartspim()
            % SMARTSPIM - Create a new SmartSPIM tile reader
            %
            %  SMARTSPIM_OBJ = SMARTSPIM()
            %
            %  Creates a Neuroscience Data Reader object for LifeCanvas
            %  SmartSPIM acquisitions. An epochstream {ROOTDIR} or
            %  {ROOTDIR, CHANNELNAME} reads the stitched All_Channels
            %  volume; {ROOTDIR, CHANNELNAME, TILEID} reads one tile.
        end % ndr.reader.smartspim.smartspim

        function info = resolveepoch(~, epochstreams)
            % RESOLVEEPOCH - resolve an epoch to its image source
            %
            % INFO = RESOLVEEPOCH(SMARTSPIM_OBJ, EPOCHSTREAMS)
            %
            % Parses the epoch's stream list to a struct describing what
            % the epoch reads, without reading any pixels beyond one
            % TIFF header:
            %   .rootDir       char, absolute path to the SmartSPIM root
            %   .channelName   char, the pinned channel directory name
            %                    ('' for an all-channel epoch)
            %   .tileId        char, the pinned tile DIR_NAME ('' for a
            %                    stitched epoch)
            %   .source        'allChannels' (stitched All_Channels
            %                    volume) or 'tile' (one Ex_* tile)
            %   .channelNames  1xC cell, channel names along the C axis
            %   .numSlices     double, number of frames (z-slices)
            %   .height        double, frame height (pixels)
            %   .width         double, frame width (pixels)
            %   .dtype         char, MATLAB numeric class of the pixels
            %   .tile          struct, ndr.format.smartspim.readTileInfo
            %                    result for a tile epoch, [] otherwise
            %   .allChannels   struct,
            %                    ndr.format.smartspim.readAllChannelsInfo
            %                    result for a stitched epoch, [] otherwise
            %
            % Accepts these epochstream shapes:
            %   { ROOTDIR, CHANNELNAME, TILEID }  -- one tile
            %   { { ROOTDIR, CHANNELNAME, TILEID }, sidecar1, ... }
            %   { ROOTDIR, CHANNELNAME } -- stitched channel; without
            %                               All_Channels, errors listing
            %                               tiles
            %   { ROOTDIR }              -- stitched, all channels;
            %                               without All_Channels, errors
            %                               listing channels

                [rootDir, channelName, tileId] = ...
                    ndr.reader.smartspim.parseEpochstreams(epochstreams);

                if isempty(rootDir)
                    error('ndr:reader:smartspim:NoRootInEpochstream', ...
                        'No SmartSPIM root directory found in epochstream.');
                end
                if ~isfolder(rootDir)
                    error('ndr:reader:smartspim:NotADirectory', ...
                        'SmartSPIM root does not exist: %s', rootDir);
                end

                info.rootDir     = rootDir;
                info.channelName = channelName;
                info.tileId      = tileId;

                if isempty(tileId) && ndr.format.smartspim.hasAllChannels(rootDir)
                    stitched = ndr.format.smartspim.readAllChannelsInfo(rootDir);
                    if isempty(channelName)
                        sel = 1:numel(stitched.channels);
                        counts = [stitched.channels.numSlices];
                        if any(counts ~= counts(1))
                            error('ndr:reader:smartspim:SliceCountMismatch', ...
                                ['All_Channels channels have different ' ...
                                 'slice counts (%s) in %s; pin one channel ' ...
                                 'with {rootDir, channelName}.'], ...
                                num2str(counts), rootDir);
                        end
                    else
                        sel = find(strcmp(stitched.channelNames, channelName), 1);
                        if isempty(sel)
                            error('ndr:reader:smartspim:NoSuchChannel', ...
                                'Channel "%s" not found. Available in %s: %s.', ...
                                channelName, rootDir, ...
                                ndr.reader.smartspim.formatNameList( ...
                                    stitched.channelNames));
                        end
                    end
                    info.source       = 'allChannels';
                    info.channelNames = stitched.channelNames(sel);
                    info.numSlices    = stitched.channels(sel(1)).numSlices;
                    info.height       = stitched.height;
                    info.width        = stitched.width;
                    info.dtype        = stitched.dtype;
                    info.tile         = [];
                    info.allChannels  = stitched;
                    return;
                end

                if isempty(channelName)
                    channels = ndr.format.smartspim.listChannels(rootDir);
                    error('ndr:reader:smartspim:ChannelNotPinned', ...
                        ['Epochstream does not pin a channel and %s has no ' ...
                         'usable All_Channels stitched volume. ' ...
                         'Available channels: %s. Pass ' ...
                         '{rootDir, channelName, tileId} as the epochstream.'], ...
                        rootDir, ndr.reader.smartspim.formatNameList( ...
                            {channels.name}));
                end

                if isempty(tileId)
                    tiles = ndr.format.smartspim.listTiles(rootDir, channelName);
                    error('ndr:reader:smartspim:TileNotPinned', ...
                        ['Epochstream does not pin a tile for channel "%s" ' ...
                         'and %s has no usable All_Channels stitched volume. ' ...
                         'Available tiles: %s. Pass ' ...
                         '{rootDir, channelName, tileId} as the epochstream.'], ...
                        channelName, rootDir, ...
                        ndr.reader.smartspim.formatNameList({tiles.id}));
                end

                tile = ndr.format.smartspim.readTileInfo( ...
                    rootDir, channelName, tileId);
                info.source       = 'tile';
                info.channelNames = {channelName};
                info.numSlices    = tile.numSlices;
                info.height       = tile.height;
                info.width        = tile.width;
                info.dtype        = tile.dtype;
                info.tile         = tile;
                info.allChannels  = [];
        end % resolveepoch()

        function n = numframes(smartspim_obj, epochstreams, ~)
            % NUMFRAMES - number of frames (z-slices) in this epoch
                info = smartspim_obj.resolveepoch(epochstreams);
                n = info.numSlices;
        end % numframes()

        function sz = framesize(smartspim_obj, epochstreams, ~)
            % FRAMESIZE - the [Y X C Z T] extent of the epoch
            %
            % Y = frame height, X = frame width, C = number of channels
            % in the epoch, Z = 1, T = number of z-slices.
                info = smartspim_obj.resolveepoch(epochstreams);
                sz = [info.height info.width numel(info.channelNames) 1 ...
                    info.numSlices];
        end % framesize()

        function order = dimensionorder(~, ~, ~)
            % DIMENSIONORDER - the dimension order of returned frames
                order = 'YXCZT';
        end % dimensionorder()

        function dt = datatype(smartspim_obj, epochstreams, ~)
            % DATATYPE - the underlying numeric class of the pixels
                info = smartspim_obj.resolveepoch(epochstreams);
                dt = info.dtype;
        end % datatype()

        function t = frametimes(smartspim_obj, epochstreams, epoch_select, frameind)
            % FRAMETIMES - the time of each requested frame (NaN)
            %
            % SmartSPIM acquisitions do not carry per-slice timestamps;
            % returns NaN for every requested frame, matching
            % ndr.reader.omezarr's clockless behaviour.
                if nargin < 4
                    frameind = 1:smartspim_obj.numframes(epochstreams, epoch_select);
                end
                t = nan(numel(frameind), 1);
        end % frametimes()

        function frames = readframes(smartspim_obj, epochstreams, epoch_select, frameind, options)
            % READFRAMES - read z-slices from the epoch
            %
            % FRAMES = READFRAMES(SMARTSPIM_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
            % FRAMES = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Reads the z-slices indexed by FRAMEIND and returns them in
            % 'YXCZT' order:
            %   size [Y X C 1 numel(FRAMEIND)]
            % where C is the number of channels in the epoch (see
            % RESOLVEEPOCH's channelNames for their order).
            %
            % Stitched epochs read each run of consecutive frame indices
            % with one ndr.format.smartspim.readAllChannelsVolume call
            % per channel. Tile epochs read frames one at a time through
            % ndr.format.smartspim.readTileVolume; large contiguous reads
            % that want the extra efficiency can call the format
            % functions with a ZRange directly.
            arguments
                smartspim_obj
                epochstreams
                epoch_select = 1
                frameind = []
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
                info = smartspim_obj.resolveepoch(epochstreams);
                Y = info.height;
                X = info.width;
                C = numel(info.channelNames);
                n = info.numSlices;

                if isempty(frameind)
                    frameind = 1:n;
                end
                frameind = double(frameind(:)');

                if any(frameind < 1) || any(frameind > n)
                    error('ndr:reader:smartspim:FrameOutOfRange', ...
                        'frameind out of range [1, %d].', n);
                end

                % Route dtype through the reader's own datatype() so
                % epoch_select is honoured -- a SmartSPIM epoch is
                % fully specified by its epochstream, but the base-class
                % API still passes epoch_select and callers may rely on it.
                dt = smartspim_obj.datatype(epochstreams, epoch_select);
                frames = zeros(Y, X, C, 1, numel(frameind), dt);

                if strcmp(info.source, 'allChannels')
                    i = 1;
                    while i <= numel(frameind)
                        j = i;
                        while j < numel(frameind) && frameind(j+1) == frameind(j) + 1
                            j = j + 1;
                        end
                        for c = 1:C
                            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                                info.rootDir, info.channelNames{c}, ...
                                'ZRange', [frameind(i) frameind(j)]);
                            % vol shape is (n, Y, X) -> (Y, X, 1, 1, n)
                            frames(:,:,c,1,i:j) = permute(vol, [2 3 4 5 1]);
                        end
                        i = j + 1;
                    end
                else
                    for i = 1:numel(frameind)
                        z = frameind(i);
                        vol = ndr.format.smartspim.readTileVolume( ...
                            info.rootDir, info.channelName, info.tileId, ...
                            'ZRange', [z z]);
                        % vol shape is (1, Y, X) -- squeeze z, place at (Y, X, 1, 1, i)
                        frames(:,:,1,1,i) = reshape(vol(1, :, :), Y, X);
                    end
                end
                frames = ndr.reader.base.selectframeCZ( ...
                    frames, options.SelectC, options.SelectZ);
        end % readframes()

        function ec = epochclock(~, ~, ~)
            % EPOCHCLOCK - clock type for a SmartSPIM epoch
            %
            % Returns {ndr.time.clocktype('no_time')} because
            % SmartSPIM acquisitions do not carry per-slice timestamps.
                ec = {ndr.time.clocktype('no_time')};
        end % epochclock()

        function t0t1 = t0_t1(~, ~, ~)
            % T0_T1 - begin/end times of the epoch
                t0t1 = {[NaN NaN]};
        end % t0_t1()

        function channels = getchannelsepoch(~, ~, ~)
            % GETCHANNELSEPOCH - list channels for a SmartSPIM epoch
            %
            % Returns a single 'image' channel named 'image1', matching
            % ndr.reader.omezarr and ndr.reader.tiffstack: fluorophore
            % channels of a stitched all-channel epoch are returned
            % together on the C axis of READFRAMES rather than as
            % separate NDR channels.
                channels = vlt.data.emptystruct('name','type','time_channel');
                channels(1).name = 'image1';
                channels(1).type = 'image';
                channels(1).time_channel = [];
        end % getchannelsepoch()

    end % methods

    methods (Static)

        function [rootDir, channelName, tileId] = parseEpochstreams(epochstreams)
            % PARSEEPOCHSTREAMS - pull rootDir, channelName, tileId
            %
            % Accepts:
            %   { ROOTDIR, CHANNELNAME, TILEID }
            %   { { ROOTDIR, CHANNELNAME, TILEID }, sidecar1, ... }
            %   { ROOTDIR }
            %   { ROOTDIR, CHANNELNAME }
            % Missing fields come back '' so the caller can raise a
            % specific error naming what needs to be pinned.
                rootDir = '';
                channelName = '';
                tileId = '';

                if (ischar(epochstreams) || isstring(epochstreams)) && ...
                        ~iscell(epochstreams)
                    rootDir = char(epochstreams);
                    return;
                end

                if ~iscell(epochstreams)
                    error('ndr:reader:smartspim:BadEpochstream', ...
                        ['Epochstream must be a path or a cell array; ' ...
                         'got %s.'], class(epochstreams));
                end

                % Nested pinning: {{root, channel, tile}, ...sidecars}
                for i = 1:numel(epochstreams)
                    entry = epochstreams{i};
                    if iscell(entry) && numel(entry) == 3
                        rootDir     = char(entry{1});
                        channelName = char(entry{2});
                        tileId      = char(entry{3});
                        return;
                    end
                end

                % Flat forms with 1, 2 or 3 char/string elements
                if all(cellfun(@(e) ischar(e) || (isstring(e) && isscalar(e)), ...
                        epochstreams))
                    switch numel(epochstreams)
                        case 1
                            rootDir = char(epochstreams{1});
                            return;
                        case 2
                            rootDir     = char(epochstreams{1});
                            channelName = char(epochstreams{2});
                            return;
                        case 3
                            rootDir     = char(epochstreams{1});
                            channelName = char(epochstreams{2});
                            tileId      = char(epochstreams{3});
                            return;
                    end
                end

                % Fallback: find the first SmartSPIM directory in the cell.
                for i = 1:numel(epochstreams)
                    entry = epochstreams{i};
                    if (ischar(entry) || isstring(entry)) && ...
                            isfolder(char(entry)) && ...
                            ndr.format.smartspim.isSmartSPIM(char(entry))
                        rootDir = char(entry);
                        return;
                    end
                end
        end % parseEpochstreams()

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
        end % formatNameList()

    end % methods (Static)

end % classdef
