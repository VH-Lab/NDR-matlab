% NDR_READER_TIFFSTACK - Reader class for multipage / multichannel TIFF image stacks
%
% This class reads image-series data from multipage TIFF files using only
% MATLAB's built-in TIFF support (imfinfo / imread / Tiff), with no external
% dependencies. It is a native NDR image reader: it implements ONLY the
% frame API (numframes, framesize, dimensionorder, datatype, frametimes,
% readframes, epochclock, t0_t1) and is a sibling of the regularly-sampled
% readers (e.g. ndr.reader.intan_rhd), not a subclass of them.
%
% The frame API design is adapted from nansen.stack.ImageStack (VervaekeLab,
% https://github.com/VervaekeLab/NANSEN). The following methods map onto
% nansen.stack.ImageStack methods of similar purpose:
%
%   ndr.reader (NDR)       | nansen.stack.ImageStack (NANSEN)
%   -----------------------|---------------------------------
%   readframes             | getFrameSet
%   framesize              | getFrameSetSize
%   numframes              | NumTimepoints / NumPlanes
%   dimensionorder         | DimensionOrder / DataDimensionOrder
%   datatype               | DataType
%   frametimes             | getFrameTimes
%
% Only the *design* (method names, dimension model) is adapted; no NANSEN
% source code is used, so no NANSEN dependency is introduced.
%
% Dimension model (v1): the pages of a multipage TIFF are treated as the
% time axis T, with one z-plane (Z=1). Channels (C) come from the TIFF's
% samples-per-pixel. Frames are returned in 'YXCZT' order.
%
% Timing: if a sidecar text file named '<tiffbasename>_frametimes.txt'
% exists next to the TIFF (one time in seconds per line, one per page), the
% epoch is treated as a timeseries with clock 'dev_local_time' and those
% values are returned by FRAMETIMES. If no sidecar exists, the epoch is
% clockless ('no_time'): the frames are an ordered stack (e.g. a slide scan
% or z-stack) and FRAMETIMES returns NaN.
%

classdef tiffstack < ndr.reader.base

	properties
	end % properties

	methods

		function tiffstack_obj = tiffstack()
			% TIFFSTACK - Create a new multipage TIFF image-stack reader
			%
			%  TIFFSTACK_OBJ = TIFFSTACK()
			%
			%  Creates a Neuroscience Data Reader object for multipage TIFF
			%  image stacks.
			%
		end % ndr.reader.tiffstack.tiffstack

		function filename = filenamefromepochfiles(tiffstack_obj, filename_array)
			% FILENAMEFROMEPOCHFILES - return the TIFF file name from a set of epoch files
			%
			% FILENAME = FILENAMEFROMEPOCHFILES(TIFFSTACK_OBJ, FILENAME_ARRAY)
			%
			% Given a cell array of full-path file names FILENAME_ARRAY that
			% comprise an epoch, returns the single TIFF file (extension .tif
			% or .tiff, case-insensitive). Errors if zero or more than one
			% TIFF file is present.
			%
				if ~iscell(filename_array)
					filename_array = {filename_array};
				end
				keep = false(1,numel(filename_array));
				for i=1:numel(filename_array)
					[~,~,ext] = fileparts(filename_array{i});
					keep(i) = any(strcmpi(ext,{'.tif','.tiff'}));
				end
				matches = filename_array(keep);
				if numel(matches)<1
					error('ndr:reader:tiffstack:nofile','No .tif/.tiff file found in epoch files.');
				elseif numel(matches)>1
					error('ndr:reader:tiffstack:multiplefiles','More than one .tif/.tiff file found in epoch files.');
				end
				filename = matches{1};
		end % filenamefromepochfiles()

		function info = tiffinfo(tiffstack_obj, epochstreams)
			% TIFFINFO - return the imfinfo structure for the epoch's TIFF file
			%
			% INFO = TIFFINFO(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
				filename = tiffstack_obj.filenamefromepochfiles(epochstreams);
				info = imfinfo(filename);
		end % tiffinfo()

		function n = numframes(tiffstack_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames (TIFF pages) in the epoch
			%
			% N = NUMFRAMES(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Adapted from nansen.stack.ImageStack NumTimepoints.
				info = tiffstack_obj.tiffinfo(epochstreams);
				n = numel(info);
		end % numframes()

		function sz = framesize(tiffstack_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent of the TIFF stack, without reading pixels
			%
			% SZ = FRAMESIZE(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Y = image height, X = image width, C = samples per pixel,
			% Z = 1 (pages are treated as T), T = number of pages.
			%
			% Adapted from nansen.stack.ImageStack/getFrameSetSize.
				info = tiffstack_obj.tiffinfo(epochstreams);
				Y = info(1).Height;
				X = info(1).Width;
				if isfield(info,'SamplesPerPixel') && ~isempty(info(1).SamplesPerPixel)
					C = info(1).SamplesPerPixel;
				else
					C = 1;
				end
				Z = 1;
				T = numel(info);
				sz = [Y X C Z T];
		end % framesize()

		function order = dimensionorder(tiffstack_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames ('YXCZT')
			%
			% ORDER = DIMENSIONORDER(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Adapted from nansen.stack.ImageStack DataDimensionOrder.
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(tiffstack_obj, epochstreams, epoch_select)
			% DATATYPE - the underlying numeric class of the TIFF pixel data
			%
			% DT = DATATYPE(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Adapted from nansen.stack.ImageStack DataType.
				info = tiffstack_obj.tiffinfo(epochstreams);
				bits = info(1).BitsPerSample(1);
				fmt = 'Unsigned';
				if isfield(info,'SampleFormat') && ~isempty(info(1).SampleFormat)
					fmt = info(1).SampleFormat;
				end
				switch lower(fmt)
					case {'ieeefloat','float'}
						if bits<=32, dt = 'single'; else, dt = 'double'; end
					case {'two''s complement signed integer','signed','signed integer'}
						dt = ['int' int2str(bits)];
					otherwise % unsigned integer
						dt = ['uint' int2str(bits)];
				end
		end % datatype()

		function frametimesfile = frametimesfilename(tiffstack_obj, epochstreams)
			% FRAMETIMESFILENAME - return the path to the optional frame-times sidecar
			%
			% FRAMETIMESFILE = FRAMETIMESFILENAME(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
			% Returns '<tiffbasename>_frametimes.txt' next to the TIFF file.
			% The file may or may not exist; see HASFRAMETIMES.
			%
				filename = tiffstack_obj.filenamefromepochfiles(epochstreams);
				[p,n,~] = fileparts(filename);
				frametimesfile = fullfile(p,[n '_frametimes.txt']);
		end % frametimesfilename()

		function b = hasframetimes(tiffstack_obj, epochstreams)
			% HASFRAMETIMES - does this epoch have an explicit frame-times sidecar?
			%
			% B = HASFRAMETIMES(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
				b = isfile(tiffstack_obj.frametimesfilename(epochstreams));
		end % hasframetimes()

		function t = frametimes(tiffstack_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - the time of each requested frame, in EPOCHCLOCK units
			%
			% T = FRAMETIMES(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% If a '<tiffbasename>_frametimes.txt' sidecar exists (one time in
			% seconds per page), returns those times for FRAMEIND (clock
			% 'dev_local_time'). Otherwise returns NaN for each frame (clock
			% 'no_time').
			%
			% Adapted from nansen.stack.ImageStack/getFrameTimes.
				if nargin<4
					frameind = 1:tiffstack_obj.numframes(epochstreams, epoch_select);
				end
				if tiffstack_obj.hasframetimes(epochstreams)
					all_t = load(tiffstack_obj.frametimesfilename(epochstreams),'-ascii');
					all_t = all_t(:);
					t = all_t(frameind);
				else
					t = nan(numel(frameind),1);
				end
		end % frametimes()

		function frames = readframes(tiffstack_obj, epochstreams, epoch_select, frameind)
			% READFRAMES - read TIFF pages as image frames
			%
			% FRAMES = READFRAMES(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Reads the TIFF pages indexed by FRAMEIND and returns them as an
			% array in 'YXCZT' order: size [Y X C 1 numel(FRAMEIND)].
			%
			% Adapted from nansen.stack.ImageStack/getFrameSet.
				if nargin<4
					frameind = 1:tiffstack_obj.numframes(epochstreams, epoch_select);
				end
				filename = tiffstack_obj.filenamefromepochfiles(epochstreams);
				sz = tiffstack_obj.framesize(epochstreams, epoch_select);
				Y = sz(1); X = sz(2); C = sz(3);
				dt = tiffstack_obj.datatype(epochstreams, epoch_select);
				frames = zeros(Y, X, C, 1, numel(frameind), dt);
				for i=1:numel(frameind)
					im = imread(filename, frameind(i));
					% im is Y x X (C=1) or Y x X x C
					frames(:,:,:,1,i) = reshape(cast(im,dt), Y, X, C);
				end
		end % readframes()

		function ec = epochclock(tiffstack_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the clock type(s) for an image epoch
			%
			% EC = EPOCHCLOCK(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns {ndr.time.clocktype('dev_local_time')} when a frame-times
			% sidecar is present (a movie), and {ndr.time.clocktype('no_time')}
			% otherwise (an ordered clockless stack / slide scan).
			%
				if tiffstack_obj.hasframetimes(epochstreams)
					ec = {ndr.time.clocktype('dev_local_time')};
				else
					ec = {ndr.time.clocktype('no_time')};
				end
		end % epochclock()

		function t0t1 = t0_t1(tiffstack_obj, epochstreams, epoch_select)
			% T0_T1 - return the [t0 t1] begin/end times of an image epoch
			%
			% T0T1 = T0_T1(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% For a movie (frame-times sidecar present) returns
			% {[firsttime lasttime]} in dev_local_time. For a clockless stack
			% returns {[NaN NaN]}.
			%
				if tiffstack_obj.hasframetimes(epochstreams)
					t = tiffstack_obj.frametimes(epochstreams, epoch_select);
					t0t1 = {[t(1) t(end)]};
				else
					t0t1 = {[NaN NaN]};
				end
		end % t0_t1()

		function channels = getchannelsepoch(tiffstack_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - list the channels available for an image epoch
			%
			% CHANNELS = GETCHANNELSEPOCH(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns a single 'image' channel named 'image1'. Multi-channel
			% TIFFs are returned together as the C axis of READFRAMES rather
			% than as separate NDR channels in v1.
			%
				channels = vlt.data.emptystruct('name','type','time_channel');
				channels(1).name = 'image1';
				channels(1).type = 'image';
				channels(1).time_channel = [];
		end % getchannelsepoch()

	end % methods

end % classdef
