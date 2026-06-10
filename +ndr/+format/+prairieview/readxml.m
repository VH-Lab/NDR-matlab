function v = readxml(filename)
% READXML - Read a Prairie View XML configuration file
%
%   V = ndr.format.prairieview.readxml(FILENAME)
%
%   Reads a Prairie View XML parameter file and returns a struct V in the
%   same shape as ndr.format.prairieview.readconfig (the legacy .pcf reader),
%   so the two formats are interchangeable for ndr.reader.prairieview:
%       V.Main.Lines_per_frame
%       V.Main.Pixels_per_line
%       V.Main.Frame_period__us_      (when available)
%       V.Main.Total_images
%       V.Image_TimeStamp__us_        (per-frame timestamps, microseconds)
%
%   The per-frame timestamps are the real recorded times (not a uniform
%   frame period): for modern PVScan files they are the '<Frame absoluteTime>'
%   values; for the older MM-era XML they are the per-frame '<Time>' values.
%
%   This is a revised port of readprairieviewxml.m / readprairieviewxml3.m
%   from VH-Lab/vhlab-TwoPhoton-matlab (Platforms/PrairieView). The tag names
%   and timestamp semantics (absoluteTime*1e6 for modern; Time*1e3 for legacy)
%   are preserved, but the file-position-based scanning of the originals is
%   replaced with whole-file regular-expression parsing for robustness.
%
%   FILENAME may be a directory, the XML file, or any file in the recording
%   directory; the XML is resolved with ndr.format.prairieview.configfilename.
%
%   See also: ndr.format.prairieview.readconfig, ndr.reader.prairieview

	filename = ndr.format.prairieview.configfilename(filename);
	txt = fileread(filename);

	versiontok = regexp(txt,'<PVScan\s+version="([^"]+)"','tokens','once');
	if ~isempty(versiontok)
		v = localReadModern(txt);
	else
		v = localReadLegacy(txt);
	end
end

% ----- modern PVScan (vers 3/4/5; ported from readprairieviewxml3) ---------

function v = localReadModern(txt)
	v = struct();
	% per-frame absolute times (seconds) -> microseconds, in file order
	at = regexp(txt,'<Frame\b[^>]*\babsoluteTime="([-+0-9.eE]+)"','tokens');
	times = zeros(1,numel(at));
	for i=1:numel(at)
		times(i) = str2double(at{i}{1});
	end
	v.Image_TimeStamp__us_ = times * 1e6;
	v.Main.Total_images = numel(times);

	v.Main.Lines_per_frame = ndr.format.prairieview.keyvalue(txt,'linesPerFrame');
	v.Main.Pixels_per_line = ndr.format.prairieview.keyvalue(txt,'pixelsPerLine');
	fp = ndr.format.prairieview.keyvalue(txt,'framePeriod');
	if ~isempty(fp) && isnumeric(fp)
		v.Main.Frame_period__us_ = fp * 1e6;     % framePeriod is in seconds
	end
	dt = ndr.format.prairieview.keyvalue(txt,'dwellTime');
	if ~isempty(dt) && isnumeric(dt)
		v.Main.Dwell_time__us_ = dt;
	end
end

% ----- legacy MM-era XML (ported from readprairieviewxml) -------------------

function v = localReadLegacy(txt)
	v = struct();

	% Older Prairie XML (e.g. v2.2 '.NET DataSet' files) embeds an XSD schema
	% before the data; element names appear there as '<xs:element name="..."/>'
	% defining the fields. Strip the schema so values are read from the data
	% rows, not from the schema definitions.
	schemaend = strfind(txt,'</xs:schema>');
	if ~isempty(schemaend)
		txt = txt(schemaend(end)+numel('</xs:schema>'):end);
	end

	v.Main.Lines_per_frame = ndr.format.prairieview.elementvalue(txt,'Lines_Per_Frame');
	v.Main.Pixels_per_line = ndr.format.prairieview.elementvalue(txt,'Pixels_Per_Line');
	fr = ndr.format.prairieview.elementvalue(txt,'Framerate');
	if ~isempty(fr) && isnumeric(fr) && fr~=0
		v.Main.Frame_period__us_ = (1/fr) * 1e6;
	end

	% one '<...Time...>VALUE<...>' (milliseconds) per '<Dataset_x0020_N>' frame
	% row, in file order
	starts = regexp(txt,'<Dataset_x0020_\d+>');
	ts = [];
	for i=1:numel(starts)
		seg = txt(starts(i):end);
		tm = regexp(seg,'<[^>]*Time[^>]*>([^<]*)<','tokens','once');
		if ~isempty(tm)
			ts(end+1) = str2double(tm{1}); %#ok<AGROW>
		end
	end
	v.Image_TimeStamp__us_ = ts * 1e3;   % milliseconds -> microseconds
	v.Main.Total_images = numel(ts);
end
