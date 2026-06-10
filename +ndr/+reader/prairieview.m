% NDR_READER_PRAIRIEVIEW - Reader for (legacy) Prairie View two-photon recordings
%
% This reader reads two-photon image series acquired with Prairie
% Technologies' PrairieView software in the LEGACY layout: a recording
% directory containing one TIFF per frame plus a '*_Main.pcf' configuration
% file. The per-frame timestamps are read from the config's
% '[Image TimeStamp (us)]' section, so the epoch is a 'dev_local_time' movie
% with true (possibly irregular) per-frame times.
%
% It is a native NDR reader with no external dependencies. It extends
% ndr.reader.tiffstack and inherits the directory/anchor-file resolution; it
% overrides the frame layout to group channels onto the C axis (see
% FRAMELAYOUT) and the timing (frametimes / epochclock / t0_t1) to read the
% real per-frame timestamps from the Prairie config.
%
% Multi-channel: each channel is written as its own TIFF named
% '..._Cycle<n>_Ch<c>_<frame>...'. A "frame" here is one TIMEPOINT; all of a
% timepoint's channels are returned together on the C axis of READFRAMES (in
% ascending channel number), and there is one timestamp per timepoint. The
% channel grouping is parsed from the file names, like NANSEN's
% PrairieViewTiffs adapter, but leniently about digit widths and channel
% count.
%
% Epoch layout: the epoch may be given as the recording directory, the
% '*_Main.pcf' config file, or any file in the directory; the config and the
% frame TIFFs are resolved from that directory (see ndr.reader.tiffstack and
% ndr.format.prairieview.configfilename).
%
% Timing vs NANSEN: NANSEN's PrairieViewTiffs reads the XML metadata but
% derives frame times from a single uniform frame period (1/dt). This reader
% instead reads the actual per-frame timestamps from the legacy config's
% '[Image TimeStamp (us)]' section, preserving real (possibly irregular)
% timing. Modern Prairie View 2.2+ XML is not parsed here yet; for modern XML
% recordings use ndr.reader.imagestack (NANSEN) for pixels, noting its timing
% is uniform.
%
% This reader is a revised port of the PrairieView platform from
% VH-Lab/vhlab-TwoPhoton-matlab (readprairieconfig.m, tpconfigfilename.m).
% The config parsing lives in ndr.format.prairieview.
%
% See also: ndr.reader.tiffstack, ndr.reader.imagestack,
%   ndr.format.prairieview.readconfig, ndr.format.prairieview.configfilename

classdef prairieview < ndr.reader.tiffstack

	properties
	end % properties

	methods

		function prairieview_obj = prairieview()
			% PRAIRIEVIEW - Create a new legacy Prairie View image reader
			%
			%  PRAIRIEVIEW_OBJ = PRAIRIEVIEW()
			%
		end % ndr.reader.prairieview.prairieview

		function L = framelayout(prairieview_obj, epochstreams)
			% FRAMELAYOUT - resolve the epoch's frames, grouping channels onto the C axis
			%
			% L = FRAMELAYOUT(PRAIRIEVIEW_OBJ, EPOCHSTREAMS)
			%
			% Parses the recording's TIFF file names for their Cycle, Channel
			% (Ch) and frame-index tokens and builds a timepoint-by-channel
			% grid, so that all channels of a timepoint are returned together
			% on the C axis of READFRAMES. A "frame" (the unit of NUMFRAMES and
			% FRAMETIMES) is one timepoint; the files for a timepoint are its
			% per-channel images.
			%
			% This mirrors how NANSEN's PrairieViewTiffs adapter groups
			% channels from 'Cycle..._Ch..._...' file names, but is lenient
			% about the cycle/frame digit widths and the channel count.
			% Files with no Ch token are treated as a single channel; files
			% with no frame digits are ordered by name.
			%
			% Returns a struct with fields:
			%   .files    ordered TIFF files
			%   .channels sorted unique channel numbers (C-axis order)
			%   .keys     nframes x 2 [cycle frame] of each timepoint (sorted)
			%   .grid     nframes x numChannels cell of file names
			%   .Y .X .C  frame height, width, number of channels
			%   .nframes  number of timepoints
			%   .datatype underlying numeric class
			%
				files = prairieview_obj.imagefiles(epochstreams);
				n = numel(files);
				cyc = ones(n,1); ch = ones(n,1); fr = zeros(n,1);
				for i=1:n
					[~,nm] = fileparts(files{i});
					ct = regexp(nm,'[Cc]ycle(\d+)','tokens','once');
					if ~isempty(ct), cyc(i) = str2double(ct{1}); end
					ht = regexp(nm,'[Cc]h(\d+)','tokens','once');
					if ~isempty(ht), ch(i) = str2double(ht{1}); end
					fm = regexp(nm,'\d+','match');
					if isempty(fm), fr(i) = i; else, fr(i) = str2double(fm{end}); end
				end
				channels = unique(ch);            % sorted ascending -> C-axis order
				keys = unique([cyc fr],'rows');   % sorted by cycle then frame
				nT = size(keys,1);
				nC = numel(channels);
				grid = cell(nT,nC);
				for i=1:n
					ti = find(keys(:,1)==cyc(i) & keys(:,2)==fr(i), 1);
					ci = find(channels==ch(i), 1);
					grid{ti,ci} = files{i};
				end
				if any(cellfun(@isempty, grid(:)))
					error('ndr:reader:prairieview:raggedchannels',...
						['The recording does not have the same set of frames for every '...
						 'channel; cannot assemble a uniform multi-channel stack.']);
				end
				fi = imfinfo(grid{1,1});
				L.files = files;
				L.channels = channels;
				L.keys = keys;
				L.grid = grid;
				L.Y = fi(1).Height;
				L.X = fi(1).Width;
				L.C = nC;
				L.nframes = nT;
				L.datatype = ndr.reader.tiffstack.tiffclass(fi);
		end % framelayout()

		function n = numframes(prairieview_obj, epochstreams, epoch_select)
			% NUMFRAMES - number of timepoints (frames) in the recording
			%
			% A frame is one timepoint; multiple channels of a timepoint count
			% once. See FRAMELAYOUT.
				L = prairieview_obj.framelayout(epochstreams);
				n = L.nframes;
		end % numframes()

		function sz = framesize(prairieview_obj, epochstreams, epoch_select)
			% FRAMESIZE - [Y X C Z T] extent, with C = number of channels
				L = prairieview_obj.framelayout(epochstreams);
				sz = [L.Y L.X L.C 1 L.nframes];
		end % framesize()

		function dt = datatype(prairieview_obj, epochstreams, epoch_select)
			% DATATYPE - underlying numeric class of the pixel data
				L = prairieview_obj.framelayout(epochstreams);
				dt = L.datatype;
		end % datatype()

		function frames = readframes(prairieview_obj, epochstreams, epoch_select, frameind)
			% READFRAMES - read timepoints, with all channels on the C axis
			%
			% FRAMES = READFRAMES(PRAIRIEVIEW_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Returns an array in 'YXCZT' order, size [Y X C 1 numel(FRAMEIND)],
			% where the C axis holds the recording's channels (in ascending Ch
			% number) for each requested timepoint.
				L = prairieview_obj.framelayout(epochstreams);
				if nargin<4
					frameind = 1:L.nframes;
				end
				frames = zeros(L.Y, L.X, L.C, 1, numel(frameind), L.datatype);
				for i=1:numel(frameind)
					ti = frameind(i);
					for ci=1:L.C
						im = imread(L.grid{ti,ci});
						frames(:,:,ci,1,i) = reshape(cast(im,L.datatype), L.Y, L.X);
					end
				end
		end % readframes()

		function v = config(prairieview_obj, epochstreams)
			% CONFIG - read the Prairie config struct for an epoch
			%
			% V = CONFIG(PRAIRIEVIEW_OBJ, EPOCHSTREAMS)
			%
			% Resolves the recording directory from EPOCHSTREAMS and reads its
			% Prairie config via ndr.format.prairieview.readconfig.
			%
				files = prairieview_obj.imagefiles(epochstreams);
				dirpath = fileparts(files{1});
				v = ndr.format.prairieview.readconfig(dirpath);
		end % config()

		function tf = hasconfigtimes(prairieview_obj, epochstreams)
			% HASCONFIGTIMES - does the Prairie config provide per-frame times?
			%
			% TF = HASCONFIGTIMES(PRAIRIEVIEW_OBJ, EPOCHSTREAMS)
			%
			% Returns true if a legacy config with an '[Image TimeStamp (us)]'
			% section is present (so frame times come from the config); false
			% for a modern XML config or when no timestamps are available, in
			% which case the inherited ndr.reader.tiffstack timing is used.
			%
				tf = false;
				try
					v = prairieview_obj.config(epochstreams);
					tf = isfield(v,'Image_TimeStamp__us_') && ~isempty(v.Image_TimeStamp__us_) ...
						&& ~all(isnan(v.Image_TimeStamp__us_));
				catch
					tf = false;
				end
		end % hasconfigtimes()

		function t = frametimes(prairieview_obj, epochstreams, epoch_select, frameind)
			% FRAMETIMES - per-frame times (seconds) from the Prairie config
			%
			% T = FRAMETIMES(PRAIRIEVIEW_OBJ, EPOCHSTREAMS, EPOCH_SELECT, FRAMEIND)
			%
			% Returns the '[Image TimeStamp (us)]' values (converted to
			% seconds) for the requested frames. Falls back to the inherited
			% ndr.reader.tiffstack behavior (sidecar / NaN) when the config has
			% no timestamps.
			%
				if nargin<4
					frameind = 1:prairieview_obj.numframes(epochstreams, epoch_select);
				end
				if prairieview_obj.hasconfigtimes(epochstreams)
					v = prairieview_obj.config(epochstreams);
					allt = v.Image_TimeStamp__us_(:) / 1e6; % microseconds -> seconds
					t = allt(frameind);
				else
					t = frametimes@ndr.reader.tiffstack(prairieview_obj, epochstreams, epoch_select, frameind);
				end
		end % frametimes()

		function ec = epochclock(prairieview_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - clock type(s) for the epoch
			%
			% Returns {ndr.time.clocktype('dev_local_time')} when the config
			% provides per-frame times; otherwise defers to ndr.reader.tiffstack.
			%
				if prairieview_obj.hasconfigtimes(epochstreams)
					ec = {ndr.time.clocktype('dev_local_time')};
				else
					ec = epochclock@ndr.reader.tiffstack(prairieview_obj, epochstreams, epoch_select);
				end
		end % epochclock()

		function t0t1 = t0_t1(prairieview_obj, epochstreams, epoch_select)
			% T0_T1 - [t0 t1] begin/end times for the epoch
			%
			% From the config timestamps when present; otherwise defers to
			% ndr.reader.tiffstack.
			%
				if prairieview_obj.hasconfigtimes(epochstreams)
					t = prairieview_obj.frametimes(epochstreams, epoch_select);
					t0t1 = {[t(1) t(end)]};
				else
					t0t1 = t0_t1@ndr.reader.tiffstack(prairieview_obj, epochstreams, epoch_select);
				end
		end % t0_t1()

	end % methods

end % classdef
