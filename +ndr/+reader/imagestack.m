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

		function filename = filenamefromepochfiles(imagestack_obj, filename_array)
			% FILENAMEFROMEPOCHFILES - return the primary image file for the epoch
			%
			% FILENAME = FILENAMEFROMEPOCHFILES(IMAGESTACK_OBJ, FILENAME_ARRAY)
			%
			% Returns the first file in FILENAME_ARRAY. NANSEN's ImageStack
			% itself resolves whatever companion files a format needs.
			%
				if ~iscell(filename_array)
					filename_array = {filename_array};
				end
				if isempty(filename_array)
					error('ndr:reader:imagestack:nofile','No file found in epoch files.');
				end
				filename = filename_array{1};
		end % filenamefromepochfiles()

		function s = imagestackobject(imagestack_obj, epochstreams)
			% IMAGESTACKOBJECT - construct the underlying nansen.stack.ImageStack
			%
			% S = IMAGESTACKOBJECT(IMAGESTACK_OBJ, EPOCHSTREAMS)
			%
			% Builds a nansen.stack.ImageStack for the epoch by opening the
			% file with nansen.stack.open (which selects the right +virtual
			% adapter from the file extension) and wrapping the resulting
			% virtual data object. Errors with a clear message if NANSEN is
			% not installed.
			%
				if exist('nansen.stack.ImageStack','class')~=8
					error('ndr:reader:imagestack:nonansen',...
						['nansen.stack.ImageStack was not found on the MATLAB path. ' ...
						 'The ndr.reader.imagestack backend requires NANSEN ' ...
						 '(https://github.com/VervaekeLab/NANSEN), installable via ' ...
						 'tools/requirements.txt (matbox.installRequirements). Use ' ...
						 'ndr.reader.tiffstack for plain multipage TIFFs to avoid this dependency.']);
				end
				filename = imagestack_obj.filenamefromepochfiles(epochstreams);
				virtualData = nansen.stack.open(filename);
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
			% Adapted from nansen.stack.ImageStack/getFrameTimes. Returns NaN
			% for each frame when NANSEN reports no timing information.
				if nargin<4
					frameind = 1:imagestack_obj.numframes(epochstreams, epoch_select);
				end
				s = imagestack_obj.imagestackobject(epochstreams);
				try
					t = s.getFrameTimes(frameind);
					t = t(:);
				catch
					t = nan(numel(frameind),1);
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
