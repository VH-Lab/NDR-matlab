function tf = isSON64(filename)
% ndr.format.ced.isSON64 - Is a CED Spike2 file a 64-bit (son64/.smrx) file?
%
%   TF = ndr.format.ced.isSON64(FILENAME)
%
%   Returns true if FILENAME is a 64-bit CED Spike2 file (the "son64" format,
%   normally with a .smrx extension), and false if it is a legacy 32-bit file
%   (the "son32" format, normally .smr or .son).
%
%   Detection reads the file's leading bytes rather than trusting the
%   extension: son64 files begin with the ASCII signature 'S64', whereas son32
%   files begin with a small integer systemID and therefore do not.
%
%   ndr.format.ced.read_SOMSMR_* uses this to route 32-bit files to the
%   built-in sigTOOL reader and 64-bit files to the sonpipe-backed reader.
%
%   See also: ndr.format.ced.read_SOMSMR_header

	tf = false;

	fid = fopen(filename, 'r', 'l');
	if fid < 0,
		error('ndr:format:ced:isSON64:cannotOpen', ...
			['Could not open file: ' filename '.']);
	end;
	cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

	magic = fread(fid, 3, '*uint8');
	if numel(magic) == 3 && isequal(magic(:)', uint8('S64')),
		tf = true;
	end;
end
