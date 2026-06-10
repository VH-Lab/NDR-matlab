function val = keyvalue(txt, keyname)
% KEYVALUE - read a Prairie View XML key/value parameter
%
%   VAL = ndr.format.prairieview.keyvalue(TXT, KEYNAME)
%
%   Given the text TXT of a (modern, PVScan) Prairie View XML file, returns
%   the value of the '<Key key="KEYNAME" value="...">' or
%   '<PVStateValue key="KEYNAME" value="...">' element. VAL is returned as a
%   number when the value parses as numeric, otherwise as the raw string.
%   Returns [] if the key is not found.
%
%   This is a revised port of readprairie3keyvalue.m from
%   VH-Lab/vhlab-TwoPhoton-matlab (Platforms/PrairieView): same key/value tag
%   model, but parses the supplied text with a regular expression rather than
%   scanning a file handle by position.
%
%   See also: ndr.format.prairieview.readxml, ndr.format.prairieview.elementvalue

	pat = ['<(?:Key|PVStateValue)\s+key="' regexptranslate('escape',keyname) ...
		'"[^>]*?\bvalue="([^"]*)"'];
	m = regexp(txt, pat, 'tokens', 'once', 'ignorecase');
	if isempty(m)
		val = [];
		return;
	end
	val = str2double(m{1});
	if isnan(val)        % not a plain number; keep the string
		val = m{1};
	end
end
