function csize = configsize(filename)
% CONFIGSIZE - byte length of the Trodes (.rec) XML configuration block
%
%  CSIZE = ndr.format.spikegadgets.configsize(FILENAME)
%
%  Returns the number of bytes occupied by the leading XML configuration
%  block of a SpikeGadgets/Trodes (.rec) file, i.e. the byte offset of the
%  first data packet. The block is delimited by the closing
%  '</Configuration>' tag; CSIZE is the index of the first byte AFTER that
%  tag (matching read_rec_config.m's 'strfind(...)+16' convention). Returns
%  0 if no configuration block is present.
%
%  This centralizes the scan that read_rec_config.m and the channel readers
%  each performed with inconsistent read lengths (read_rec_config scans
%  1000000 chars while read_rec_analog/trodeChannels scan only 30000, which
%  truncates on configurations larger than ~30 kB).
%
%  See also: ndr.format.spikegadgets.read_rec_config

	fid = fopen(filename,'r');
	if fid<0,
		error('ndr:format:spikegadgets:configsize:cannotOpen', ...
			['Could not open file ' filename '.']);
	end;
	cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU> close on any exit

	closingTag = '</Configuration>';
	junk = fread(fid,1000000,'char');
	idx = strfind(junk', closingTag);
	if isempty(idx),
		csize = 0;
	else,
		csize = idx(1) + length(closingTag); % first byte after the closing tag
	end;
end
