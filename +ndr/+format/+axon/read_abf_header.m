function h = read_abf_header(filename)
% READ_ABF_READER - read header infromation from an Axon Instruments ABF file
%
% H = READ_ABF_HEADER(FILENAME)
%
% Reads header information from the ABF file FILENAME.
% 
% Relies on abfload from https://github.com/fcollman/abfload
%

[d,si,h]=abfload2(filename,'start',0,'stop',0.1,'doDispInfo',false);

