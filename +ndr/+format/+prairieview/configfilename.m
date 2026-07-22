function fname = configfilename(dirname)
% CONFIGFILENAME - Name of the (legacy) Prairie View configuration file
%
%   FNAME = ndr.format.prairieview.configfilename(DIRNAME)
%      OR
%   FNAME = ndr.format.prairieview.configfilename(CONFIGFILE)
%
%   If DIRNAME is a directory, locates the recording's config file within it:
%   a legacy '*_Main.pcf' if present, otherwise a '*.xml' (excluding the
%   'tour.xml' / 'exclude.xml' helper files). If a file is passed, its parent
%   directory is searched the same way.
%
%   This is a revised port of tpconfigfilename.m from
%   VH-Lab/vhlab-TwoPhoton-matlab (Platforms/PrairieView); see that file for
%   the original. The behavior is preserved; this version uses cross-platform
%   path handling.
%
%   See also: ndr.format.prairieview.readconfig, ndr.reader.prairieview

	if isfolder(dirname)
		tpdir = dirname;
	else
		[tpdir,~] = fileparts(dirname);
		if isempty(tpdir)
			tpdir = pwd;
		end
	end

	pcfile = dir(fullfile(tpdir,'*_Main.pcf'));
	if isempty(pcfile)
		xmls = dir(fullfile(tpdir,'*.xml'));
		include = [];
		for i=1:numel(xmls)
			nm = lower(xmls(i).name);
			if any(strcmp(nm,{'tour.xml','exlude.xml','exclude.xml'}))
				% skip helper files (the original excluded 'tour.xml' and the
				% misspelled 'exlude.xml'; 'exclude.xml' is allowed for too)
			else
				include(end+1) = i; %#ok<AGROW>
			end
		end
		if isempty(include)
			error('ndr:format:prairieview:noconfig',...
				['Could not find a Prairie config file (*_Main.pcf or *.xml) for ' dirname '.']);
		end
		if numel(include)==1
			fname = fullfile(tpdir, xmls(include(1)).name);
		else
			% Multiple candidate XMLs (e.g. the scan XML plus a companion
			% '*_Cycle....._VoltageRecording_*.xml'). Picking the last in
			% lexical order chose the voltage-recording file, because '_'
			% (0x5F) sorts after '.' (0x2E) -- yielding empty timestamps.
			% Prefer the XML whose basename is a prefix of the recording's
			% TIFF files (the scan XML); error if the choice is ambiguous.
			tiffs = [dir(fullfile(tpdir,'*.tif')); dir(fullfile(tpdir,'*.tiff'))];
			tiffnames = {tiffs.name};
			matches = [];
			for k=1:numel(include)
				[~,base,~] = fileparts(xmls(include(k)).name);
				if ~isempty(base) && ~isempty(tiffnames) && any(startsWith(tiffnames, base))
					matches(end+1) = include(k); %#ok<AGROW>
				end
			end
			if numel(matches)==1
				fname = fullfile(tpdir, xmls(matches(1)).name);
			elseif isempty(matches)
				error('ndr:format:prairieview:noconfig',...
					['Could not unambiguously choose a Prairie scan XML among ' ...
					 int2str(numel(include)) ' candidates in ' tpdir ...
					 ' (none matches a TIFF prefix).']);
			else
				error('ndr:format:prairieview:noconfig',...
					['Ambiguous Prairie scan XML: ' int2str(numel(matches)) ...
					 ' candidates match a TIFF prefix in ' tpdir '.']);
			end
		end
	else
		fname = fullfile(tpdir, pcfile(end).name);
	end
end
