function v = readconfig(filename)
% READCONFIG - Read values from a (legacy) Prairie View config file
%
%   V = ndr.format.prairieview.readconfig(FILENAME)
%
%   Reads a legacy Prairie Technologies '.pcf' config file and returns a
%   struct V whose fields mirror the file's sections and parameters. Section
%   and parameter names have spaces and parentheses replaced with underscores
%   (so '[Main]' -> V.Main, 'Frame period (us)' -> V.Main.Frame_period__us_).
%   The special '[Image TimeStamp (us)]' section is read as a vector
%   V.Image_TimeStamp__us_ with one timestamp (microseconds) per image; this
%   is the per-frame time source for ndr.reader.prairieview.
%
%   FILENAME may be a directory, a config-file path, or any file in the
%   recording directory; the config file is resolved with
%   ndr.format.prairieview.configfilename.
%
%   For Prairie View 2.2+ recordings the config is an '.xml' document; in that
%   case this function delegates to ndr.format.prairieview.readxml (which reads
%   the per-frame timestamps and dimensions from the XML) and sets
%   V.is_xml = true.
%
%   This is a revised port of readprairieconfig.m from
%   VH-Lab/vhlab-TwoPhoton-matlab (Platforms/PrairieView). The .pcf parsing
%   behavior is preserved, but section termination is made robust to CR, LF,
%   and CRLF line endings (the original assumed Windows CRLF), and str2double
%   is used in place of str2num.
%
%   See also: ndr.format.prairieview.configfilename, ndr.reader.prairieview

	filename = ndr.format.prairieview.configfilename(filename);

	v = struct();
	[~,~,ext] = fileparts(filename);
	if strcmpi(ext,'.xml')
		v = ndr.format.prairieview.readxml(filename);
		v.is_xml = true;
		return;
	end
	v.is_xml = false;

	txt = fileread(filename);
	lines = regexp(txt, '\r\n|\r|\n', 'split');
	N = numel(lines);

	i = 1;
	while i <= N
		s = strtrim(lines{i});
		if isempty(s) || s(1) ~= '['
			i = i + 1;
			continue;
		end

		endb = strfind(s,']');
		if isempty(endb)
			i = i + 1;
			continue;
		end
		secname = strtrim(s(2:endb(1)-1));

		if strcmpi(secname,'Image TimeStamp (us)')
			% the following lines (one per image) hold '<label>=<timestamp_us>'
			if ~isfield(v,'Main') || ~isfield(v.Main,'Total_images')
				error('ndr:format:prairieview:nototalimages',...
					['Config ' filename ' has an [Image TimeStamp (us)] section but no '...
					 '[Main] Total images count was read before it.']);
			end
			nimg = v.Main.Total_images;
			ts = nan(1,nimg);
			for k=1:nimg
				i = i + 1;
				if i > N, break; end
				ln = lines{i};
				eqi = strfind(ln,'=');
				if ~isempty(eqi)
					ts(k) = str2double(strtrim(ln(eqi(1)+1:end)));
				end
			end
			v.Image_TimeStamp__us_ = ts;
			i = i + 1;
		else
			subname = localsanitize(secname);
			field_struct = struct();
			i = i + 1;
			while i <= N
				ln = strtrim(lines{i});
				if isempty(ln) || ln(1) == '['
					break; % blank line or next section ends this section
				end
				eqi = strfind(ln,'=');
				if numel(eqi) > 1
					error('ndr:format:prairieview:badline',...
						['Found more than one equal sign on a line in config ' filename '.']);
				end
				if ~isempty(eqi)
					field = localsanitize(strtrim(ln(1:eqi(1)-1)));
					rawval = strtrim(ln(eqi(1)+1:end));
					val = str2double(rawval);
					if isnan(val) % not a number; keep the string
						val = rawval;
					end
					field_struct.(field) = val;
				end
				i = i + 1;
			end
			v.(subname) = field_struct;
		end
	end
end

function name = localsanitize(name)
	% replace characters invalid in MATLAB field names (space, parentheses)
	% with underscores, matching the original readprairieconfig behavior
	name(name==' ') = '_';
	name(name=='(') = '_';
	name(name==')') = '_';
end
