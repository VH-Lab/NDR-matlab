function val = elementvalue(txt, tag)
% ELEMENTVALUE - read an element value from a (legacy) Prairie View XML
%
%   VAL = ndr.format.prairieview.elementvalue(TXT, TAG)
%
%   Given the text TXT of a legacy (MM-era) Prairie View XML file, returns the
%   value enclosed by the first element whose tag contains TAG, i.e. the text
%   between '>' and the next '<' of '<...TAG...>VALUE<...>'. VAL is returned as
%   a number when it parses as numeric, otherwise as the raw string. Returns []
%   if the tag is not found.
%
%   This is a revised port of the getxmlval subfunction of readprairieviewxml.m
%   from VH-Lab/vhlab-TwoPhoton-matlab (Platforms/PrairieView): same
%   value-between-angle-brackets model, but parses the supplied text with a
%   regular expression rather than scanning a file handle by position.
%
%   See also: ndr.format.prairieview.readxml, ndr.format.prairieview.keyvalue

	pat = ['<[^>]*' regexptranslate('escape',tag) '[^>]*>([^<]*)<'];
	m = regexp(txt, pat, 'tokens', 'once');
	if isempty(m)
		val = [];
		return;
	end
	val = str2double(m{1});
	if isnan(val)
		val = m{1};
	end
end
