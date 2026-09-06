% NDR_READER_OMEZARR - Reader class for OME-Zarr (NGFF v0.4) volumes
%
% This class exposes an OME-Zarr store through NDR's image (frame) API.
% It is a native NDR image reader, sibling of ndr.reader.tiffstack rather
% than of the regularly-sampled readers: it implements ONLY the frame API
% (numframes, framesize, dimensionorder, datatype, frametimes, readframes,
% epochclock, t0_t1). No fake sample rate, no fake t0_t1 for the
% regularly-sampled abstraction.
%
% Everything below this class -- .zattrs and .zarray parsing, pyramid
% enumeration, path resolution, pixel decoding -- lives in
% ndr.format.omezarr.* . The class here only maps NDR calls into
% ndr.format.omezarr calls.
%
% Epoch layout: an OME-Zarr epoch is a .zarr DIRECTORY plus a required
% pyramid selector. Epochstreams may be, in any combination:
%   - a 2-element cell {ZARRPATH, PYRAMIDNAME} that pins the pyramid;
%   - a plain path to the .zarr directory (errors with the pyramid list --
%     pyramid selection has no default, because "which analytical lens am
%     I looking through?" cannot be guessed silently. See issue #127.);
%   - additional sidecar files (acquisition JSON, ROIs, stitch provenance
%     etc.) that the file navigator handed along; they are ignored here.
%
% The dual-pyramid lab layout stores 'mean' and 'max' views of one volume
% with a shared level-0 array (see ferret-lightsheet/formats/
% OurUsualZarrFormat.md). Selecting a pyramid is selecting an analytical
% lens: 'max' preserves sparse bright features that 'mean' averages away,
% and vice versa. The reader will never pick one for you.
%
% Dimension model (v1): the NGFF axes (typically c, z, y, x) are mapped
% onto NDR's frame model as follows:
%   T <- Z axis (each z-plane is a "frame")
%   Y, X <- Y, X axes of the plane
%   C <- C axis (channel dimension)
%   Z = 1 (image stacks are treated as 2D+time+C, matching tiffstack)
% Frames are returned in 'YXCZT' order: size [Y X C 1 nFrames].
%
% Timing: NGFF may carry a `t` axis for time-lapse; the initial version
% assumes no `t` axis (the lab's current SmartSPIM output has none), so
% epochclock is 'no_time' and frametimes returns NaN. Adding `t`-axis
% support is straightforward when a real dataset needs it.
%
% Pyramid level: metadata methods (numframes, framesize, datatype) report
% level 1 (highest resolution). readframes accepts a 'Level' name-value
% (default 1) because level is a resolution/speed tradeoff, not a
% semantic lens change. Level MAY default; pyramid MAY NOT.
%
% Pixel reading is delegated to ndr.format.omezarr.readArray, filed as
% issue #130. Until that lands, readframes errors with a clear message.
% Everything else -- the frame API metadata, epoch resolution, timing --
% works today against a metadata-only fixture.

classdef omezarr < ndr.reader.base

	properties
	end

	methods

		function omezarr_obj = omezarr()
			% OMEZARR - Create a new OME-Zarr image-stack reader
			%
			%  OMEZARR_OBJ = OMEZARR()
			%
			%  Creates a Neuroscience Data Reader object for OME-Zarr
			%  volumes (a .zarr directory pinned to one pyramid via an
			%  epochstream of the form {ZARRPATH, PYRAMIDNAME}).
			%
		end % ndr.reader.omezarr.omezarr

		function info = resolveepoch(omezarr_obj, epochstreams)
			% RESOLVEEPOCH - resolve an epoch to a Zarr path + pyramid
			%
			% INFO = RESOLVEEPOCH(OMEZARR_OBJ, EPOCHSTREAMS)
			%
			% Parses the epoch's stream list to a struct describing the
			% volume without reading pixels:
			%   .zarrPath      char, absolute path to the .zarr directory
			%   .pyramidName   char, the pinned pyramid's name
			%   .pyramid       struct, the entry from
			%                    ndr.format.omezarr.listPyramids matching
			%                    pyramidName
			%   .axisIndex     struct with fields c, z, y, x giving the
			%                    (1-based) axis positions from the NGFF
			%                    axes list; NaN if the file does not have
			%                    that axis
			%
			% Accepts these epochstream shapes:
			%   { ZARRPATH, PYRAMIDNAME }         -- pinned pyramid
			%   { {ZARRPATH, PYRAMIDNAME}, ... }  -- pinned pyramid plus
			%                                        ignored sidecars
			%   ZARRPATH                          -- errors, listing the
			%                                        available pyramids
			%
			% Sidecar files handed along by the file navigator are
			% silently ignored. This mirrors tiffstack's treatment of
			% non-image companions in an epoch.

				[zarrPath, pyramidName] = ...
					ndr.reader.omezarr.parseEpochstreams(epochstreams);

				if isempty(pyramidName)
					pyramids = ndr.format.omezarr.listPyramids(zarrPath);
					names = {pyramids.name};
					error('ndr:reader:omezarr:PyramidNotPinned', ...
						['Epochstream does not pin a pyramid. ' ...
						 'Available in %s: %s. ' ...
						 'Pass {zarrPath, pyramidName} as the epochstream.'], ...
						zarrPath, ndr.reader.omezarr.formatNameList(names));
				end

				pyramids = ndr.format.omezarr.listPyramids(zarrPath);
				idx = find(strcmp({pyramids.name}, pyramidName), 1);
				if isempty(idx)
					error('ndr:reader:omezarr:UnknownPyramid', ...
						['Pyramid "%s" is not in %s. Available: %s.'], ...
						pyramidName, zarrPath, ...
						ndr.reader.omezarr.formatNameList({pyramids.name}));
				end

				info.zarrPath = zarrPath;
				info.pyramidName = pyramidName;
				info.pyramid = pyramids(idx);
				info.axisIndex = ...
					ndr.reader.omezarr.classifyAxes(pyramids(idx).axes);
		end % resolveepoch()

		function n = numframes(omezarr_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames (Z-planes) at level 1
			%
			% For a Zarr with no Z axis, returns 1.
				info = omezarr_obj.resolveepoch(epochstreams);
				shape = info.pyramid.levels(1).shape;
				if isnan(info.axisIndex.z)
					n = 1;
				else
					n = shape(info.axisIndex.z);
				end
		end % numframes()

		function sz = framesize(omezarr_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent of the stack at level 1
			%
			% Y = image height, X = image width, C = channel count,
			% Z = 1 (Z-planes are treated as T), T = total frames.
				info = omezarr_obj.resolveepoch(epochstreams);
				shape = info.pyramid.levels(1).shape;
				Y = ndr.reader.omezarr.axisSize(shape, info.axisIndex.y, 1);
				X = ndr.reader.omezarr.axisSize(shape, info.axisIndex.x, 1);
				C = ndr.reader.omezarr.axisSize(shape, info.axisIndex.c, 1);
				T = ndr.reader.omezarr.axisSize(shape, info.axisIndex.z, 1);
				Z = 1;
				sz = [Y X C Z T];
		end % framesize()

		function order = dimensionorder(omezarr_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(omezarr_obj, epochstreams, epoch_select)
			% DATATYPE - the underlying numeric class at level 1
				info = omezarr_obj.resolveepoch(epochstreams);
				dt = ndr.reader.omezarr.zarrClass(info.pyramid.levels(1).dtype);
		end % datatype()

		function t = frametimes(omezarr_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - the time of each requested frame (NaN)
			%
			% NGFF v0.4 permits a `t` axis but the lab layout does not
			% carry one; this version returns NaN for each requested
			% frame. When a real time-lapse dataset arrives, promote this
			% to read the coordinate transformation.
				if nargin<4
					frameind = 1:omezarr_obj.numframes(epochstreams, epoch_select);
				end
				t = nan(numel(frameind), 1);
		end % frametimes()

		function frames = readframes(omezarr_obj, epochstreams, epoch_select, frameind, options)
			% READFRAMES - read frames (Z-planes) from the pinned pyramid
			%
			% FRAMES = READFRAMES(OMEZARR_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			% FRAMES = READFRAMES(..., 'Level', L, 'SelectC', C, 'SelectZ', Z)
			%
			% Reads the Z-planes indexed by FRAMEIND at the requested
			% pyramid Level (default 1 = highest resolution) and returns
			% them as an array in 'YXCZT' order:
			%   size [Y X numel(C) 1 numel(FRAMEIND)]
			%
			% Level MAY default; pyramid is pinned by the epochstream
			% and cannot be overridden here.
			%
			% NOTE: pixel reading requires ndr.format.omezarr.readArray,
			% which is being implemented in issue #130. Until that lands,
			% this method errors with a clear message rather than
			% returning fake or partial data.
			arguments
				omezarr_obj
				epochstreams
				epoch_select = 1
				frameind = []
				options.Level (1,1) double {mustBeInteger, mustBePositive} = 1
				options.SelectC (1,:) double = []
				options.SelectZ (1,:) double = []
			end
				if isempty(which('ndr.format.omezarr.readArray'))
					error('ndr:reader:omezarr:readArrayNotImplemented', ...
						['ndr.reader.omezarr.readframes requires ' ...
						 'ndr.format.omezarr.readArray, which is filed ' ...
						 'as issue #130 and not yet implemented. ' ...
						 'Metadata methods (numframes, framesize, ' ...
						 'dimensionorder, datatype) work today.']);
				end

				info = omezarr_obj.resolveepoch(epochstreams);
				pyramidName = info.pyramidName;

				if isempty(frameind)
					frameind = 1:omezarr_obj.numframes(epochstreams, epoch_select);
				end

				sz = omezarr_obj.framesize(epochstreams, epoch_select);
				Y = sz(1); X = sz(2); C = sz(3);
				dt = omezarr_obj.datatype(epochstreams, epoch_select);

				zIdx = info.axisIndex.z;
				levelShape = info.pyramid.levels(options.Level).shape;
				nAxes = numel(levelShape);
				startVec = ones(1, nAxes);
				stopVec  = levelShape;

				frames = zeros(Y, X, C, 1, numel(frameind), dt);
				for i = 1:numel(frameind)
					if ~isnan(zIdx)
						startVec(zIdx) = frameind(i);
						stopVec(zIdx)  = frameind(i);
					end
					plane = ndr.format.omezarr.readArray( ...
						info.zarrPath, pyramidName, options.Level, ...
						'Region', [startVec; stopVec], ...
						'OutputType', dt);
					frames(:,:,:,1,i) = ...
						ndr.reader.omezarr.arrangePlaneYXC( ...
							plane, info.axisIndex, Y, X, C);
				end
				frames = ndr.reader.base.selectframeCZ( ...
					frames, options.SelectC, options.SelectZ);
		end % readframes()

		function ec = epochclock(omezarr_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - clock type for an OME-Zarr epoch
			%
			% Returns {ndr.time.clocktype('no_time')} because the current
			% version does not assume a `t` axis. When a time-lapse
			% dataset appears, this promotes to 'dev_local_time' with
			% times drawn from the multiscales coordinate transformation
			% along the `t` axis.
				ec = {ndr.time.clocktype('no_time')};
		end % epochclock()

		function t0t1 = t0_t1(omezarr_obj, epochstreams, epoch_select)
			% T0_T1 - begin/end times of the epoch
			%
			% Returns {[NaN NaN]} for the clockless case, matching
			% tiffstack's clockless behaviour.
				t0t1 = {[NaN NaN]};
		end % t0_t1()

		function channels = getchannelsepoch(omezarr_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - list channels for an OME-Zarr epoch
			%
			% Returns a single 'image' channel named 'image1', matching
			% the tiffstack convention: multi-channel data is returned
			% together on the C axis of READFRAMES rather than as
			% separate NDR channels.
				channels = vlt.data.emptystruct('name','type','time_channel');
				channels(1).name = 'image1';
				channels(1).type = 'image';
				channels(1).time_channel = [];
		end % getchannelsepoch()

	end % methods

	methods (Static)

		function [zarrPath, pyramidName] = parseEpochstreams(epochstreams)
			% PARSEEPOCHSTREAMS - pull the .zarr path and pyramid name
			%
			% Accepts a char/string path, a cell array containing a
			% {path, pyramid} 2-cell (optionally alongside sidecars),
			% or a flat {path, pyramid} 2-cell. Returns pyramidName as
			% '' when none is pinned so callers can raise a specific
			% error naming the available pyramids.
				pyramidName = '';
				zarrPath = '';

				if (ischar(epochstreams) || isstring(epochstreams)) && ...
						~iscell(epochstreams)
					zarrPath = char(epochstreams);
					return;
				end

				if ~iscell(epochstreams)
					error('ndr:reader:omezarr:BadEpochstream', ...
						['Epochstream must be a path or a cell array; ' ...
						 'got %s.'], class(epochstreams));
				end

				for i = 1:numel(epochstreams)
					entry = epochstreams{i};
					if iscell(entry) && numel(entry) == 2
						zarrPath = char(entry{1});
						pyramidName = char(entry{2});
						return;
					end
				end

				% Flat {path, pyramidName} form: only when the second
				% element is unambiguously a pyramid name (a string that
				% is not itself a path to an existing file or folder).
				% Otherwise, a caller who passes {path, sidecar.json}
				% would silently see "sidecar.json" adopted as a pyramid.
				if numel(epochstreams) == 2 && ...
						(ischar(epochstreams{1}) || isstring(epochstreams{1})) && ...
						(ischar(epochstreams{2}) || isstring(epochstreams{2})) && ...
						isfolder(char(epochstreams{1})) && ...
						~isfolder(char(epochstreams{2})) && ...
						~isfile(char(epochstreams{2}))
					zarrPath = char(epochstreams{1});
					pyramidName = char(epochstreams{2});
					return;
				end

				for i = 1:numel(epochstreams)
					entry = epochstreams{i};
					if (ischar(entry) || isstring(entry)) && ...
							isfolder(char(entry)) && ...
							ndr.format.omezarr.isOMEZarr(char(entry))
						zarrPath = char(entry);
						return;
					end
				end

				if isempty(zarrPath)
					error('ndr:reader:omezarr:NoZarrInEpochstream', ...
						'No OME-Zarr directory found in epochstream.');
				end
		end % parseEpochstreams()

		function axisIndex = classifyAxes(axes)
			% CLASSIFYAXES - assign c/z/y/x indices from an NGFF axes list
			%
			% Missing axes come back as NaN so callers can adapt (e.g. a
			% 2D image with no Z or C).
				axisIndex = struct('c', NaN, 'z', NaN, 'y', NaN, 'x', NaN);
				for i = 1:numel(axes)
					nm = lower(axes(i).name);
					switch nm
						case 'c', axisIndex.c = i;
						case 'z', axisIndex.z = i;
						case 'y', axisIndex.y = i;
						case 'x', axisIndex.x = i;
					end
				end
		end % classifyAxes()

		function s = axisSize(shape, idx, fallback)
			% AXISSIZE - shape(idx) if idx is a valid index, else fallback
				if isnan(idx) || idx < 1 || idx > numel(shape)
					s = fallback;
				else
					s = shape(idx);
				end
		end % axisSize()

		function dt = zarrClass(dtypeStr)
			% ZARRCLASS - map a Zarr dtype string to a MATLAB class name
			%
			% Handles the common little/big-endian numeric types. Errors
			% on anything unsupported rather than guessing.
				s = char(dtypeStr);
				% strip byte-order prefix (<, >, |, =)
				if ~isempty(s) && any(s(1) == '<>|=')
					core = s(2:end);
				else
					core = s;
				end
				map = struct( ...
					'u1', 'uint8',  'i1', 'int8', ...
					'u2', 'uint16', 'i2', 'int16', ...
					'u4', 'uint32', 'i4', 'int32', ...
					'u8', 'uint64', 'i8', 'int64', ...
					'f4', 'single', 'f8', 'double');
				if isfield(map, core)
					dt = map.(core);
				else
					error('ndr:reader:omezarr:UnsupportedDtype', ...
						'Unsupported Zarr dtype: %s', dtypeStr);
				end
		end % zarrClass()

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

		function planeYXC = arrangePlaneYXC(plane, axisIndex, Y, X, C)
			% ARRANGEPLANEYXC - permute a readArray output to [Y X C]
			%
			% readArray returns an array shaped like the on-disk axes
			% (e.g. c-z-y-x); collapse the singleton Z and permute so Y
			% is dim 1, X is dim 2, C is dim 3. Missing axes are treated
			% as size 1.
				nAxes = ndims(plane);
				% Build a permutation putting y, x, c first (in that
				% order), followed by everything else (including z, which
				% is a singleton after the region read).
				dims = 1:nAxes;
				want = [axisIndex.y, axisIndex.x, axisIndex.c];
				want = want(~isnan(want));
				rest = setdiff(dims, want, 'stable');
				perm = [want, rest];
				planePerm = permute(plane, perm);
				planeYXC = reshape(planePerm, Y, X, C);
		end % arrangePlaneYXC()

	end % methods (Static)

end % classdef
