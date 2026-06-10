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
% ndr.reader.tiffstack: the pixel reading (enumerating the directory's TIFFs
% in name order, framesize, datatype, readframes) is inherited unchanged, and
% only the timing (frametimes / epochclock / t0_t1) is overridden to come
% from the Prairie config instead of a sidecar.
%
% Epoch layout: the epoch may be given as the recording directory, the
% '*_Main.pcf' config file, or any file in the directory; the config and the
% frame TIFFs are resolved from that directory (see ndr.reader.tiffstack and
% ndr.format.prairieview.configfilename).
%
% Scope (v1): a single channel is assumed (one TIFF per frame, so the TIFF
% count equals the number of timestamps). Multi-channel interleaving and the
% modern Prairie View 2.2+ XML format are not handled here; for modern XML
% recordings use ndr.reader.imagestack (which reads them through NANSEN).
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
