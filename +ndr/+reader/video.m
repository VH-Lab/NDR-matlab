% NDR_READER_VIDEO - Native reader for video files (.mp4/.avi/.mov/...) using MATLAB's VideoReader
%
% This class reads video files using ONLY MATLAB's built-in VideoReader,
% with no external dependencies (in contrast to ndr.reader.imagestack, which
% delegates to the NANSEN toolbox). It is a native NDR image reader: it
% implements only the frame API (numframes, framesize, dimensionorder,
% datatype, frametimes, readframes, epochclock, t0_t1, getchannelsepoch,
% metadata) and is a sibling of ndr.reader.tiffstack.
%
% Epoch layout: an epoch is ONE video file. EPOCHSTREAMS may also contain
% companion files (e.g. an 'epochprobemap.ndi' that NDI's file navigator
% hands along with the video) or a directory; non-video files are ignored and
% directories are expanded to the files they contain. Exactly one video file
% must remain, otherwise an error is raised.
%
% Which containers can be read depends on the platform's VideoReader support
% (see "Supported Video and Audio File Formats" in the MATLAB documentation):
% Motion JPEG / uncompressed AVI and Motion JPEG 2000 are readable everywhere;
% MPEG-4 / QuickTime need the platform's media framework (GStreamer on Linux).
%
% Dimension model: each video frame is one timepoint T, with one z-plane
% (Z=1). Colour channels are the C axis: C=3 for RGB video, C=1 for
% greyscale video (VideoFormat 'Grayscale' / 'Mono8' / 'Mono16'). Frames are
% returned in 'YXCZT' order. FRAMEIND is a 1-based index into T.
%
% Timing: a video has real frame times, so the epoch clock is always
% 'dev_local_time' and FRAMETIMES are seconds from the start of the file.
% The times are measured, not assumed: the file is decoded once in order and
% VideoReader's CurrentTime is recorded immediately before each readFrame,
% which gives the presentation time of every frame and is correct for
% variable-frame-rate files, where (k-1)/FrameRate would drift. Because that
% scan decodes every frame, its result is cached per file (keyed by full path,
% size and modification date) for the rest of the MATLAB session.
%
% The frame API design is adapted from nansen.stack.ImageStack (VervaekeLab,
% https://github.com/VervaekeLab/NANSEN), as for ndr.reader.tiffstack; only
% the design (method names, dimension model) is adapted, no NANSEN code is
% used.
%
% See also: ndr.reader.tiffstack, ndr.reader.imagestack, VideoReader
%

classdef video < ndr.reader.base

	properties
	end % properties

	methods

		function video_obj = video()
			% VIDEO - Create a new native (VideoReader-backed) video reader
			%
			%  VIDEO_OBJ = VIDEO()
			%
			%  Creates a Neuroscience Data Reader object for video files, using
			%  only MATLAB's built-in VideoReader.
			%
		end % ndr.reader.video.video

		function filename = videofile(video_obj, epochstreams)
			% VIDEOFILE - return the single video file of an epoch
			%
			% FILENAME = VIDEOFILE(VIDEO_OBJ, EPOCHSTREAMS)
			%
			% EPOCHSTREAMS entries may be files or directories (directories are
			% expanded to the files they contain). Files whose extension is not
			% a recognized video extension (see VIDEOEXTENSIONS) are ignored, so
			% companion files such as 'epochprobemap.ndi' do not interfere.
			% Errors if there is not exactly one video file.
			%
				if ~iscell(epochstreams)
					epochstreams = {epochstreams};
				end
				files = {};
				for i=1:numel(epochstreams)
					entry = epochstreams{i};
					if isfolder(entry)
						d = dir(entry);
						for k=1:numel(d)
							if ~d(k).isdir
								files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
							end
						end
					else
						files{end+1} = entry; %#ok<AGROW>
					end
				end
				keep = false(1,numel(files));
				for i=1:numel(files)
					[~,~,e] = fileparts(files{i});
					keep(i) = any(strcmpi(e, ndr.reader.video.videoextensions()));
				end
				vidfiles = unique(files(keep));
				if isempty(vidfiles)
					error('ndr:reader:video:novideofile',...
						['No video file found in the epoch files. Recognized extensions: ' ...
						 strjoin(ndr.reader.video.videoextensions(), ', ') '.']);
				end
				if numel(vidfiles) > 1
					error('ndr:reader:video:multiplevideofiles',...
						['An ndr.reader.video epoch must contain exactly one video file, ' ...
						 'but %d were found: %s'], numel(vidfiles), strjoin(vidfiles, ', '));
				end
				filename = vidfiles{1};
		end % videofile()

		function v = videoobject(video_obj, epochstreams)
			% VIDEOOBJECT - construct a VideoReader for the epoch's video file
			%
			% V = VIDEOOBJECT(VIDEO_OBJ, EPOCHSTREAMS)
			%
			% Returns a new VideoReader object for the single video file of the
			% epoch (see VIDEOFILE).
			%
				v = VideoReader(video_obj.videofile(epochstreams));
		end % videoobject()

		function n = numframes(video_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames in the video
			%
			% N = NUMFRAMES(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Uses VideoReader's NumFrames. For containers where VideoReader
			% cannot report a frame count (NumFrames empty, zero or not finite),
			% the frames are counted by decoding the file once (see
			% FRAMETIMES; the result is cached).
			%
			% Adapted from nansen.stack.ImageStack NumTimepoints.
				v = video_obj.videoobject(epochstreams);
				n = ndr.reader.video.videonumframes(v);
				if isnan(n)
					n = numel(ndr.reader.video.scanframetimes(v.Path, v.Name));
				end
		end % numframes()

		function sz = framesize(video_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent of the video
			%
			% SZ = FRAMESIZE(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Y = Height, X = Width, C = colour channels (3 for RGB, 1 for
			% greyscale), Z = 1, T = number of frames. C is taken from the
			% shape of the first decoded frame, so it always agrees with what
			% READFRAMES returns.
			%
			% Adapted from nansen.stack.ImageStack/getFrameSetSize.
				v = video_obj.videoobject(epochstreams);
				[C, ~] = ndr.reader.video.channelsanddatatype(v);
				T = video_obj.numframes(epochstreams, epoch_select);
				sz = [v.Height v.Width C 1 T];
		end % framesize()

		function order = dimensionorder(video_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames ('YXCZT')
			%
			% Adapted from nansen.stack.ImageStack DataDimensionOrder.
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(video_obj, epochstreams, epoch_select)
			% DATATYPE - the numeric class of the video frames (usually 'uint8')
			%
			% DT = DATATYPE(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Taken from the class of the first decoded frame.
			%
			% Adapted from nansen.stack.ImageStack DataType.
				v = video_obj.videoobject(epochstreams);
				[~, dt] = ndr.reader.video.channelsanddatatype(v);
		end % datatype()

		function t = frametimes(video_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - the time of each requested frame, in seconds from the start of the file
			%
			% T = FRAMETIMES(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Returns a numel(FRAMEIND)x1 vector of frame times in seconds on
			% the 'dev_local_time' clock. The times are VideoReader's
			% CurrentTime recorded immediately before each frame is decoded
			% (see the class help); the scan is cached per file. If FRAMEIND
			% is omitted, all frames are returned.
			%
			% Adapted from nansen.stack.ImageStack/getFrameTimes.
				filename = video_obj.videofile(epochstreams);
				[p, nm, e] = fileparts(filename);
				all_t = ndr.reader.video.scanframetimes(p, [nm e]);
				if nargin<4 || isempty(frameind)
					frameind = 1:numel(all_t);
				end
				ndr.reader.video.checkframeind(frameind, numel(all_t));
				t = all_t(frameind(:));
		end % frametimes()

		function frames = readframes(video_obj, epochstreams, epoch_select, frameind, options)
			% READFRAMES - read video frames
			%
			% FRAMES = READFRAMES(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			% FRAMES = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
			%
			% Reads the frames indexed by FRAMEIND (1-based, any order, random
			% access via VideoReader/read) and returns them in 'YXCZT' order:
			% size [Y X numel(C) numel(Z) numel(FRAMEIND)]. Runs of consecutive
			% indices are read with one read() call each. The colour channels
			% of a frame are decoded together, so 'SelectC'/'SelectZ' are
			% applied by post-selection.
			%
			% Adapted from nansen.stack.ImageStack/getFrameSet.
			arguments
				video_obj
				epochstreams
				epoch_select = 1
				frameind = []
				options.SelectC (1,:) double = []
				options.SelectZ (1,:) double = []
			end
				v = video_obj.videoobject(epochstreams);
				n = video_obj.numframes(epochstreams, epoch_select);
				if isempty(frameind)
					frameind = 1:n;
				end
				frameind = frameind(:)';
				ndr.reader.video.checkframeind(frameind, n);
				[C, dt] = ndr.reader.video.channelsanddatatype(v);
				Y = v.Height;
				X = v.Width;
				frames = zeros(Y, X, C, 1, numel(frameind), dt);
				% split FRAMEIND into runs of consecutive increasing indices
				breaks = [0 find(diff(frameind)~=1) numel(frameind)];
				for r=1:numel(breaks)-1
					pos = breaks(r)+1:breaks(r+1);
					first = frameind(pos(1));
					last = frameind(pos(end));
					if first==last
						block = read(v, first);
					else
						block = read(v, [first last]);
					end
					frames(:,:,:,1,pos) = reshape(cast(block,dt), Y, X, C, 1, numel(pos));
				end
				frames = ndr.reader.base.selectframeCZ(frames, options.SelectC, options.SelectZ);
		end % readframes()

		function ec = epochclock(video_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the clock type(s) for a video epoch
			%
			% EC = EPOCHCLOCK(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% A video always has real frame times, so this returns
			% {ndr.time.clocktype('dev_local_time')}.
			%
				ec = {ndr.time.clocktype('dev_local_time')};
		end % epochclock()

		function t0t1 = t0_t1(video_obj, epochstreams, epoch_select)
			% T0_T1 - return the [t0 t1] begin/end times of a video epoch
			%
			% T0T1 = T0_T1(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Returns {[firsttime lasttime]} on 'dev_local_time', where these
			% are the times of the first and last frames (the same convention
			% as ndr.reader.tiffstack and ndr.reader.imagestack).
			%
				t = video_obj.frametimes(epochstreams, epoch_select);
				if isempty(t)
					t0t1 = {[NaN NaN]};
				else
					t0t1 = {[t(1) t(end)]};
				end
		end % t0_t1()

		function channels = getchannelsepoch(video_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - list the channels available for a video epoch
			%
			% Returns a single 'image' channel named 'image1'. The colour
			% channels of the video are returned together as the C axis of
			% READFRAMES rather than as separate NDR channels.
			%
				channels = vlt.data.emptystruct('name','type','time_channel');
				channels(1).name = 'image1';
				channels(1).type = 'image';
				channels(1).time_channel = [];
		end % getchannelsepoch()

		function m = metadata(video_obj, epochstreams, epoch_select)
			% METADATA - standardized image-acquisition metadata for a video epoch
			%
			% M = METADATA(VIDEO_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% A video is not a raster scan, so this returns the default struct
			% from ndr.reader.base.emptyimagemetadata (israster=false) with only
			% FRAME_PERIOD filled in, as 1/FrameRate (seconds) from the
			% container header.
			%
			% See also: ndr.reader.base/metadata
				m = ndr.reader.base.emptyimagemetadata();
				v = video_obj.videoobject(epochstreams);
				if ~isempty(v.FrameRate) && v.FrameRate > 0
					m.frame_period = 1/double(v.FrameRate);
				end
		end % metadata()

	end % methods

	methods (Static)

		function exts = videoextensions()
			% VIDEOEXTENSIONS - file extensions treated as video files
			%
			% EXTS = ndr.reader.video.videoextensions()
			%
				exts = {'.avi','.mp4','.m4v','.mov','.mj2','.mpg','.mpeg','.wmv','.asf','.ogg','.ogv','.mkv','.webm'};
		end % videoextensions()

		function n = videonumframes(v)
			% VIDEONUMFRAMES - frame count from VideoReader, or NaN if unavailable
			%
			% N = ndr.reader.video.videonumframes(V)
			%
				n = NaN;
				try
					nf = v.NumFrames;
					if ~isempty(nf) && isfinite(nf) && nf > 0
						n = double(nf);
					end
				catch
					n = NaN;
				end
		end % videonumframes()

		function [C, dt] = channelsanddatatype(v)
			% CHANNELSANDDATATYPE - colour channel count and class from the first frame
			%
			% [C, DT] = ndr.reader.video.channelsanddatatype(V)
			%
			% Decodes frame 1 of VideoReader V and returns its number of colour
			% channels (size along dim 3: 3 for RGB, 1 for greyscale) and its
			% numeric class.
			%
				f = read(v, 1);
				C = size(f, 3);
				dt = class(f);
		end % channelsanddatatype()

		function checkframeind(frameind, n)
			% CHECKFRAMEIND - error unless FRAMEIND are integer indices in 1..N
			%
			% ndr.reader.video.checkframeind(FRAMEIND, N)
			%
				if any(frameind < 1) || any(frameind > n) || any(frameind ~= round(frameind))
					error('ndr:reader:video:badframeind',...
						'Frame indices must be integers between 1 and %d.', n);
				end
		end % checkframeind()

		function t = scanframetimes(folder, name)
			% SCANFRAMETIMES - per-frame times of a video file, measured by decoding it once
			%
			% T = ndr.reader.video.scanframetimes(FOLDER, NAME)
			%
			% Opens FULLFILE(FOLDER, NAME) with VideoReader and, frame by frame,
			% records CurrentTime (the presentation time of the next frame, in
			% seconds from the start of the file) before calling readFrame.
			% Returns a column vector with one entry per frame. The result is
			% cached for the MATLAB session, keyed by the full path, byte size
			% and modification date, so a file changed on disk is re-scanned.
			%
				persistent cache
				if isempty(cache)
					cache = containers.Map('KeyType','char','ValueType','any');
				end
				filename = fullfile(folder, name);
				d = dir(filename);
				if isempty(d)
					error('ndr:reader:video:nofile','Video file %s not found.', filename);
				end
				key = sprintf('%s|%d|%.10f', filename, d(1).bytes, d(1).datenum);
				if isKey(cache, key)
					t = cache(key);
					return;
				end
				v = VideoReader(filename);
				nguess = ndr.reader.video.videonumframes(v);
				if isnan(nguess)
					nguess = 0;
				end
				t = zeros(nguess, 1);
				k = 0;
				while hasFrame(v)
					k = k + 1;
					t(k,1) = v.CurrentTime;
					readFrame(v);
				end
				t = t(1:k);
				cache(key) = t;
		end % scanframetimes()

	end % methods (Static)

end % classdef
