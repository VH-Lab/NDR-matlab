function configsize = read_rec_configsize(filename, searchbytes)
% ndr.format.spikegadgets.read_rec_configsize - First byte of packet data in a .rec
%
%   CONFIGSIZE = ndr.format.spikegadgets.read_rec_configsize(FILENAME)
%   CONFIGSIZE = ndr.format.spikegadgets.read_rec_configsize(FILENAME, SEARCHBYTES)
%
%   Returns the number of bytes to skip to reach the packet stream, suitable
%   for fseek(fid, CONFIGSIZE, 'bof'). Returns 0 if the file has no
%   configuration block (some raw SD-card captures do not). SEARCHBYTES limits
%   how much of the file head is scanned (default 1000000).
%
%   A .rec begins with an XML configuration block terminated by
%   '</Configuration>', and the packet stream starts on the NEXT LINE. The
%   readers in this package compute this inline as
%   strfind(junk, '</Configuration>') + 16, which is correct because strfind is
%   1-based; this function computes the same value for a single-newline
%   terminator, and additionally handles a CRLF terminator or a header written
%   without one, where the fixed + 16 would be off by one.
%
%   Mirrors ndr/format/spikegadgets/read_rec_configsize.py in NDR-python, where
%   the equivalent inline expression was ported onto 0-based bytes.find and so
%   landed a byte early -- see NDR-python#12.
%
%   See also: ndr.format.spikegadgets.read_rec_trodeChannels

	arguments
		filename {mustBeTextScalar}
		searchbytes (1,1) {mustBeNumeric} = 1000000
	end

	tag = '</Configuration>';

	fid = fopen(filename, 'r');
	if fid < 0,
		error('ndr:format:spikegadgets:cannotOpen', ...
			['Could not open file: ' char(filename) '.']);
	end;
	cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

	head = fread(fid, searchbytes, '*char')';

	index = strfind(head, tag);
	if isempty(index),
		configsize = 0;
		return;
	end;

	% 1-based index of the tag's last byte, which is also the 0-based count of
	% bytes up to and including the tag.
	offset = index(1) + numel(tag) - 1;

	if offset + 2 <= numel(head) && isequal(head(offset+1:offset+2), sprintf('\r\n')),
		configsize = offset + 2;
	elseif offset + 1 <= numel(head) && ...
			(head(offset+1) == sprintf('\n') || head(offset+1) == sprintf('\r')),
		configsize = offset + 1;
	else,
		configsize = offset;
	end;
end
