% NDR_READER_IMAGESTACK - Reader backend wrapping nansen.stack.ImageStack
%
% This class reads image-series data by delegating to NANSEN's
% nansen.stack.ImageStack (VervaekeLab, https://github.com/VervaekeLab/NANSEN).
% Through a single reader string it gives NDR access to ALL of NANSEN's
% format coverage, because ImageStack dispatches internally to its own
% +virtual adapters (ScanImage, PrairieView, ThorLabs, HDF5, multipage TIFF,
% Video, ...).
%
% NANSEN is declared in tools/requirements.txt (installed by
% matbox.installRequirements, including on CI), but it is touched only when
% this reader is used: it is never required by NDR's native readers (e.g.
% ndr.reader.tiffstack) and never reaches NDI. If NANSEN is not on the
% MATLAB path, the methods of this class raise a clear error.
%
% Attribution: this reader's frame API and dimension model are adapted from
% nansen.stack.ImageStack (VervaekeLab). The method correspondence is:
%
%   ndr.reader (NDR)       | nansen.stack.ImageStack (NANSEN)
%   -----------------------|---------------------------------
%   readframes             | getFrameSet
%   framesize              | getFrameSetSize / Num* + ImageHeight/ImageWidth
%   numframes              | NumTimepoints / NumPlanes
%   dimensionorder         | DataDimensionOrder
%   datatype               | DataType
%   frametimes             | getFrameTimes
%
% License note: this class WRAPS the public ImageStack API (it does not copy
% NANSEN source), so it does not redistribute NANSEN code. Before lifting any
% NANSEN source into NDR, confirm NANSEN's license is compatible.
%

classdef imagestack < ndr.reader.base

	properties
	end % properties

	methods

		function imagestack_obj = imagestack()
			% IMAGESTACK - Create a new NANSEN-ImageStack-backed image reader
			%
			%  IMAGESTACK_OBJ = IMAGESTACK()
			%
		end % ndr.reader.imagestack.imagestack

		function imsrc = imagesource(imagestack_obj, filename_array)
			% IMAGESOURCE - resolve epoch files to the path(s) handed to nansen.stack.open
			%
			% IMSRC = IMAGESOURCE(IMAGESTACK_OBJ, FILENAME_ARRAY)
			%
			% FILENAME_ARRAY (the epoch streams) may contain single files,
			% directories, or a mix. nansen.stack.open does NOT accept a bare
			% folder, so a directory is expanded here into the ordered list of
			% image files it contains. Returns either:
			%   - a single char path (when the epoch is one file), or
			%   - a cell array of same-extension image file paths (when the
			%     epoch is a directory / multi-file acquisition, e.g. Prairie
			%     View). open() then selects the adapter and, for TIFFs, sniffs
			%     the Software tag to dispatch to ScanImage/Prairie/etc.
			%
			% Directory expansion gathers the most common image extension among
			% the directory's files so that companion files (e.g. Prairie .xml
			% / .env) are not passed to open() (which requires one extension).
			%
				if ~iscell(filename_array)
					filename_array = {filename_array};
				end
				if isempty(filename_array)
					error('ndr:reader:imagestack:nofile','No file found in epoch files.');
				end

				hasfolder = false;
				for i=1:numel(filename_array)
					if isfolder(filename_array{i}), hasfolder = true; break; end
				end

				if ~hasfolder
					if numel(filename_array)==1
						imsrc = filename_array{1};
					else
						imsrc = imagestack_obj.sameextfiles(filename_array);
					end
					return;
				end

				% expand directories (and keep any explicitly-listed files)
				files = {};
				for i=1:numel(filename_array)
					entry = filename_array{i};
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
				imfiles = imagestack_obj.sameextfiles(files);
				if numel(imfiles)==1
					imsrc = imfiles{1};
				else
					imsrc = imfiles;
				end
		end % imagesource()

		function imfiles = sameextfiles(imagestack_obj, files)
			% SAMEEXTFILES - keep the image files sharing the most common image extension
			%
			% IMFILES = SAMEEXTFILES(IMAGESTACK_OBJ, FILES)
			%
			% From a list FILES, returns (name-ordered) those whose extension
			% is the most common image extension present, so that one
			% same-extension set is passed to nansen.stack.open. Non-image
			% companion files (e.g. .xml, .env, .txt) are dropped.
			%
				imgexts = {'.tif','.tiff','.h5','.hdf5','.raw','.avi','.mp4','.mov','.png','.jpg','.jpeg','.bmp'};
				exts = {};
				for i=1:numel(files)
					[~,~,e] = fileparts(files{i});
					exts{end+1} = lower(e); %#ok<AGROW>
				end
				keep = ismember(exts, imgexts);
				files = files(keep);
				exts = exts(keep);
				if isempty(files)
					error('ndr:reader:imagestack:noimagefile',...
						'No recognized image files found in the epoch directory/files.');
				end
				% choose the most common image extension
				uext = unique(exts);
				counts = cellfun(@(x) sum(strcmp(exts,x)), uext);
				[~,mi] = max(counts);
				chosen = uext{mi};
				imfiles = sort(files(strcmp(exts,chosen)));
		end % sameextfiles()

		function s = imagestackobject(imagestack_obj, epochstreams)
			% IMAGESTACKOBJECT - construct the underlying nansen.stack.ImageStack
			%
			% S = IMAGESTACKOBJECT(IMAGESTACK_OBJ, EPOCHSTREAMS)
			%
			% Builds a nansen.stack.ImageStack for the epoch by opening the
			% file(s) with nansen.stack.open (which selects the right +virtual
			% adapter from the file extension, and for TIFFs sniffs the Software
			% tag) and wrapping the resulting virtual data object. A directory
			% epoch is expanded to its ordered image files first (see
			% IMAGESOURCE), since open() does not accept a bare folder. Errors
			% with a clear message if NANSEN is not installed.
			%
				if exist('nansen.stack.ImageStack','class')~=8
					error('ndr:reader:imagestack:nonansen',...
						['nansen.stack.ImageStack was not found on the MATLAB path. ' ...
						 'The ndr.reader.imagestack backend requires NANSEN ' ...
						 '(https://github.com/VervaekeLab/NANSEN), installable via ' ...
						 'tools/requirements.txt (matbox.installRequirements). Use ' ...
						 'ndr.reader.tiffstack for plain multipage TIFFs to avoid this dependency.']);
				end
				imsrc = imagestack_obj.imagesource(epochstreams);
				virtualData = nansen.stack.open(imsrc);
				s = nansen.stack.ImageStack(virtualData);
		end % imagestackobject()

		function n = numframes(imagestack_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of frames in an image epoch
			%
			% Adapted from nansen.stack.ImageStack NumTimepoints/NumPlanes.
				s = imagestack_obj.imagestackobject(epochstreams);
				n = s.NumTimepoints * s.NumPlanes;
		end % numframes()

		function sz = framesize(imagestack_obj, epochstreams, epoch_select)
			% FRAMESIZE - the [Y X C Z T] extent without reading pixels
			%
			% Adapted from nansen.stack.ImageStack ImageHeight/ImageWidth/Num*.
				s = imagestack_obj.imagestackobject(epochstreams);
				sz = [s.ImageHeight s.ImageWidth s.NumChannels s.NumPlanes s.NumTimepoints];
		end % framesize()

		function order = dimensionorder(imagestack_obj, epochstreams, epoch_select)
			% DIMENSIONORDER - the dimension order of returned frames
			%
			% Adapted from nansen.stack.ImageStack DataDimensionOrder. We
			% normalize NANSEN's order to NDR's canonical 'YXCZT'.
				order = 'YXCZT';
		end % dimensionorder()

		function dt = datatype(imagestack_obj, epochstreams, epoch_select)
			% DATATYPE - the underlying numeric class of the image data
			%
			% Adapted from nansen.stack.ImageStack DataType.
				s = imagestack_obj.imagestackobject(epochstreams);
				dt = s.DataType;
		end % datatype()

		function t = frametimes(imagestack_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - the time of each requested frame, in EPOCHCLOCK units
			%
			% Adapted from nansen.stack.ImageStack/getFrameTimes. Always
			% returns a numel(FRAMEIND)x1 vector. When NANSEN reports no
			% timing information for the format (getFrameTimes errors, or
			% returns empty/short because TimeIncrement is unset), every
			% requested frame is reported as NaN so the result length always
			% matches FRAMEIND. The duration type is converted to seconds.
				if nargin<4
					frameind = 1:imagestack_obj.numframes(epochstreams, epoch_select);
				end
				n = numel(frameind);
				try
					s = imagestack_obj.imagestackobject(epochstreams);
					t = s.getFrameTimes(frameind);
					if isduration(t)
						t = seconds(t);
					end
					t = double(t(:));
				catch
					t = [];
				end
				% Coerce anything that is not a full-length finite-or-NaN
				% vector into a NaN vector of the correct length, so the
				% (epochfiles, frameind) -> times contract always holds even
				% for formats whose adapter supplies no timing metadata.
				if numel(t) ~= n
					t = nan(n,1);
				end
		end % frametimes()

		function frames = readframes(imagestack_obj, epochstreams, epoch_select, frameind)
			% READFRAMES - read image frames from an epoch
			%
			% Adapted from nansen.stack.ImageStack/getFrameSet. ImageStack
			% returns data in YXCZT order but SQUEEZED along singleton
			% dimensions; we restore the full [Y X C Z nframes] shape so the
			% NDR frame contract (explicit singleton C/Z) holds.
				if nargin<4
					frameind = 1:imagestack_obj.numframes(epochstreams, epoch_select);
				end
				s = imagestack_obj.imagestackobject(epochstreams);
				frames = s.getFrameSet(frameind);
				sz = [s.ImageHeight s.ImageWidth s.NumChannels s.NumPlanes];
				frames = reshape(frames, [sz(1) sz(2) sz(3) sz(4) numel(frameind)]);
		end % readframes()

		function ec = epochclock(imagestack_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - return the clock type(s) for an image epoch
			%
			% Returns 'dev_local_time' when NANSEN provides finite frame times,
			% otherwise 'no_time'.
				t = imagestack_obj.frametimes(epochstreams, epoch_select, 1);
				if ~isempty(t) && all(isfinite(t))
					ec = {ndr.time.clocktype('dev_local_time')};
				else
					ec = {ndr.time.clocktype('no_time')};
				end
		end % epochclock()

		function t0t1 = t0_t1(imagestack_obj, epochstreams, epoch_select)
			% T0_T1 - return the [t0 t1] begin/end times of an image epoch
			%
				ec = imagestack_obj.epochclock(epochstreams, epoch_select);
				if strcmp(ec{1}.type,'dev_local_time')
					t = imagestack_obj.frametimes(epochstreams, epoch_select);
					t0t1 = {[t(1) t(end)]};
				else
					t0t1 = {[NaN NaN]};
				end
		end % t0_t1()

		function channels = getchannelsepoch(imagestack_obj, epochstreams, epoch_select)
			% GETCHANNELSEPOCH - list the channels available for an image epoch
			%
			% Returns a single 'image' channel named 'image1'.
				channels = vlt.data.emptystruct('name','type','time_channel');
				channels(1).name = 'image1';
				channels(1).type = 'image';
				channels(1).time_channel = [];
		end % getchannelsepoch()

	end % methods

end % classdef
