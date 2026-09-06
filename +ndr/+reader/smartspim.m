% NDR_READER_SMARTSPIM - Reader class for LifeCanvas SmartSPIM raw acquisitions
%
% This class exposes one SmartSPIM tile through NDR's image (frame) API.
% It is a native NDR image reader, sibling of ndr.reader.omezarr and
% ndr.reader.tiffstack rather than of the regularly-sampled readers:
% it implements ONLY the frame API (numframes, framesize, dimensionorder,
% datatype, frametimes, readframes, epochclock, t0_t1). No fake sample
% rate, no fake t0_t1 for the regularly-sampled abstraction.
%
% Everything below this class -- metadata / XML parsing, tile discovery,
% pixel decoding -- lives in ndr.format.smartspim.* . The class here only
% maps NDR calls into ndr.format.smartspim calls.
%
% Epoch layout: a SmartSPIM epoch is ONE (channel, tile) pair inside a
% SmartSPIM acquisition directory. The epochstream pins all three:
%   { ROOTDIR, CHANNELNAME, TILEID }
% Sidecar files may accompany it inside a larger cell:
%   { { ROOTDIR, CHANNELNAME, TILEID }, sidecar1, sidecar2, ... }
% Anything less specific errors with a list of what could complete the
% pinning; there is no default channel and no default tile. Selecting a
% channel is a fluorophore call; selecting a tile is a physical
% acquisition-position call. Neither can be guessed silently.
%
% Stitching / cross-tile assembly is deliberately out of scope: this
% reader returns ONE tile per epoch and reports it as-is. See issue #128
% for the option-(b) stitching-in-MATLAB decision, which remains open.
% If a downstream user wants a stitched volume in MATLAB, that is a
% separate follow-up.
%
% Dimension model:
%   T <- Z axis of the tile (each z-slice TIFF is a "frame")
%   Y, X <- Y, X axes of the plane (the tile's TIFF height and width)
%   C = 1 (one channel per epoch; multi-channel data pins a different
%          epoch per channel, matching the tiffstack convention)
%   Z = 1
% Frames are returned in 'YXCZT' order: size [Y X 1 1 nFrames].
%
% Timing: SmartSPIM raw acquisitions do not carry per-slice timestamps.
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
            %  SmartSPIM raw acquisitions. Each epoch pins one channel
            %  and one tile via an epochstream of the form
            %  {ROOTDIR, CHANNELNAME, TILEID}.
        end % ndr.reader.smartspim.smartspim

        function info = resolveepoch(~, epochstreams)
            % RESOLVEEPOCH - resolve an epoch to (rootDir, channel, tile)
            %
            % INFO = RESOLVEEPOCH(SMARTSPIM_OBJ, EPOCHSTREAMS)
            %
            % Parses the epoch's stream list to a struct describing the
            % tile without reading any pixels beyond one TIFF header:
            %   .rootDir       char, absolute path to the SmartSPIM root
            %   .channelName   char, the pinned channel directory name
            %   .tileId        char, the pinned tile DIR_NAME
            %   .tile          struct, ndr.format.smartspim.readTileInfo
            %                    result for the pinned tile
            %
            % Accepts these epochstream shapes:
            %   { ROOTDIR, CHANNELNAME, TILEID }
            %   { { ROOTDIR, CHANNELNAME, TILEID }, sidecar1, ... }
            %   { ROOTDIR }              -- errors, listing channels
            %   { ROOTDIR, CHANNELNAME } -- errors, listing tiles

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

                if isempty(channelName)
                    channels = ndr.format.smartspim.listChannels(rootDir);
                    error('ndr:reader:smartspim:ChannelNotPinned', ...
                        ['Epochstream does not pin a channel. ' ...
                         'Available in %s: %s. Pass ' ...
                         '{rootDir, channelName, tileId} as the epochstream.'], ...
                        rootDir, ndr.reader.smartspim.formatNameList( ...
                            {channels.name}));
                end

                if isempty(tileId)
                    tiles = ndr.format.smartspim.listTiles(rootDir, channelName);
                    error('ndr:reader:smartspim:TileNotPinned', ...
                        ['Epochstream does not pin a tile for channel "%s". ' ...
                         'Available in %s: %s. Pass ' ...
                         '{rootDir, channelName, tileId} as the epochstream.'], ...
                        channelName, rootDir, ...
                        ndr.reader.smartspim.formatNameList({tiles.id}));
                end

                info.rootDir     = rootDir;
                info.channelName = channelName;
                info.tileId      = tileId;
                info.tile        = ndr.format.smartspim.readTileInfo( ...
                    rootDir, channelName, tileId);
        end % resolveepoch()

        function n = numframes(smartspim_obj, epochstreams, ~)
            % NUMFRAMES - number of frames (z-slices) in this tile
                info = smartspim_obj.resolveepoch(epochstreams);
                n = info.tile.numSlices;
        end % numframes()

        function sz = framesize(smartspim_obj, epochstreams, ~)
            % FRAMESIZE - the [Y X C Z T] extent of the tile
            %
            % Y = tile height, X = tile width, C = 1, Z = 1,
            % T = number of z-slices.
                info = smartspim_obj.resolveepoch(epochstreams);
                sz = [info.tile.height info.tile.width 1 1 info.tile.numSlices];
        end % framesize()

        function order = dimensionorder(~, ~, ~)
            % DIMENSIONORDER - the dimension order of returned frames
                order = 'YXCZT';
        end % dimensionorder()

        function dt = datatype(smartspim_obj, epochstreams, ~)
            % DATATYPE - the underlying numeric class of the tile
                info = smartspim_obj.resolveepoch(epochstreams);
                dt = info.tile.dtype;
        end % datatype()

        function t = frametimes(smartspim_obj, epochstreams, epoch_select, frameind)
            % FRAMETIMES - the time of each requested frame (NaN)
            %
            % SmartSPIM raw acquisitions do not carry per-slice
            % timestamps; returns NaN for every requested frame,
            % matching ndr.reader.omezarr's clockless behaviour.
                if nargin < 4
                    frameind = 1:smartspim_obj.numframes(epochstreams, epoch_select);
                end
                t = nan(numel(frameind), 1);
        end % frametimes()

        function frames = readframes(smartspim_obj, epochstreams, epoch_select, frameind, options)
            % READFRAMES - read z-slices from the pinned tile
            %
            % FRAMES = READFRAMES(SMARTSPIM_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
            % FRAMES = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Reads the z-slices indexed by FRAMEIND from the pinned
            % tile and returns them in 'YXCZT' order:
            %   size [Y X 1 1 numel(FRAMEIND)]
            %
            % Frames are read one at a time (the format layer's
            % readTileVolume can read a contiguous range; for arbitrary
            % index lists this is a simple loop). Sparse random reads
            % are fine; large contiguous reads that want the extra
            % efficiency can call ndr.format.smartspim.readTileVolume
            % with a ZRange directly.
            arguments
                smartspim_obj
                epochstreams
                epoch_select = 1
                frameind = []
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
                info = smartspim_obj.resolveepoch(epochstreams);
                Y = info.tile.height;
                X = info.tile.width;
                n = info.tile.numSlices;

                if isempty(frameind)
                    frameind = 1:n;
                end

                if any(frameind < 1) || any(frameind > n)
                    error('ndr:reader:smartspim:FrameOutOfRange', ...
                        'frameind out of range [1, %d].', n);
                end

                dt = info.tile.dtype;
                frames = zeros(Y, X, 1, 1, numel(frameind), dt);
                for i = 1:numel(frameind)
                    z = frameind(i);
                    vol = ndr.format.smartspim.readTileVolume( ...
                        info.rootDir, info.channelName, info.tileId, ...
                        'ZRange', [z z]);
                    % vol shape is (1, Y, X) — squeeze z, place at (Y, X, 1, 1, i)
                    frames(:,:,1,1,i) = reshape(vol(1, :, :), Y, X);
                end
                frames = ndr.reader.base.selectframeCZ( ...
                    frames, options.SelectC, options.SelectZ);
        end % readframes()

        function ec = epochclock(~, ~, ~)
            % EPOCHCLOCK - clock type for a SmartSPIM epoch
            %
            % Returns {ndr.time.clocktype('no_time')} because raw
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
            % ndr.reader.omezarr and ndr.reader.tiffstack. A SmartSPIM
            % epoch pins a specific fluorophore channel via its
            % epochstream, so at the NDR-channel level the tile is
            % single-channel.
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
