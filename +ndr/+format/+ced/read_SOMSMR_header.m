function [header] = read_SOMSMR_header(filename);
% ndr.format.intan.read_SOMSMR_header - Read header information from a CED SOM or SMR file
%
% HEADER = ndr.format.ced.read_SOMSMR_header(FILENAME)
%
% Returns a structure HEADER with all of the information fields that
% are stored in the CED SOM/SMR file FILENAME.
%
% CED stands for Cambridge Electronic Design, which makes the Spike2 data acquisition system.
% This function reads header files for the SOM/SMR file formats.
%
% This function depends on sigTOOL by Malcolm Lidierth (http://sigtool.sourceforge.net).
%
% sigTOOL is also included in the https://github.com/VH-Lab/thirdparty bundle and
% can be installed with instructions at http://code.vhlab.org.
%
% HEADER contains two substructures:
% --------------------------------------------------------------------
% fileinfo                |  Information about the file and its version
% channelinfo             |  Information about the channels acquired in the file
%
% See also: ndr.format.ced.read_SOMSMR_datafile, ndr.format.ced.read_SOMSMR_sampleinterval,
%   SONFILEHEADER (documents HEADER.fileinfo),
%
% For 64-bit CED files (the son64 format, normally .smrx) the header is read via
% the sonpipe command-line bridge; 32-bit files (son32, normally .smr/.son) use
% the built-in sigTOOL reader below. See ndr.format.ced.isSON64.

if ndr.format.ced.isSON64(filename),
	header = ndr.format.ced.sonpipe.read_SOMSMR_header(filename);
	return;
end;

[pathname filename2 extension] = fileparts(filename);
if strcmpi(extension,'.smr'), % little endian
	fid=fopen(filename,'r','l');
elseif strcmp(extension,'.son'), % big endian
	fid=fopen(filename,'r','b');
else,
	error(['Unknown extension for SOM/SMR file: .' extension '.']);
end;

header.fileinfo = SONFileHeader(fid);
header.channelinfo = SONChanList(fid);

fclose(fid);

