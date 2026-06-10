% NDR_READER_TIFFSTACK - Reader class for multipage / multichannel TIFF image stacks
%
% This class reads image-series data from TIFF files using only MATLAB's
% built-in TIFF support (imfinfo / imread / Tiff), with no external
% dependencies. It is a native NDR image reader: it implements ONLY the
% frame API (numframes, framesize, dimensionorder, datatype, frametimes,
% readframes, epochclock, t0_t1) and is a sibling of the regularly-sampled
% readers (e.g. ndr.reader.intan_rhd), not a subclass of them.
%
% Epoch layout (single file OR a directory of files):
%   An epoch may be described by any of the following EPOCHSTREAMS:
%     - a single multipage TIFF file (each page is a frame);
%     - a directory (each TIFF in it contributes its page(s), in name order);
%     - an explicit list of TIFF files (each contributes its page(s)).
%   The directory form is the intended layout for acquisitions that write
%   many single-plane files (e.g. Prairie View), so the epoch can be anchored
%   on the directory rather than enumerating thousands of filenames. Frames
%   are ordered by file name (lexical; acquisition systems zero-pad indices)
%   and then by page within each file. The stack is assumed homogeneous:
%   every file has the same height/width/channels/datatype and the same
%   number of pages as the first file.
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
% Dimension model (v1): the pages across the ordered files are treated as the
% time axis T, with one z-plane (Z=1). Channels (C) come from the TIFF's
% samples-per-pixel. Frames are returned in 'YXCZT' order.
%
% Timing: frame times come from an optional sidecar text file (one time in
% seconds per frame, in frame order). For a single-file epoch the sidecar is
% '<tiffbasename>_frametimes.txt'; for a directory/multi-file epoch it is
% 'frametimes.txt' in the epoch directory. If a sidecar is present the epoch
% is a timeseries with clock 'dev_local_time'; otherwise it is clockless
% ('no_time') and FRAMETIMES returns NaN.
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
			%  Creates a Neuroscience Data Reader object for TIFF image stacks
			%  (a single multipage TIFF, or a directory / list of TIFFs).
			%
		end % ndr.reader.tiffstack.tiffstack

		function files = imagefiles(tiffstack_obj, epochstreams)
			% IMAGEFILES - return the ordered list of TIFF files for an epoch
			%
			% FILES = IMAGEFILES(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
			% EPOCHSTREAMS entries may be, in any combination:
			%   - a single TIFF file (used directly);
			%   - a directory (its .tif/.tiff contents are expanded);
			%   - an ANCHOR file that is not itself a TIFF (e.g. a Prairie
			%     '.xml'/'.pcf' config, or another per-epoch marker the file
			%     navigator matched on) -- the TIFFs are then taken from the
			%     anchor's parent directory.
			% Returns a cell array of full-path TIFF file names ordered by name.
			% Errors if no TIFF files are found.
			%
			% Resolving an anchor file to its directory is what lets the file
			% navigator discover epochs by matching a marker file (a bare
			% directory is not matchable) while the reader still reads the
			% whole stack. Format-specific parsing of the anchor (e.g. reading
			% frame times out of a Prairie config) layers on top of this.
			%
				if ~iscell(epochstreams)
					epochstreams = {epochstreams};
				end
				files = {};
				for i=1:numel(epochstreams)
					entry = epochstreams{i};
					if isfolder(entry)
						files = [files, tiffstack_obj.tiffsindir(entry)]; %#ok<AGROW>
					else
						[~,~,ext] = fileparts(entry);
						if any(strcmpi(ext,{'.tif','.tiff'}))
							files{end+1} = entry; %#ok<AGROW>
						else
							% an anchor / marker file: take TIFFs from its folder
							files = [files, tiffstack_obj.tiffsindir(fileparts(entry))]; %#ok<AGROW>
						end
					end
				end
				files = unique(files); % unique also sorts lexically
				if isempty(files)
					error('ndr:reader:tiffstack:nofile',...
						'No .tif/.tiff file found in epoch files or directories.');
				end
		end % imagefiles()

		function files = tiffsindir(tiffstack_obj, folder)
			% TIFFSINDIR - return the full-path .tif/.tiff files in a folder
			%
			% FILES = TIFFSINDIR(TIFFSTACK_OBJ, FOLDER)
			%
				files = {};
				if isempty(folder), folder = '.'; end
				d = [dir(fullfile(folder,'*.tif')); dir(fullfile(folder,'*.tiff'))];
				for k=1:numel(d)
					if ~d(k).isdir
						files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
					end
				end
		end % tiffsindir()

		function filename = filenamefromepochfiles(tiffstack_obj, filename_array)
			% FILENAMEFROMEPOCHFILES - return the first TIFF file name for an epoch
			%
			% FILENAME = FILENAMEFROMEPOCHFILES(TIFFSTACK_OBJ, FILENAME_ARRAY)
			%
			% Returns the first (name-ordered) TIFF file of the epoch. Kept for
			% backward compatibility and for callers that just need a
			% representative file; use IMAGEFILES for the full ordered list.
			%
				files = tiffstack_obj.imagefiles(filename_array);
				filename = files{1};
		end % filenamefromepochfiles()

		function info = resolveepoch(tiffstack_obj, epochstreams)
			% RESOLVEEPOCH - resolve an epoch to an ordered frame layout
			%
			% INFO = RESOLVEEPOCH(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
			% Returns a struct describing the epoch's frames without reading
			% pixels:
			%   .files        ordered cell of TIFF file names
			%   .dirpath      the directory anchoring the epoch (parent of the
			%                    files), used for the frame-times sidecar
			%   .pagesperfile number of pages in each file (homogeneous; taken
			%                    from the first file)
			%   .nframes      total number of frames (pagesperfile * numfiles)
			%   .firstinfo    imfinfo struct of the first file
			%
				files = tiffstack_obj.imagefiles(epochstreams);
				firstinfo = imfinfo(files{1});
				info.files = files;
				info.dirpath = fileparts(files{1});
				info.pagesperfile = numel(firstinfo);
				info.nframes = info.pagesperfile * numel(files);
				info.firstinfo = firstinfo;
		end % resolveepoch()

		function [filename, page] = framesource(tiffstack_obj, info, frameidx)
			% FRAMESOURCE - map a global frame index to a (file, page) source
			%
			% [FILENAME, PAGE] = FRAMESOURCE(TIFFSTACK_OBJ, INFO, FRAMEIDX)
			%
			% Given the INFO struct from RESOLVEEPOCH and a 1-based global
			% frame index FRAMEIDX, returns the file and 1-based page within
			% that file that hold the frame.
			%
				ppf = info.pagesperfile;
				fileidx = floor((frameidx-1)/ppf) + 1;
				page = mod(frameidx-1, ppf) + 1;
				filename = info.files{fileidx};
		end % framesource()

		function n = numframes(tiffstack_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames in the epoch (across all files/pages)
			%
			% Adapted from nansen.stack.ImageStack NumTimepoints.
				info = tiffstack_obj.resolveepoch(epochstreams);
				n = info.nframes;
		end % numframes()

		function sz = framesize(tiffstack_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent of the stack, without reading pixels
			%
			% Y = image height, X = image width, C = samples per pixel,
			% Z = 1 (pages/files are treated as T), T = total frames.
			%
			% Adapted from nansen.stack.ImageStack/getFrameSetSize.
				info = tiffstack_obj.resolveepoch(epochstreams);
				fi = info.firstinfo;
				Y = fi(1).Height;
				X = fi(1).Width;
				if isfield(fi,'SamplesPerPixel') && ~isempty(fi(1).SamplesPerPixel)
					C = fi(1).SamplesPerPixel;
				else
					C = 1;
				end
				Z = 1;
				T = info.nframes;
				sz = [Y X C Z T];
		end % framesize()

		function order = dimensionorder(tiffstack_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames ('YXCZT')
			%
			% Adapted from nansen.stack.ImageStack DataDimensionOrder.
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(tiffstack_obj, epochstreams, epoch_select)
			% DATATYPE - the underlying numeric class of the TIFF pixel data
			%
			% Adapted from nansen.stack.ImageStack DataType.
				info = tiffstack_obj.resolveepoch(epochstreams);
				dt = ndr.reader.tiffstack.tiffclass(info.firstinfo);
		end % datatype()

		function frametimesfile = frametimesfilename(tiffstack_obj, epochstreams)
			% FRAMETIMESFILENAME - return the path to the frame-times sidecar
			%
			% FRAMETIMESFILE = FRAMETIMESFILENAME(TIFFSTACK_OBJ, EPOCHSTREAMS)
			%
			% For a single-file epoch this is '<tiffbasename>_frametimes.txt'
			% next to the TIFF; for a directory/multi-file epoch it is
			% 'frametimes.txt' in the epoch directory. The file may or may not
			% exist; see HASFRAMETIMES.
			%
				info = tiffstack_obj.resolveepoch(epochstreams);
				if numel(info.files)==1
					[p,n,~] = fileparts(info.files{1});
					frametimesfile = fullfile(p,[n '_frametimes.txt']);
				else
					frametimesfile = fullfile(info.dirpath,'frametimes.txt');
				end
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
			% If a frame-times sidecar exists (one time in seconds per frame,
			% in frame order), returns those times for FRAMEIND (clock
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
			% READFRAMES - read frames (TIFF pages across the ordered files)
			%
			% FRAMES = READFRAMES(TIFFSTACK_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Reads the frames indexed by FRAMEIND and returns them as an array
			% in 'YXCZT' order: size [Y X C 1 numel(FRAMEIND)].
			%
			% Adapted from nansen.stack.ImageStack/getFrameSet.
				info = tiffstack_obj.resolveepoch(epochstreams);
				if nargin<4
					frameind = 1:info.nframes;
				end
				sz = tiffstack_obj.framesize(epochstreams, epoch_select);
				Y = sz(1); X = sz(2); C = sz(3);
				dt = tiffstack_obj.datatype(epochstreams, epoch_select);
				frames = zeros(Y, X, C, 1, numel(frameind), dt);
				for i=1:numel(frameind)
					[fname, page] = tiffstack_obj.framesource(info, frameind(i));
					im = imread(fname, page);
					frames(:,:,:,1,i) = reshape(cast(im,dt), Y, X, C);
				end
		end % readframes()

		function ec = epochclock(tiffstack_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the clock type(s) for an image epoch
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

	methods (Static)
		function dt = tiffclass(fi)
			% TIFFCLASS - map an imfinfo struct to a MATLAB numeric class
			%
			% DT = ndr.reader.tiffstack.tiffclass(FI)
			%
			% Given an imfinfo struct FI (or its first element), returns the
			% underlying numeric class string (e.g. 'uint16', 'int16',
			% 'single') implied by its BitsPerSample and SampleFormat.
			%
				bits = fi(1).BitsPerSample(1);
				fmt = 'Unsigned';
				if isfield(fi,'SampleFormat') && ~isempty(fi(1).SampleFormat)
					fmt = fi(1).SampleFormat;
				end
				switch lower(fmt)
					case {'ieeefloat','float'}
						if bits<=32, dt = 'single'; else, dt = 'double'; end
					case {'two''s complement signed integer','signed','signed integer'}
						dt = ['int' int2str(bits)];
					otherwise % unsigned integer
						dt = ['uint' int2str(bits)];
				end
		end % tiffclass()
	end % methods (Static)

end % classdef
